# 08 Decision records

Short records of choices that are not obvious from the code. Format: context, decision, consequences.
Add a new record rather than editing an old one; mark a replaced record *Superseded by ADR-NNN*.

## ADR-001 Port into VLC's real Qt interface, not the prototype
**Context.** The design existed as an HTML prototype with mock data. **Decision.** Implement it in
`modules/gui/qt` on VLC's own models; the prototype is a visual reference only. **Consequences.**
Every screen plays real media and uses real options; features without a VLC backend (OpenSubtitles
search, sleep timer, reverse) are left out rather than faked.

## ADR-002 Keep the branch rebase-able onto upstream
**Decision.** Prefer QML changes; keep C++ small; never reformat upstream files; log every change
outside the Qt QML in 04. Large refactors (e.g. splitting the ~1140-line `SPrefsPanel` constructor)
are declined for that reason. **Consequences.** Some code smells stay on purpose (CLAUDE.md lists them).

## ADR-003 Videos is a folder tree
**Context.** Upstream's Videos page groups videos by name; users add folders of series and seasons.
**Decision.** Videos (and Music) open on the library's entry points; folders show subfolders then
their own media; an address line and up/down back/forward navigate. Playlists become a top-level
entry. **Consequences.** The ML gives no recursive count, so a folder with only subfolders looks like
any folder; folders without videos at any depth are hidden in Videos.

## ADR-004 Play on a folder is recursive, A to Z
**Context.** Right-click Play on a series folder (only season subfolders) queued nothing.
**Decision.** Play queues the folder's own media A to Z, then each subfolder by name, recursively
(depth limit 32), skipping banned/missing folders; video menus open the player view.
**Consequences.** Large trees queue many items at once; it appends to the queue (VLC's behaviour),
which may surprise users (open question in 12).

## ADR-005 System title bar by default everywhere
**Context.** Client-side decorations looked inconsistent and lacked native features (snap layouts,
window menus) on some platforms. **Decision.** Since v0.1.5 the system title bar is the default on
Windows, Linux and macOS; the window title is not repeated inside the interface; in fullscreen the
player top bar shows the title. **Consequences.** The player's one-line 40 px top bar must not depend
on CSD (fixed 2026-11-01 after the harness caught a 32 px bar).

## ADR-006 Bars over the video show by edge proximity
**Decision.** In fullscreen (and with unpinned controls) the top bar shows only near the top, the
control bar only near the bottom, nothing in between; a key press shows both; locks keep the shown
bar. Pinned controls in a window keep both bars visible (the Figma video stage).
**Consequences.** The video surface's own pointer events drive the zones (it takes hover events).

## ADR-007 Restyle VLC's Widgets dialogs instead of rewriting them
**Decision.** Keep VLC's Open Media, Preferences classic pages, Effects, Messages etc. and theme them
through a palette and a shared stylesheet; only two dialogs are new QML (Open network stream, New
playlist). Keep the system title bar on dialogs. **Consequences.** Lower risk and full feature
parity; some dialogs look less like Figma.

## ADR-008 Settings as Figma rows bound to real options
**Decision.** Rows write their option only if the value differs from what they first showed; options
the classic Save writes itself are not rows; classic pages remain under Advanced Options.
**Consequences.** A Save can never undo the classic pages; `prefs-save` proves Save is a no-op when
nothing changed.

## ADR-009 No Canvas or QtQuick.Shapes
**Context.** Windows' contrib Qt has neither; one `Canvas` stopped the whole player from loading on
Windows (v0.1.0 was re-tagged). **Decision.** Draw with Rectangles, images and the icon font only.

## ADR-010 Fixed release asset names and full releases
**Decision.** Assets have no version in their names; every non-rc tag is a full release.
**Consequences.** `releases/latest/download/<name>` always serves the newest build and the website's
fallback links never change.

## ADR-011 Linux packages in /opt, built from the AppImage tree
**Context.** Users asked for deb, rpm and Arch packages and repositories. **Decision.** Package the
same self-contained tree as the AppImage (bundled Qt, `$ORIGIN` rpaths) into `/opt/vlc-juxtopposed`
with a `vlc-juxtopposed` command, using nfpm for all three formats; repositories on the fork's GitHub
Pages like Open Task Manager's. **Consequences.** Packages are large (~150 MB) but identical across
distributions and never conflict with the distribution's VLC; dependencies cover only what the tree
leaves to the system; a CI job installs them on five distributions.

## ADR-012 A separate package signing key
**Decision.** "VLC juxtopposed packages" (F092723FE6C0D16999EB7F6019D03339EB84F8FB), not Open Task
Manager's key, so trusting one project's repository does not trust the other's packages. Details in 09.

## ADR-013 Wayland is required in Linux builds
**Context.** Builds without VLC's Wayland outputs put video in an X11 window that a Wayland Qt
interface loses after a while. **Decision.** CI builds wayland-scanner 1.23 and configures with
`--enable-wayland`; `appimage.sh` refuses a tree without the Wayland outputs.

## ADR-014 Unofficial, credited
**Decision.** Name "VLC (juxtopposed)"; every page, release and package says it is unofficial and not
affiliated with VideoLAN; Juxtopposed is credited for the design. Windows update checks are off
(they pointed at VideoLAN's releases).
