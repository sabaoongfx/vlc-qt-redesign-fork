# Prototype -> Qt design token map (Phase 0)

Source of truth for prototype values: `sabaoongfx/vlc` `css/app.css` (`:root` and `[data-theme="light"]`).
Qt colours are defined in `modules/gui/qt/style/systempalette.cpp`
(`makeDarkPalette()` / `makeLightPalette()`), keyed by `ColorSet` x `Bg|Fg|Decoration` x `Primary|Secondary|...` x state.
Accent comes from the `accentColor` option handled in `systempalette.cpp` (`orange500`).
Sizes/spacing/fonts live in `modules/gui/qt/style/VLCStyle.qml` (all via `MainCtx.dp()`).

## Colour (dark)

| Prototype var | Value | Qt target (to confirm in Phase 1) |
|---|---|---|
| --accent | #D37918 | `orange500` / `Bg Primary Pressed` family |
| --accent-mid / --accent-dim | #AB6314 / #371F06 | accent hover / pressed variants |
| --on-accent | #1a0e02 | Fg on accent surfaces |
| --lib, --panel | #0E0E0E | `View` Bg Secondary (currently black) |
| --nav, --rail, --bar, --card | #191919 / #1B1B1B | `View`/`Window` Bg Primary (`darkGrey300`) |
| --side | #161616 | side panel Bg |
| --field, --search | #090909 / #151515 | text-field Bg |
| --fg / --fg-2 / --dim / --dimmer | #E3E3E3 / #BDBDBD / #8F8F8F / #5F5F5F | Fg Primary / Secondary / disabled |
| --line / --line-2 | #373737 / #262626 | Decoration Border / Separator |
| --menu / --menu-hover | #232323 / #191919 | menu Bg normal / hovered |
| --dlg / --dlg-head | #1A1A1A / #090909 | dialog Bg |
| --video-bg | #2A2927 | video surface placeholder |

## Colour (light)
Prototype light values are in `css/app.css` `[data-theme="light"]` (bar #ABAAAA, lib #D2D2D1, fg #151515, ...).
Map to `makeLightPalette()` the same way as dark.

## Other
- Font: Inter, "Segoe UI", system-ui (check `VLCStyle.qml` font handling before bundling Inter).
- Shadow: 0 10px 40px rgba(0,0,0,.55) dark / .3 light -> `Decoration Shadow`.
- Radii, spacing, type scale, icon sizes: extract from prototype CSS in Phase 1 and map to `VLCStyle.qml`
  `margin_*`, `fontMetrics_*`, `icon_*`, radius properties.

## Open items
- Verify each "Qt target" against the actual `setColor(...)` calls before editing.
- Confirm Qt is enabled in the CI image's default `./configure` (check the build log).
