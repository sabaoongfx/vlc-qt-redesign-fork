# 11 User guide and FAQ

VLC (juxtopposed) is VLC media player with a redesigned interface by Juxtopposed. It plays everything
VLC plays. It is unofficial and not affiliated with VideoLAN.

## Install

**Windows 10/11:** run `VLC-juxtopposed-x64-setup.exe`. It is not code-signed yet: if SmartScreen
stops it, choose *More info*, then *Run anyway*. Or unzip the portable zip and run `vlc.exe`.

**Linux, any distribution:** `chmod +x VLC-juxtopposed-x86_64.AppImage && ./VLC-juxtopposed-x86_64.AppImage`

**Debian, Ubuntu (with updates):**
```bash
curl -fsSL https://sabaoongfx.github.io/vlc-qt-redesign-fork/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/vlc-juxtopposed.gpg
echo "deb [signed-by=/usr/share/keyrings/vlc-juxtopposed.gpg] https://sabaoongfx.github.io/vlc-qt-redesign-fork stable main" \
  | sudo tee /etc/apt/sources.list.d/vlc-juxtopposed.list
sudo apt update && sudo apt install vlc-juxtopposed
```

**Arch, Manjaro (with updates):**
```bash
curl -fsSL https://sabaoongfx.github.io/vlc-qt-redesign-fork/KEY.gpg | sudo pacman-key --add -
sudo pacman-key --lsign-key "VLC juxtopposed packages"
printf '\n[vlc-juxtopposed]\nServer = https://sabaoongfx.github.io/vlc-qt-redesign-fork/arch/$arch\n' \
  | sudo tee -a /etc/pacman.conf
sudo pacman -Sy vlc-juxtopposed
```

**Fedora, openSUSE:** download `VLC-juxtopposed-x86_64.rpm` and `sudo dnf install ./VLC-juxtopposed-x86_64.rpm`
(openSUSE: `sudo zypper install ./VLC-juxtopposed-x86_64.rpm`).

**macOS 13+ (Apple silicon):** open the dmg and drag the app to Applications. The first time macOS
blocks it: open *System Settings > Privacy & Security* and choose *Open Anyway*.

## Using it

**Library.** The sidebar has Home, Videos, Music, Network and Playlists. Add folders with *Open Folder*
(Ctrl+F) or by dropping a folder on the window; they appear in Videos and Music.

- **Videos / Music** show your folders. Click a folder to open it, click a video to play it. The
  address line at the top shows where you are; click a part of it to go back there. Back and forward
  go up and down the folders.
- **Right-click** a folder or video: *Play* plays it (a folder with its subfolders, A to Z), *Enqueue*
  adds it to the play queue, *Add to a playlist*, and for added folders *Remove from list*.
- **Search** filters the current page as you type; **sort** and **grid/list** are next to it.
- **Home** shows Continue Watching and New Videos. *Remove from list* takes a video out of Continue Watching.
- **Network** lists streams you saved; add one with *Add Stream* in the "..." menu (or Ctrl+N).
- **Playlists**: create one with the New Playlist button; its "..." menu plays, shuffles, exports
  (.m3u), renames or deletes it.

**Player.**
- The bottom bar: library card button, previous, 10 s back, play/pause, 10 s forward, next; volume
  and the panels (tracks, subtitles, effects, play queue) on the right.
- Hover the seek bar to preview a frame. If you watched part of a video before, a prompt offers to
  continue from where you stopped.
- In fullscreen (F11 or double-click), move the pointer to the top or bottom edge to show that bar.
- The library button opens a small library beside the video; drag items from it into the play queue.
- Right-click the video for the full menu.

**Mini player.** While something plays and you browse the library, a card at the bottom right shows
it; its queue button lists what's next.

**Settings** (Ctrl+P, Cmd+, on Mac): categories on the left, search at the top. Classic VLC settings
are under *Advanced Options*. Theme: System, Day or Night.

## Keyboard shortcuts (interface)

| Keys | Action | Keys | Action |
|---|---|---|---|
| Ctrl+O | Open | Ctrl+P | Settings |
| Ctrl+Shift+O | Open file | Ctrl+L | Play queue |
| Ctrl+F | Open folder | Ctrl+H | Minimal view |
| Ctrl+N | Network stream | F11 | Fullscreen interface |
| Ctrl+D | Disc | F10 | Menu |
| Ctrl+I | Media information | F1 | Help |
| Ctrl+E | Effects and filters | Ctrl+Q | Quit |
| Ctrl+M | Messages | Ctrl+= / Ctrl+- | Bigger / smaller interface |

Playback keys (space, arrows, f, m...) are VLC's hotkeys, listed in Settings > Controls.

## FAQ

**Is this official VLC?** No. It is VLC's code with a new interface, built and published by Sabaoon.
VideoLAN did not make or endorse it.

**Does it replace my VLC?** No. It installs separately (its own folder, menu entry and uninstaller) and
can sit next to VideoLAN's VLC. On Windows and macOS both share VLC's settings folder; on Linux too
(`~/.config/vlc`).

**Why does Windows/macOS warn when I open it?** The builds are not code-signed or notarized yet. Each
release has SHA256SUMS and GitHub build attestations if you want to verify a download.

**A video plays for a minute and then ends.** Check that the file is complete: files still being
downloaded (e.g. by a torrent client) have empty parts that VLC skips.

**On Linux the video disappeared after a while (v0.1.5 and older AppImages).** Fixed in v0.1.6. With an
older AppImage, start it with `QT_QPA_PLATFORM=xcb`.

**Where are my settings?** Windows `%APPDATA%\vlc`, Linux `~/.config/vlc`, macOS `~/Library/Preferences/org.videolan.vlc`.
Renaming `vlc-qt-interface.ini` (Windows) or `vlc-qt-interface.conf` (Linux) resets the interface
layout, e.g. an old control bar.

**How do I report a bug?** GitHub Issues are not enabled on the repository yet (an open item in 12).
Whatever the channel, include your platform, the version and the steps; a log helps: run with
`--verbose=2 --file-logging --logfile=vlc.log`.
