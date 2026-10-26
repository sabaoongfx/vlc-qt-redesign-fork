# Settings map: Figma rows to VLC options

The settings window follows the Figma `03 Settings` frames. Every row is bound to a real VLC
option through the usual `ConfigControl` classes (`SettingsRows` in
`modules/gui/qt/dialogs/preferences/simple_preferences.cpp`). This file is generated from that code;
regenerate it after changing the rows.

Rules:

- A row with no matching option is left out, not faked. If the build lacks an option (for example,
  its module is not compiled in), the row is not shown.
- Row controls are written on Save only when the user changed them. Each classic page (Interface,
  Audio, Video, Subtitles, Input & Codecs) stays whole under its page's Advanced Options, with its own
  Save code.
- Options the classic Save code writes itself are not repeated as rows: `volume-save`, `audio-filter`,
  `freetype-shadow-opacity`, `freetype-background-opacity`, `qt-fullscreen-screennumber`, `intf`.

Figma rows left out (no VLC option, or the option does something else):

| Page | Figma row | Why |
|---|---|---|
| Global | Interface language | Windows-only in VLC (the classic Interface page has it there) |
| Global | Show confirmation and error dialogs, Developer mode, Additional command line options | no option |
| Interface | Use a custom skin, Skin file | the classic page's layout chooser writes `intf`; kept there |
| Interface | Remember window size and position, Show the file name in the title bar | no option |
| Interface | Open fullscreen on | `qt-fullscreen-screennumber`, written by the classic Video page |
| Interface | Hide after (slider) | shown as `mouse-hide-timeout` in ms |
| Privacy | Save recently played items, Never remember items matching | the options are obsolete in VLC 4 |
| Controls | Single / double click on the video, Reverse scroll direction | no option |
| Controls | Remotes (web remote, port) | the web interface is enabled through `extraintf`, not one option |
| Playback | Pause when another app uses audio | no option |
| Video | Picture (hue, brightness, contrast, saturation, gamma) | they only act through the adjust filter, which these rows cannot enable |
| Audio | Equalizer, presets, two-pass, spatial audio, stereo widening, normalise, night mode | filters enabled through `audio-filter`; the effects dialog handles them |
| Audio | Startup volume | written by the classic Audio page; kept there |
| Subtitles | Size values (relative / pixels), Font size | the font size options are obsolete in VLC 4 |
| Performance | Video post-processing, Give VLC real-time priority, Process priority | obsolete or no option |
| Recording | Discover cast devices | no option |
| Extensions | Add-on list, Load add-ons on startup | the plugins dialog lists them |

## Video Defaults


**Output**

| Row | Option |
|---|---|
| Enable video | `video` |
| Start videos in fullscreen | `fullscreen` |
| Stop the screensaver during playback | `disable-screensaver` |
| Keep the video above other windows | `video-on-top` |
| Play video as desktop wallpaper | `video-wallpaper` |

**Deinterlacing**

| Row | Option |
|---|---|
| Deinterlacing | `deinterlace` |
| Method | `deinterlace-mode` |

**Framing**

| Row | Option |
|---|---|
| Aspect ratio | `aspect-ratio` |
| Crop | `crop` |
| Fit the video to the window | `autoscale` |

*Advanced Options*

## Audio Defaults


**Output**

| Row | Option |
|---|---|
| Enable audio | `audio` |
| Output module | `aout` |
| Stereo mode | `stereo-mode` |
| Force Dolby Surround | `force-dolby-surround` |
| Use S/PDIF when available | `spdif` |

**Volume**

| Row | Option |
|---|---|
| Maximum volume | `qt-max-volume` |
| Volume step | `volume-step` |

**Loudness**

| Row | Option |
|---|---|
| Replay gain | `audio-replay-gain-mode` |
| Replay gain preamp | `audio-replay-gain-preamp` |

**Effects**

| Row | Option |
|---|---|
| Keep the pitch when changing speed | `audio-time-stretch` |
| Visualization | `audio-visual` |

*Advanced Options*

## Playback Preferences


**Startup**

| Row | Option |
|---|---|
| Continue where you left off | `restore-playback-pos` |
| Start playing as soon as a file opens | `playlist-autostart` |
| Default playback speed | `rate` |

**Tracks**

| Row | Option |
|---|---|
| Preferred video quality | `preferred-resolution` |
| Preferred menu language | `menu-language` |
| Default audio track | `audio-track` |
| Default subtitle track | `sub-track` |

**Order**

| Row | Option |
|---|---|
| Repeat | (custom, see code) |
| Shuffle | `random` |
| Stop after each item | `play-and-stop` |
| When playback finishes | (custom, see code) |

**Seeking**

| Row | Option |
|---|---|
| Seek precisely | (custom, see code) |

*Advanced Options*

## Interface Settings


**Window**

| Row | Option |
|---|---|
| Play video inside the main window | `embedded-video` |
| Resize the window to fit the video | `qt-video-autoresize` |
| Show window decorations | `qt-titlebar` |
| Show the menu bar | `qt-menubar` |

**Playback Controls**

| Row | Option |
|---|---|
| Start in compact mode | `qt-minimal-view` |
| Keep the controls below the video | `qt-pin-controls` |
| Hide the mouse and controls after | `mouse-hide-timeout` |
| Show controls in fullscreen | `qt-fs-controller` |

**Notifications and System Tray**

