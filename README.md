# mpv-kde-hdr-switcher

A lightweight Lua script for **mpv** on **KDE Plasma (Wayland)** that automatically toggles System HDR and WCG (Wide Color Gamut) modes based on the video file's properties.

## Features
* **Automatic HDR Toggle**: Switches HDR on when an HDR file is detected and back to SDR when finished.
* **High Responsiveness**: Optimized with a 0.1s polling interval for near-instant detection.
* **Smart Detection**: Identifies HDR even in mislabeled or "stubborn" files by analyzing luminance metadata (max-luma) alongside standard color flags.
* **Quarantine Logic**: Includes a configurable delay (1.0s by default) to prevent screen flickering when navigating playlists.
* **Playback Sync**: Pauses video during the mode switch to ensure a clean transition without frame drops or artifacts.

## Requirements
* **KDE Plasma** (Wayland session is mandatory for HDR).
* **libkscreen** (provides the `kscreen-doctor` utility).
* **mpv** compiled with Lua support.

## Hardware Note
Tested and verified on systems using `kscreen-doctor`. The detection logic is hardware-agnostic and focuses on stream metadata (Primaries, Gamma/Transfer, and Mastering Display Luminance) rather than specific decoder flags, ensuring reliability across different GPU drivers.

## Installation
1. Download `kde-hdr-switcher.lua` and move it to your mpv scripts folder:
   `~/.config/mpv/scripts/`

2. Find your display output name by running:
   `kscreen-doctor -o`
   *Example output: Output: 1 Name: HDMI-A-1*

3. Open the script in a text editor and update the `output_name` variable at the top:
   `local output_name = "HDMI-A-1"` -- Replace with your actual output name

## Configuration
You can fine-tune the script behavior by modifying the variables in the `CONFIGURATION` section:

| Variable | Default | Description |
| :--- | :--- | :--- |
| check_interval | 0.1 | Time in seconds between metadata checks. |
| max_attempts | 10 | Number of checks before switching back to SDR (10 * 0.1s = 1s). |

## How it Works
The script monitors both `video-params` and `video-out-params` for specific HDR indicators using an optimized priority-based logic:
* **Transfer Curves (Gamma)**: PQ (SMPTE ST 2084) or HLG.
* **Color Primaries**: BT.2020 (Ultra HD standard) primaries or matrix identifiers.
* **Luminance Metadata**: Detects HDR via `max-luma` (Mastering Display) values, allowing it to catch HDR content even when standard color space tags are missing or incorrect. The 203 nits value is ignored because it represents the standard reference for "Graphics White" in HDR, often used as a default placeholder that doesn't indicate actual high-dynamic-range highlights.

Upon detection, it triggers:
`kscreen-doctor output.<name>.hdr.enable output.<name>.wcg.enable`

## License
MIT License
