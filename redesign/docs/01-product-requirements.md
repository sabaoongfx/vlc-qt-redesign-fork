# 01 Product requirements

## Summary

VLC (juxtopposed) is VLC 4 with a new interface: the design Juxtopposed presented in the video
"I Redesigned VLC After 25 Years" (https://youtu.be/ERFeOgqk324) and the community Figma file,
implemented in VLC's real Qt/QML interface and backed by VLC's real models (media library, player,
playlist, settings). The HTML prototype (`sabaoongfx/vlc`) is a visual reference only; its data layer
is not used.

## Goals

1. **Look like the design.** Library, player, side panels, menus, dialogs and Settings match the Figma
   frames (colours, sizes and spacing measured by the test harness, see 07).
2. **Keep VLC's behaviour.** Everything plays what VLC plays; options are VLC's own options; no
   feature is faked with mock data.
3. **Install next to VideoLAN's VLC.** Its own name, folder, menu entry and uninstaller on every
   platform; it never replaces or breaks the official VLC.
4. **Stay rebase-able onto upstream VLC.** Prefer QML changes; keep C++/core changes small and logged (04).
5. **Ship on Windows, Linux and macOS** as normal downloads, and on Linux through apt and pacman.

## Non-goals

- Replacing VLC's Cocoa macOS interface, skins2 or ncurses (macOS gets this Qt interface instead).
- The prototype's mock-ups without a VLC backend (OpenSubtitles search, spatializer and stereo
  widener panels as drawn, sleep timer, reverse playback).
- Being an official VideoLAN product. Every page and release says it is unofficial.

## Audience

- People who use VLC daily and want a modern, calmer interface with a folder-based library.
- Viewers of Juxtopposed's and Sab GFX's videos who want to try the design for real.
- Windows, Linux (Ubuntu/Debian, Fedora/openSUSE, Arch/Manjaro) and Apple-silicon Mac users.

## Platforms and support

| Platform | Package | Minimum |
|---|---|---|
| Windows | NSIS installer, portable zip | Windows 10/11 x64 |
| Linux | AppImage, tarball, .deb, .rpm, Arch package, apt and pacman repositories | x86_64, glibc 2.39 (Ubuntu 24.04, Debian 13, Fedora 40, openSUSE Tumbleweed, Arch) |
| macOS | dmg | macOS 13+, Apple silicon |

Not supported: 32-bit, ARM Linux, Intel Macs (not built), Windows on ARM.

## Scope (feature areas)

Each area has numbered requirements in 02.

- Main window shell: sidebar (Home, Videos, Music, Network, Playlists), top bar, page headers with
  back/forward, address line, search, sort and view toggles.
- Media library: Home (Continue Watching, New Videos), Videos as a folder tree, Music as a folder
  tree plus albums/artists/genres/tracks, Network saved streams, Playlists.
- Player: video stage, control bar (library button, previous, 10 s back, play, 10 s forward, next),
  seek bar with preview, top bar, auto-hiding bars, side panels (tracks, audio, effects), tracks
  picker, play queue, compact library card with its icon rail, resume prompt, mini player.
- Settings: Figma row pages over VLC options, search, classic pages under Advanced Options.
- Dialogs: VLC's Widgets dialogs restyled (palette and stylesheet), two new Figma dialogs (Open
  network stream, New playlist).
- Packaging and distribution: see 05 and 06.

## Success criteria

- Every release: all CI workflows green on the tagged commit (Linux build with screenshots,
  Linux packages with install tests on five distributions, Windows build with screenshots, macOS build).
- Harness: no QML warnings in any scene; the measured Figma checks pass (07).
- A user can install, play a local video, browse a folder tree and change a setting on each platform
  without errors (manual checklist in 06).

## Constraints

- GPL-2.0-or-later (VLC). Inter font under OFL. Design credit to Juxtopposed on the website and in
  release notes.
- No code-signing certificates yet: Windows SmartScreen and macOS Gatekeeper warn (09).
- Qt 6.10 on Linux packages, the contrib Qt on Windows (no `Canvas`, no `QtQuick.Shapes`), Qt from the
  online installer on macOS.
