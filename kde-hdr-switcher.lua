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
    local params = mp.get_property_native("video-out-params")
    local vparams = mp.get_property_native("video-params")

    -- Hardware-specific formats (crucial for HEVC/P010 without standard metadata)
    local vo_format = mp.get_property("video-out-params/pixelformat") or ""
    local v_format = mp.get_property("video-format") or ""

    -- Wait for decoder to initialize video structures
    if not params and not vparams then
        if attempts < max_attempts then
            attempts = attempts + 1
            mp.add_timeout(check_interval, check_hdr)
        end
        return
    end

    local colormatrix = params["colormatrix"] or vparams["colormatrix"] or ""
    local transfer = params["transfer"] or vparams["transfer"] or ""
    local primaries = params["primaries"] or vparams["primaries"] or ""

    -- DETECTION LOGIC (Short-circuit evaluation) --
    local is_hdr =
    -- BT.2020 color space is the standard for Ultra HD and HDR content
    string.find(colormatrix, "bt.2020") or
    string.find(primaries, "bt.2020") or

    -- Hybrid Log-Gamma: HDR standard used mainly in TV and live broadcasts
    transfer == "hlg" or

    -- SMPTE ST 2084 / PQ: The perceptual quantizer curve used in HDR10 and Dolby Vision
    transfer == "smpte2084" or
    transfer == "pq" or

    -- Fallback: Detects HEVC hardware decoding (VA-API), which often implies 10-bit HDR
    (vo_format == "vaapi" and v_format == "hevc") or

    -- High Bit Depth check: Detects 10-bit pixel formats (P010), a key requirement for HDR
    string.find(vo_format, "p010")

    if is_hdr then
        set_system_hdr(true)
        attempts = 0 -- Reset counter on successful detection
    else
        -- Quarantine logic: confirm it's SDR before switching back
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

mp.register_event("shutdown", function()
    -- Force SDR mode on exit to restore desktop colors
    os.execute(string.format("kscreen-doctor output.%s.hdr.disable output.%s.wcg.disable &", output_name, output_name))
end)
