# Engine test plan (future work)

Status: planned 2026-11-13, nothing built. The redesign's own tests (`scenarios.txt`, `check.py`, the
Settings suite, the Qt unit tests) cover the interface. This plan covers the VLC engine underneath:
formats, codecs, filters, outputs, network inputs, streaming, casting (the inventory is
`redesign/docs/13-feature-inventory.md`, sections 2-9).

## Why test the engine at all

The engine is upstream code with upstream tests, and this fork does not change it (apart from a few
core patches listed in CLAUDE.md). What can still break here is **our builds and packages**: a plugin
missing from a package, a library not bundled, a configure option that silently turned a feature off.
That has already happened: every Linux package up to v0.1.6 was built without VLC's Wayland video
outputs (Ubuntu's wayland-scanner was too old; configure only warned), and the AppImage once shipped
without Qt's Wayland and SVG plugins. So the tests below check **what the released files can do**,
not VLC's algorithms, and they run against the packages, not only the build tree.

## What upstream already tests (run it, do not rewrite it)

`make check` in `test/` (libvlc media, player, media list, thumbnails, equalizer, slaves, renderer
discovery; core clock, config, input streams, preparser, audio output; demux units for MP4, TS PES,
timestamps, JSON; packetizers H.264, HEVC, H.266, MPEG video; CEA-708; WebVTT mux; Lua playlist
parsers and extensions; TLS, keystore, medialibrary). Samples in `test/samples`.

**Step 0:** run `make check` (top level `test/`) in the Linux build workflow, next to the Qt unit
tests. Expected cost: one CI step, ~10-20 min. Failures there are upstream's or a core patch of ours.

## Layers

### Layer 1: plugin inventory per package (cheap, catches the class of bug we actually had)

- For each released file (AppImage, tar.gz, deb, rpm, Arch, Windows zip/installer, macOS dmg) list the
  plugins VLC loads: `vlc --list` (or `vlc -vv --list-verbose`) with the package's own plugin path.
- Compare with the must-have list per platform (`redesign/tests/engine/must-have-<platform>.txt`): a
  missing must-have plugin fails the run; other added or removed plugins are reported (see Decisions).
- Must-have lists per platform, for example Linux: `wl_shm`, `egl_wl`, `xdg-shell`, `xcb_window`,
  `gl`, `libplacebo`, `pulse`, `pipewire`, `alsa`, `avcodec`, `dav1d`, `vaapi`, `libass`,
  `freetype`, `adaptive`, `smbc`, `stream_out_chromecast`, `microdns`, `dbus` (MPRIS), `medialibrary`.
- Also: every plugin loads (`vlc-cache-gen` reports no "stale" or unloadable plugin; `ldd` finds every
  library inside the package for AppImage/tar.gz).
- Where: the existing package jobs (`redesign-linux-packages.yml` install-test on each distro,
  `redesign-windows.yml` shots job, `redesign-macos.yml` smoke test). Effort: ~1 day.

### Layer 2: playback matrix with generated media

Media is generated in CI with ffmpeg (no binary samples in git): a short test pattern
(`testsrc2`, 2 s) with a sine tone, so a decoded frame and the audio can be checked against known values.

Each case runs the package's VLC headless:
`vlc -I dummy --play-and-exit --vout=dummy --aout=afile --audiofile-file=out.wav -vv <file>`
and passes when:
1. the log names the expected modules (`using demux module "mkv"`, `using video decoder module "avcodec"`),
2. there is no `error` line from the demux/decoder,
3. a frame grabbed with the scene filter (`--video-filter=scene --scene-format=png --scene-ratio=25`)
   shows the testsrc2 colour bars at the expected places (pixel check, tolerance for lossy codecs),
4. `out.wav` holds the tone (RMS and dominant frequency within a tolerance), and its length matches.

Matrix (each row is one generated file; ffmpeg must be able to encode it):

| Group | Cases |
|---|---|
| Containers | MKV, WebM, MP4/MOV, AVI, MPEG-TS, MPEG-PS, Ogg, FLV, ASF/WMV, 3GP, WAV, AIFF, FLAC, MP3, AAC (ADTS), raw H.264/HEVC ES |
| Video codecs | H.264, HEVC (8 and 10 bit), AV1, VP8, VP9, MPEG-1, MPEG-2, MPEG-4 Part 2, Theora, MJPEG, ProRes, DNxHD, FFV1, WMV2 |
| Audio codecs | AAC, MP3, AC-3, E-AC-3, Opus, Vorbis, FLAC, ALAC, PCM (s16/s24/f32), MP2, WMA2, multichannel 5.1 AC-3 and Opus (downmix to stereo checked) |
| Subtitles | SRT, ASS (a styled line), WebVTT, TTML, MicroDVD, external `.srt` next to the file (autoload), embedded MKV tracks, MP4 tx3g, DVB subtitles in TS, CEA-608 in H.264. Checked by rendering: the scene snapshot contains white text pixels in the subtitle area; with `--sub-track` the right language |
| Images | PNG, JPEG, SVG as media |
| Playlists | M3U, M3U8, PLS, XSPF, ASX, CUE (each pointing at two generated files: both play, in order) |
| Seeking | seek to 50% in each container (`--start-time`), frame at the right timestamp (the testsrc2 counter) |

Effort: ~3-4 days for the script (`redesign/tests/engine/matrix.py`) and the first platform; most work is
the pass criteria. Run time: ~10 min per platform.

### Layer 3: filters

- **Audio** (afile output, compare with the unfiltered run): equalizer preset (band energy changes),
  compressor and normvol (peak lowered), gain, karaoke (centre removed: a mono tone cancels), mono,
  channel remap, scaletempo at 1.5x (duration /1.5, pitch unchanged: same dominant frequency),
  pitch shift (frequency moves), spatializer and stereo widener (left/right differ from the input).
- **Video** (scene snapshot pixel checks): adjust (saturation 0 = grey bars), invert (colours inverted),
  transform/rotate (bars rotated), crop (`--crop` changes the frame size), deinterlace on an
  interlaced test file (combing gone: line difference metric), sharpen/blur (edge energy up/down),
  logo and marquee overlays (their pixels present), aspect ratio forcing (frame size).
- Effort: ~2 days. Run time: ~5 min.

### Layer 4: outputs (needs the harness's nested session)

- Video outputs: Wayland (`wl_shm`, EGL), X11 (`xcb`), OpenGL, libplacebo: play in the nested KWin with
  `--vout=<module>` and check a screenshot shows the test pattern.
- Audio outputs: PulseAudio and PipeWire with a null sink inside the nested session, record the
  monitor and check the tone. This also unblocks the redesign test "volume bar when a video starts".
- Hardware decoding (VA-API, VDPAU, VideoToolbox, D3D11): no GPU on GitHub runners. Manual checklist
  item per release, or a self-hosted runner later.

### Layer 5: network inputs (local servers in the runner, no internet)

| Protocol | Local server |
|---|---|
| HTTP/HTTPS | `python3 -m http.server`; HTTPS with a self-signed cert and `--no-gnutls-system-trust` + the cert |
| HLS, DASH | ffmpeg `-f hls` / `-f dash` into a folder served over HTTP; also a live HLS (sliding playlist) |
| RTSP/RTP | `mediamtx` (single binary) fed by ffmpeg |
| UDP / multicast | ffmpeg `-f mpegts udp://127.0.0.1:1234` and `udp://@239.0.0.1:1234` |
| SRT | ffmpeg `srt://` listener |
| FTP, SFTP | `pyftpdlib`; `sshd` in a container |
| SMB | a Samba container (also checks the KWallet/Secret Service password storage separately) |
| UPnP/DLNA, mDNS | `minidlna` container; `avahi-publish` services: the discovery modules list them |

Pass: playback as in Layer 2 plus the expected access module in the log. Effort: ~3 days (servers are
the work). Run time: ~10 min.

### Layer 6: streaming out and Convert

- Convert (the dialog's profiles): `--sout '#transcode{...}:std{access=file,mux=...,dst=out}'` for each
  profile in the Convert dialog (H.264+MP3 MP4, VP8+Vorbis WebM, Theora Ogg, MP3/FLAC/CD audio, ...);
  `ffprobe` checks container, codecs, duration and frame count of the output.
- Stream out: HTTP, HLS (`livehttp`), RTP/RTSP, UDP, SRT; a second VLC or ffprobe reads the stream and
  checks it as in Layer 2. Icecast (`shout`) against an icecast2 container.
- Record button: `--input-record-path` + the record hotkey on a stream, the file is playable.
- Effort: ~2 days. Run time: ~10 min.

### Layer 7: casting

- Chromecast: no device in CI. Two levels:
  1. discovery: publish a fake `_googlecast._tcp` service with `avahi-publish`; the renderer list
     (`microdns` renderer discoverer, upstream's `test_libvlc_renderer_discoverer` style) shows it;
  2. a fake receiver: a small Python server speaking the Cast v2 protocol (TLS + protobuf) far enough
     to accept `LOAD` and fetch the HTTP stream VLC serves; check that the stream is valid H.264/AAC.
     This is the expensive part (~3-4 days); until then, a manual check with a real Chromecast per release.
- Effort: discovery ~0.5 day; fake receiver later.

### Layer 8: discs and capture

- DVD: build a small DVD-Video ISO with `dvdauthor` + `xorriso` from a generated MPEG-2 file, play it
  (`dvd://` on the ISO) and check the menu/title module in the log. Blu-ray (`libbluray`): no free
  authoring tool; manual. Audio CD (`cdda`): manual (no drive).
- Capture: `v4l2loopback` is not loadable on GitHub runners; manual, or a self-hosted runner.
  Screen capture (`xcb_screen`) can run in the nested session: capture it, check the frame.

### Layer 9: control and integration

- MPRIS: in the nested session, `playerctl` / `dbus-send` play, pause, next, metadata (Linux packages).
- Lua HTTP interface: `--extraintf http --http-password x`, `curl` status.json, play/pause commands.
- Telnet and `rc`/`cli` interfaces: scripted commands (upstream has `test/modules/lua/telnet.sh`).
- Screensaver inhibition: D-Bus call observed with `dbus-monitor` while playing.
- Notifications (`notify`), Last.fm (`audioscrobbler` against a local fake endpoint).

## Where and when it runs

- A new workflow `redesign-engine.yml`: on `workflow_dispatch`, weekly (schedule), and before a
  release (the release runbook gets a line: engine run green on the tagged commit). Not on every push:
  ~45-60 min per platform.
- Linux first (the build image and the packages), then Windows (portable zip on `windows-latest`,
  Layers 1, 2, 3, 6), then macOS (Layers 1, 2).
- Output: a report like the harness one (`engine-report.html`: per case module names, pass/fail,
  the frame snapshot), uploaded as an artifact. A failed case fails the workflow.

## Order of work

| Step | What | Effort | Value |
|---|---|---|---|
| 0 | Upstream `make check` in CI | 0.5 day | catches core patch regressions |
| 1 | Plugin inventory per package | 1 day | catches the bugs we actually shipped |
| 2 | Playback matrix (Linux build tree, then packages) | 3-4 days | formats/codecs per release |
| 3 | Convert and stream out | 2 days | the Stream/Convert menu entries end to end |
| 4 | Network inputs | 3 days | Network page, Open Network Stream |
| 5 | Filters | 2 days | the side panel effects (Equalizer, Compressor, Video Colors/Crop) for real |
| 6 | Outputs with null sinks | 1-2 days | also unblocks the volume test |
| 7 | Control/integration | 1-2 days | media keys, desktop widgets |
| 8 | Casting discovery, then the fake receiver | 0.5 + 3-4 days | the Renderer button |
| 9 | Discs, capture | 1 day + manual items | rarely used |

## Decisions (2026-11-13)

- **Plugin lists: strict on a must-have set, report the rest.** A must-have plugin missing from a package
  fails the run; any other added or removed plugin is listed in the report as a warning. Reason: upstream
  adds, renames and drops plugins on every rebase, so a strict full list would fail for reasons that are
  not bugs and get ignored; the must-have set is what users actually notice (video and audio outputs,
  the main decoders, subtitles, network access, library, MPRIS). The must-have lists live in
  `redesign/tests/engine/must-have-<platform>.txt` and are edited on purpose.
- **Hardware decoding and capture: manual checks per release, no self-hosted runner.** A self-hosted
  runner means a machine of the user's kept online and running CI code; not worth it for two items.
  The release runbook (`06-release-runbook.md`) gets a short manual list: VA-API playback of an HEVC file
  on the user's Linux machine (`--avcodec-hw=vaapi`, log says `using ... vaapi`), a webcam in Open
  Capture Device. Exception: the macOS runner already decodes with VideoToolbox (seen in CI), so the
  macOS engine job checks the log for it automatically.
- **Test servers: GitHub service containers.** Samba, minidlna and icecast2 run as service containers of
  the Linux engine job (free, no setup outside the workflow, Linux jobs only); HTTP, HLS, DASH, UDP, SRT,
  FTP and RTSP use small processes in the job itself (python, ffmpeg, mediamtx). Windows and macOS engine
  jobs skip the network layer; their network code is the same upstream code, and the Linux job covers it.