| Row | Option |
|---|---|
| Show the system tray icon | `qt-system-tray` |
| Show a popup when the media changes | `qt-notification` |
| Start minimized to the tray | `qt-start-minimized` |
| Closing the window keeps VLC in the tray | `qt-close-to-system-tray` |

*Advanced Options*

## Subtitle Defaults


**Tracks & Languages**

| Row | Option |
|---|---|
| Enable subtitles | `spu` |
| Preferred language | `sub-language` |
| Text encoding | `subsdec-encoding` |

**Loading Subtitles**

| Row | Option |
|---|---|
| Load subtitle files automatically | `sub-autodetect-file` |
| File name matching | `sub-autodetect-fuzzy` |

**Appearance**

| Row | Option |
|---|---|
| Font | `freetype-font` |
| Bold | `freetype-bold` |
| Text color | `freetype-color` |
| Text opacity | `freetype-opacity` |
| Outline thickness | `freetype-outline-thickness` |
| Outline color | `freetype-outline-color` |
| Distance from the bottom | `sub-margin` |

**On Screen Display**

| Row | Option |
|---|---|
| Show messages on the video | `osd` |
| Show the media title when it starts | `video-title-show` |

*Advanced Options*

## Mouse & Keyboard Controls


**Keyboard Shortcuts**

| Row | Option |
|---|---|
| Shortcuts | (custom, see code) |
| Ignore the system volume keys | `qt-disable-volume-keys` |

**Skip Amounts**

| Row | Option |
|---|---|
| Very short skip | `extrashort-jump-size` |
| Short skip | `short-jump-size` |
| Medium skip | `medium-jump-size` |
| Long skip | `long-jump-size` |

**Mouse**

| Row | Option |
|---|---|
| Scroll wheel | `hotkeys-y-wheel-mode` |
| Horizontal scroll | `hotkeys-x-wheel-mode` |

## Playlists, Folders & Files


**Opening Files**

| Row | Option |
|---|---|
| Only allow one VLC window | `one-instance` |
| Apply to files opened from the file manager | `one-instance-when-started-from-file` |
| Add to the play queue instead of replacing it | `playlist-enqueue` |
| When opening a folder | `recursive` |
| Show hidden files | `show-hiddenfiles` |

**Metadata & Artwork**

| Row | Option |
|---|---|
| Fetch titles and artwork from the internet | `metadata-network-access` |

**Media Library**

| Row | Option |
|---|---|

## Global Settings


**Appearance**

| Row | Option |
|---|---|
| Theme | (custom, see code) |
| Accent color | (custom, see code) |

**Startup**

| Row | Option |
|---|---|
| Ask about network access on first start | `qt-privacy-ask` |
| Check for updates automatically | `qt-updates-notif` |

**Diagnostics**

| Row | Option |
|---|---|
| Save a log | `file-logging` |
| Log file | `logfile` |
| Log details | `log-verbose` |

*Advanced Options*
| Show minor warnings | `verbose` |
| Log format | `logmode` |
| Collect playback statistics | `stats` |

## Privacy Settings


**History**

| Row | Option |
|---|---|
| Remember the playback position | `restore-playback-pos` |
| Clear history now | (custom, see code) |

**Network**

| Row | Option |
|---|---|
| Fetch titles and cover art from the internet | `metadata-network-access` |
| Last.fm username | `lastfm-username` |
| Last.fm password | `lastfm-password` |
| Last.fm submission URL | `scrobbler-url` |

## Network Connections & Security


**Buffering**

| Row | Option |
|---|---|
| Local files | `file-caching` |
| Discs | `disc-caching` |
| Network streams | `network-caching` |
| Live capture | `live-caching` |

**Proxy**

| Row | Option |
|---|---|
| HTTP proxy | `http-proxy` |
| HTTP proxy password | `http-proxy-pwd` |

**Security**

| Row | Option |
|---|---|
| Verify certificates against the system trust store | `gnutls-system-trust` |
| Cipher preference | `gnutls-priorities` |

*Advanced Options*
| HTTP server address | `http-host` |
| HTTP server port | `http-port` |

## Performance Settings


**Decoding**

| Row | Option |
|---|---|
| Hardware-accelerated decoding | `hw-dec` |
| Decoder device | `dec-dev` |
| Skip the H.264 loop filter | `avcodec-skiploopfilter` |
| Decoding threads | `avcodec-threads` |

**Smooth Playback**

| Row | Option |
|---|---|
| Drop frames when the system can't keep up | `drop-late-frames` |
| Rescan plugins at the next start | `reset-plugins-cache` |

*Advanced Options*
| Preferred decoders | `codec` |
| Clock synchronisation | `clock-synchro` |
| Clock jitter | `clock-jitter` |
| Clock source | `clock-master` |

## Recording, Casting & Streaming Out


**Recording**

| Row | Option |
|---|---|
| Save recordings to | `input-record-path` |
| Record without re-encoding when possible | `input-record-native` |

**Casting**

| Row | Option |
|---|---|
| Cast quality | `sout-chromecast-conversion-quality` |

**Streaming**

| Row | Option |
|---|---|
| Play locally while streaming | `sout-display` |
| Include audio | `sout-audio` |
| Include video | `sout-video` |
| Include subtitles | `sout-spu` |
| Encoding preset | `sout-x264-preset` |
| Tuning | `sout-x264-tune` |

*Advanced Options*
| Stream all elementary streams | `sout-all` |
| Keep the stream output open | `sout-keep` |

## Add-ons & Scripts


**Add-ons**

| Row | Option |
|---|---|
| Plugins and extensions | (custom, see code) |
