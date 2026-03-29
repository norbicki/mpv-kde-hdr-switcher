# mpv-kde-hdr-switcher

A lightweight Lua script for **mpv** on **KDE Plasma (Wayland)** that automatically toggles System HDR and WCG (Wide Color Gamut) modes based on the video file's properties.

## Features
* **Automatic HDR Toggle**: Switches HDR on when an HDR file is detected and back to SDR when finished.
* **High Responsiveness**: Optimized with a 0.1s polling interval for near-instant detection.
* **Smart Detection**: Goes beyond basic metadata; identifies HDR in "stubborn" files via `p010` pixel formats and `HEVC` hardware decoding flags.
* **Quarantine Logic**: Includes a configurable delay (1.0s by default) to prevent screen flickering when navigating playlists.
* **Playback Sync**: Pauses video during the mode switch to ensure a clean transition without frame drops or artifacts.

## Requirements
* **KDE Plasma** (Wayland session is mandatory for HDR).
* **libkscreen** (provides the `kscreen-doctor` utility).
* **mpv** compiled with Lua support.
* **Hardware Decoding** (VA-API/Intel recommended for best results with 10-bit files).

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
The script monitors `video-out-params` for specific HDR indicators:
* **Color Spaces**: BT.2020 matrix or primaries.
* **Transfer Curves**: HLG, PQ (SMPTE ST 2084).
* **Pixel Formats**: P010 (10-bit) or HEVC streams via VA-API.

Upon detection, it triggers:
`kscreen-doctor output.<name>.hdr.enable output.<name>.wcg.enable`

