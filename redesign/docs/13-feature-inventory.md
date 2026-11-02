# 13 Feature inventory: everything VLC (juxtopposed) has

A list of what the app can do: the redesigned interface first, then the VLC engine underneath it
(formats, codecs, filters, outputs, network, streaming, control). Written 2026-11-02.

**Sources.** The interface sections come from `modules/gui/qt` on branch `redesign`. The engine
sections come from the plugins of the local Linux build (`build/modules/.libs`, 427 plugins,
grouped by their folder under `modules/`). The released packages are built elsewhere (Ubuntu
24.04 for the Linux packages, a cross-build for Windows, macOS on arm64), so a few plugins differ
per platform: Linux-only ones are marked *(Linux)*. A plugin's presence means VLC can do it; it
does not mean the redesigned interface shows a button for it (see the last section).

Legend: **R** = added or redrawn by the redesign; everything else is upstream VLC 4.

---

## 1. Interface (what the user sees)

### Window and look
- **R** Day, Night and System colour schemes; accent colour setting (default #D37918), applied live.
- **R** Inter font bundled; icon font redrawn where the Figma needs it (transport glyphs).
- **R** System title bar by default; VLC's own window buttons as an option (Show window decorations).
- **R** Opens at 1280x800 centred (85% of a smaller screen).
- Upstream Qt/QML interface underneath; skins2 and ncurses interfaces are also built (not redesigned).

### Library (media library on)
- **R** Floating sidebar: Home, Videos, Music, Network, Playlists. Expanded while idle, collapsed during
  playback, toggle button.
- **R** Page header: back/forward (up/down in folder trees), address line (breadcrumb), item count,
  sort, list/grid, search, "..." page menu.
- **R** Home: Continue Watching (with progress, Remove from list), New Videos, New Music.
- **R** Videos as a folder tree: added folders, subfolders and videos together, A to Z by default,
  generated thumbnail tile when a video has none.
- **R** Music: folder tree with square covers; Albums, Artists, Genres, Tracks pages (upstream pages,
  restyled).
- **R** Network: saved streams list, Add Stream in the "..." menu, Open Network Stream dialog.
- **R** Playlists: list, New Playlist dialog (drop files, file chooser), "..." menu: Play, Shuffle,
  Export Playlist (.m3u), Add to Queue, Rename, Delete.
- **R** Folder "..." menu: Add File, Add Folder, Resync (also retries files that failed before), Info.
- One click plays or opens; right-click context menus; drag items into the play queue.
- Media library engine: indexing of chosen folders, thumbnails, playback history and resume
  positions, playlists, albums/artists/genres/shows grouping, folder banning, rescan.

### Player
- **R** Top bar 40 px with the title; bottom bar 55 px; bars over the video appear when the pointer
  nears the top or bottom edge.
- **R** Control bar (Default Style): library button, previous, 10 s back, play/pause, 10 s forward,
  next, times either side of the seek bar, volume wedge, audio, languages and tracks, settings panel,
  play queue, mini player, fullscreen.
- **R** Seek bar with chapter breaks and a preview thumbnail that follows the cursor.
- **R** Library rail and compact library card beside the video (Home, Videos, Music, Network,
  Playlists, Recent, Add); drag rows into the queue.
- **R** Resume prompt: "You already watched till HH:MM:SS", Continue Watching.
- **R** Enter or F toggles fullscreen; Escape leaves it.
- Customize Player (toolbar editor): 42 controls can be placed, including stop, record, snapshot,
  A to B loop, loop, random, faster/slower, playback speed, frame step, chapter previous/next,
  DVD menu, navigation box, teletext, program, renderer (casting), bookmarks, reverse, aspect ratio,
  high-resolution time, info, open, quit.

### Side panels and pickers
- **R** Tracks picker (Video, Audio, Subtitles tabs): track lists, None, external tracks (add, edit),
  audio output device with refresh.
- **R** Settings side panel: Subtitles and Audio delay with reset, playback speed, Equalizer,
  Compressor, Video Essential / Colors / Crop.
- The full Effects and Filters window (spatializer, stereo widener, video filters, sync) stays under
  Open Advanced Settings.

### Play queue and mini player
- **R** Play Queue panel: sort, search, + Add to the queue, rows show the file name when the title tag
  is empty; drag to reorder; context menu.
- **R** Floating mini player card (bottom right of the library): video preview, progress field, title,
  folder and artist, queue card (count and duration, sort, clear, add, click to play).
- Detached play queue window.

### Menus and dialogs
- **R** Main "..." menu: Open File(s), Open Folder, Open Network Stream, Open Disc, Open Capture Device,
  Convert, Open Recent, Keyboard Shortcuts, Customize Player, Settings, About, More (View, Tools,
  Help, Quit).
- **R** Right-click menu on the video with hotkey hints; menus drawn to the Figma (48 px rows).
- **R** Every Qt dialog follows Day/Night (message boxes, input boxes, Qt's own file dialog).
- Dialogs (upstream, restyled): Open Media (File, Disc, Network, Capture), Convert / Stream, Media
  Information and Codec details, Track Synchronization, Bookmarks, Jump to Time, Messages log,
  Plugins and extensions, Add-ons, Podcasts, Program guide (EPG), VLM, Fingerprint (AcoustID),
  first-run wizard, system tray icon.

### Settings
- **R** Figma-style Settings window with search and 13 categories: General, Interface, Privacy,
  Controls (hotkeys), Playback, Video, Audio, Subtitles, Library, Network, Performance, Recording,
  Extensions.
- Advanced Options: the classic Simple pages and the full tree of every module option.
- 114 rebindable hotkeys (global hotkeys too, through `xcb_hotkeys` on X11).

### Accessibility
- **R** Every enabled control at least 3:1 against its background (WCAG 1.4.11), text 4.5:1, small
  buttons 28 px targets; checked by the harness on every screen.
- Keyboard navigation through the whole interface; screen reader names (AT-SPI on Linux, UI
  Automation on Windows).

---

## 2. Opening media (inputs)

- **Local**: files, folders (plays a folder's own files before its subfolders), archives (`archive`:
  zip, rar, 7z, tar... opened as folders), drag and drop, file manager "Open with" (one instance).
- **Discs**: DVD with menus (`dvdnav`, `dvdread`), Blu-ray (`libbluray`), Audio CD (`cdda`, CD-Text
  and track names), VCD/SVCD (`vcd`).
- **Network protocols**: HTTP/HTTPS, HLS and DASH adaptive streaming (`adaptive`), HDS, FTP, SFTP,
  SMB/CIFS (`smbc`), WebDAV, NFS-like shares via the file system, RTSP/RTP (`rtp` with H.264, H.265,
  MPEG, Opus, PCM, raw payloads), UDP and multicast (`udp`, `amt`), SRT (`access_srt`), MMS, SDP,
  SAT>IP, Gopher, TCP, memory and shared-memory inputs.
- **Capture** *(Linux)*: webcams and TV cards (`v4l2`), ALSA/PulseAudio/PipeWire/JACK audio
  (`access_alsa`, `pulsesrc`, `pipewiresrc`, `access_jack`), screen capture (`xcb_screen`,
  `wl_screenshooter`), DVB/ATSC digital TV (`dtv`), FireWire (`dc1394`, `dv1394`), SDI (`linsys_*`).
- **Websites**: Lua parsers for Dailymotion, Vimeo, SoundCloud, Twitch, Jamendo, BBC, Newgrounds and
  others (`share/lua/playlist`); any site yt-dlp supports through `ytdl` (needs `yt-dlp` installed).
- **Playlists** (`playlist` demux): M3U/M3U8, PLS, XSPF, ASX, B4S, WPL, RAM, QTL, WMS, SGI MB,
  iTunes XML, podcast RSS, DVB channel lists, Blu-ray/DVD index files; CUE sheets through Lua.
- **Network discovery**: UPnP/DLNA and mDNS/Bonjour (`microdns`, `avahi`), SAP announcements, MTP
  devices, optical drives and USB disks (`udisks`, `udev`), audio capture devices (`pulselist`,
  `pipewirelist`), podcasts, internet radio directories (`radio`, Icecast and others in Lua).

## 3. Formats and codecs

### Containers (demuxers, 46)
MKV/WebM, MP4/MOV/M4A/3GP, AVI, MPEG-TS and PS (incl. DVB, Blu-ray m2ts), ASF/WMV, Ogg, FLV and
anything else via FFmpeg (`avformat`), WAV, AIFF, AU, CAF, FLAC, raw ES (MP3, AAC, AC-3, DTS),
H.264/H.265/VC-1 elementary streams, MJPEG, NSV, NuppelVideo, PVA, TiVo (`ty`), XA, VOC, TTA,
tracker modules (`mod`: MOD, S3M, XM, IT), game music (`gme`: NSF, SPC, VGM...), MIDI (`smf`, played
with `fluidsynth`), images, directories.

### Video and audio decoders (59 codec plugins)
- FFmpeg (`avcodec`): nearly every video and audio codec (H.264, HEVC, VP8/9, AV1, MPEG-1/2/4,
  ProRes, DNxHD, WMV, AAC, AC-3/E-AC-3, DTS, TrueHD, WMA, ALAC...).
- Dedicated: AV1 (`dav1d`, `aom`), VP8/VP9 (`vpx`, with alpha), Theora, FLAC, Opus, Vorbis, Speex,
  MP3 (`mpg123`, `mad`), AAC (`faad`), LPCM/AES3/ADPCM/G.711, raw video, JPEG/PNG/SVG images.
- Hardware decoding *(Linux)*: VA-API (`vaapi`, with DRM, Wayland and X11 devices) and VDPAU;
  Intel QSV encoder. On macOS: VideoToolbox (seen in CI).
- Encoders (for Convert/Stream): x264, x265, rav1e, AV1 (`aom`), VP8/9, Theora, Vorbis, Opus, FLAC,
  Speex, TwoLAME (MP2), FFmpeg's encoders.

### Subtitles
SRT, SSA/ASS (full styling with `libass`), WebVTT, TTML, USF, MicroDVD, SubViewer, MPL2, VobSub,
DVD and Blu-ray (PGS) subtitles, DVB subtitles, Teletext (`zvbi`, with page navigation), CEA-608/708
closed captions (`cc`), SCTE-18/27, 3GPP text, EBU STL, SVCD/CVD. Text rendered with FreeType
(fonts, outline, shadow, background); subtitle delay; automatic loading of matching files;
OpenSubtitles search through the VLSub extension.

## 4. Audio

- **Outputs** *(Linux)*: PipeWire, PulseAudio, ALSA, JACK, sndio, file output; S/PDIF and HDMI
  passthrough (`spdif`, `tospdif`).
- **Filters (30)**: 10-band equalizer with presets, parametric EQ, compressor, limiter, gate,
  expander, volume normalizer, EBU R128 loudness meter, spatializer (room), stereo widener, stereo
  pan, headphone virtualization, Dolby Surround decoder, channel remapping and mixing, mono,
  karaoke (voice removal), chorus/flanger, gain, scaletempo (speed without pitch change) and pitch
  shift, high-quality resampling (`soxr`, `speex_resampler`, `samplerate`).
- Audio delay (A/V sync), audio track and device switching, volume up to 125% (configurable),
  replay gain.
- **Visualizations**: spectrum, scope, VU meter (`visual`), 3D spectrum (`glspectrum`).

## 5. Video

- **Outputs** *(Linux)*: OpenGL/GLES (EGL on Wayland, X11, GBM), libplacebo (HDR tone mapping, high
  quality scaling), Wayland shm/xdg-shell, XCB/X11, KMS/DRM (no desktop), caca (ASCII), memory and
  external outputs. Windows uses Direct3D/DirectComposition, macOS its own.
- **Filters (45)**: deinterlacing (many modes, SIMD), adjust (brightness, contrast, hue, saturation,
  gamma), sharpen, denoise (`hqdn3d`), deband (`gradfun`), crop/pad, rotate, transform/flip, zoom
  (`magnify`), scale, grain, Gaussian blur, motion blur, anti-flicker, posterize, sepia, invert,
  edge detection, colour threshold, erase, wave, ripple, psychedelic, puzzle, mirror, old movie,
  VHS, anaglyph 3D, mosaic, wall and panoramix (split over several screens), clone, FPS change,
  scene snapshots.
- **Overlays**: logo, marquee text, RSS ticker, mosaic, audio bar graph, dynamic overlay.
- Aspect ratio, crop and zoom presets; snapshots; frame stepping; 360 video and VR viewpoint
  (OpenGL output).

## 6. Playback control

- Playback speed (slower/faster, a speed pill in the side panel), A to B loop, loop one/all,
  random, reverse (negative rate: only where the input can play backwards, which is rare), chapters and titles, bookmarks, jump to time, frame step,
  record the current stream to a file, resume where you left off.
- Programs (MPEG-TS channels) and EPG; DVD/Blu-ray menus with keyboard navigation.
- Sleep timer: not in VLC (noted in `12-known-issues-and-roadmap.md`).

## 7. Convert, stream and cast

- Convert/Save to MP4, MKV (via FFmpeg), WebM, Ogg, TS, PS, AVI, ASF, WAV, MPJPEG (`mux_*`) with
  transcoding profiles.
- Stream out over HTTP, HLS (`livehttp`), RTP/RTSP, UDP, SRT, Icecast/Shoutcast (`shout`), to a file,
  with duplication, delay, mosaic bridge and stats (`stream_out_*`, 23 modules).
- Casting to Chromecast (`stream_out_chromecast`, Renderer button and menu).
- VLM (scheduled broadcasts and video on demand).

## 8. Remote control and integration

- **MPRIS over D-Bus** *(Linux)*: desktop media keys, KDE/GNOME media widgets, `playerctl`.
- Screensaver/idle inhibition while playing (D-Bus, XDG, Wayland idle-inhibit).
- Lua interfaces: web interface and HTTP API (`http.lua`), telnet, command line (`cli.lua`), remote
  control (`rc`), mouse gestures.
- Desktop notifications on media change (`notify`); Last.fm scrobbling (`audioscrobbler`).
- Passwords for network shares stored in KWallet or the Secret Service (GNOME Keyring), a file, or
  memory.
- Logging to the console, a file, syslog or the systemd journal; JSON tracer.

## 9. Extensions and metadata

- Lua extensions (VLSub included), add-ons manager (skins, extensions, playlist parsers from the
  add-ons repository).
- Metadata: tags read with TagLib (ID3, Vorbis comments, MP4, APE...), cover art from the folder or
  the file, online art and metadata fetchers, AcoustID audio fingerprinting.

## 10. Platforms and distribution (redesign)

- **R** Windows 10/11 x64: installer (next to VideoLAN's VLC) and portable zip; not code-signed.
- **R** Linux x86_64: AppImage, tar.gz, deb (Debian 13, Ubuntu 24.04+), rpm (Fedora, openSUSE), Arch
  package; signed apt and pacman repositories; Wayland and X11.
- **R** macOS 13+ on Apple silicon: dmg, not notarized; the video area is unverified on a real Mac.
- **R** Releases carry SHA256SUMS and GitHub build attestations.

---

## Built but not reachable from the redesigned interface

| What | Where it went | How to reach it now |
|---|---|---|
| Discover pages (services, URL page) | Removed from the sidebar | Not reachable (`DiscoverDisplay` remains in the code) |
| Browse devices (SMB/UPnP browser) | Removed from the Network page | Not reachable from the library |
| Spatializer, stereo widener, video filters, sync | Not in the side panel | Settings panel > Open Advanced Settings (Effects window) |
| View/Tools/Help menus in the library top bar | The top bar lost the cone and menu | "..." menu > More |
| skins2 and ncurses interfaces | Out of the redesign's scope | `--intf skins2`, `--intf ncurses` |
| Classic preferences | Behind the Figma Settings | Settings > Advanced Options |

Features in the Figma that VLC has no engine for (sleep timer, waveform seek bar, subtitle
timeline, bookmarks panel, onboarding, setting presets) are listed in
`12-known-issues-and-roadmap.md`.
