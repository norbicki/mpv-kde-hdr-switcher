local utils = require 'mp.utils'

-- CONFIGURATION --
local output_name = "HDMI-A-1"
local check_interval = 0.1  -- Time between checks in seconds
local hdr_active = false
local attempts = 0
local max_attempts = 10     -- Total quarantine time: 10 * 0.1s = 1.0s

-- SYSTEM CONTROL FUNCTION --
local function set_system_hdr(state)
    if state == hdr_active then return end

    local action = state and "enable" or "disable"
    local message = state and "HDR Mode: ENABLED" or "HDR Mode: DISABLED"

    -- Pause to prevent playback artifacts during mode switch
    mp.set_property_native("pause", true)

    -- Execute kscreen-doctor to toggle HDR and WCG
    local cmd = string.format("kscreen-doctor output.%s.hdr.%s output.%s.wcg.%s &",
                output_name, action, output_name, action)
    os.execute(cmd)

    hdr_active = state

    -- Resume playback and show OSD after display synchronization
    mp.add_timeout(1.2, function()
        mp.set_property_native("pause", false)
        mp.osd_message(message, 3)
    end)
end

-- VIDEO PARAMETERS ANALYSIS --
local function check_hdr()
    local vparams = mp.get_property_native("video-params")
    local out_params = mp.get_property_native("video-out-params")

    -- Wait for the decoder to initialize video structures
    if not vparams and not out_params then
        if attempts < max_attempts then
            attempts = attempts + 1
            mp.add_timeout(check_interval, check_hdr)
        end
        return
    end

    -- Data extraction with priority for video-out-params (as seen in your terminal dump)
    local gamma = (out_params and out_params["gamma"]) or (vparams and vparams["gamma"]) or ""
    local primaries = (out_params and out_params["primaries"]) or (vparams and vparams["primaries"]) or ""
    local max_luma = (out_params and out_params["max-luma"]) or (vparams and vparams["max-luma"]) or 0
    local colormatrix = (out_params and out_params["colormatrix"]) or (vparams and vparams["colormatrix"]) or ""

    -- DETECTION LOGIC (Optimized by probability of occurrence):
    -- 1. gamma: "pq" (HDR10) or "hlg" (Broadcast HDR) are the most reliable indicators.
    -- 2. primaries: "bt.2020" is the industry standard for 4K HDR content.
    -- 3. max_luma: Fallback for mislabeled files (e.g., files reporting bt.709 but containing HDR metadata).
    --    Note: 203 nits is the standard reference for SDR white, so we ignore it.
    -- 4. colormatrix: Final check for bt.2020 tags in the color matrix.

    local is_hdr = (gamma == "pq" or gamma == "hlg") or
                   (primaries == "bt.2020") or
                   (max_luma > 0 and max_luma ~= 203) or
                   (string.find(colormatrix, "bt.2020") ~= nil)

    if is_hdr then
        set_system_hdr(true)
        attempts = 0 -- Reset counter on successful detection
    else
        -- Confirm it's SDR over multiple attempts to avoid false negatives during scene changes
        if attempts < max_attempts then
            attempts = attempts + 1
            mp.add_timeout(check_interval, check_hdr)
        else
            set_system_hdr(false)
            attempts = 0
        end
    end
end

-- EVENT HANDLERS --

mp.register_event("file-loaded", function()
    attempts = 0
    -- Start detection loop shortly after file load
    mp.add_timeout(check_interval, check_hdr)
end)

mp.observe_property("pause", "bool", function(name, paused)
    -- Re-check HDR state when unpausing
    if not paused then
        attempts = 0
        check_hdr()
    end
end)

mp.observe_property("eof-reached", "bool", function(name, val)
    if val == true then
        set_system_hdr(false)
        attempts = 0
    end
end)

mp.register_event("shutdown", function()
    -- Force SDR mode on exit to restore desktop colors
    os.execute(string.format("kscreen-doctor output.%s.hdr.disable output.%s.wcg.disable", output_name, output_name))
end)
