# 04 Upstream divergence log

Every place the fork differs from upstream VLC (`videolan/vlc`, remote `upstream`), so a rebase keeps
them and upstream patches can be picked out. Base: `dd056f2640` (2026-10-20, "stream_output: fix leak
on clock bus"); 457 commits on top. Regenerate the file lists with:

```bash
MB=$(git merge-base HEAD upstream/master)
git diff --stat $MB HEAD -- . ':!modules/gui/qt' ':!redesign' ':!.github'   # outside the Qt module
git diff --stat $MB HEAD -- modules/gui/qt                                   # the Qt module (304 files)
```

Risk: **high** = core or shared code other modules use; **medium** = Qt module C++; **low** = QML,
assets, packaging only.

## Outside the Qt module

| File | Change | Why | Risk | Upstream candidate |
|---|---|---|---|---|
| `src/input/item.c` (`rdh_compar_type`) | A folder opened for playback lists its own files before its subfolders | A "Sample" subfolder sorted before the episodes and played first | high | Yes, as an option or with discussion |
| `include/vlc_media_library.h` | `vlc_ml_list_subfolders()`, `vlc_ml_count_subfolders()` inline wrappers | Folder tree; the ML already had `VLC_ML_LIST_SUBFOLDERS` without a wrapper | low | Yes |
| `modules/misc/medialibrary/Thumbnailer.cpp` | Timeout 3 s to 15 s; seek PRECISE instead of FAST | Long HEVC episodes timed out; fast seek gave grey frames on 4K videos with few key frames | medium | Maybe (cost: slower thumbnails) |
| `extras/package/win32/build.sh` | No `--enable-update-check` | It pointed at VideoLAN's releases | low | No |
| `extras/package/win32/NSIS/vlc.win32.nsi.in` | Own product name, folder, registry key, uninstall entry, product id; quoted `${PRODUCT_PUBLISHER}` paths | Install next to VideoLAN's VLC | low | No |
| `po/POTFILES.in` | Deleted Qt files removed | Files removed below | low | n/a |
| `extras/package/redesign/*` | New: `appimage.sh`, `linux-packages.sh`, `get-nfpm.sh`, `make-arch-repo.sh`, `apt-distributions`, `macapp.sh`, `macos-build.sh` | Packaging (05) | low | No |
| `.github/workflows/redesign-*.yml` | New CI | 05 | low | No |
| `CLAUDE.md`, `redesign/` | Notes, plans, harness, these docs | | low | No |

## Qt module C++ (medium risk)

Largest changes first (lines changed, `git diff --stat`).

| File | Change |
|---|---|
| `dialogs/preferences/simple_preferences.cpp/.hpp` | Settings rebuilt as Figma row pages (`SettingsRows`, search index), 13 categories; fixes for two upstream Save bugs (list combos with an out-of-list value showed the first choice; font combos rewrote a generic family): keep both |
| `menus/menus.cpp/.hpp` | `RedesignMenuStyle` (QProxyStyle for QMenu: card, rows, right-aligned shortcuts, sections), hotkey hints in action text |
| `medialibrary/mlvideofoldertreemodel.cpp/.hpp` | New folder tree model |
| `tests/test_navigation_model.cpp` | Rewritten for the new sidebar (not built in CI, never run) |
| `player/effects_controller.cpp/.hpp` | New: equalizer, compressor, video adjust/crop for the side-panel cards |
| `menus/qml_menu_wrapper.cpp/.hpp` | Export Playlist (M3U), playlist menu actions |
| `medialibrary/medialib.cpp/.hpp` | Folder Play recursion; `recordVisit`; helpers for the compact library |
| `player/seek_preview.cpp/.hpp` | New: seek bar preview thumbnails via the preparser |
| `style/systempalette.cpp/.hpp`, `style/redesign.hpp` | Figma palettes, Widgets palette, shared helpers |
| `dialogs/preferences/preferences.cpp` | Window chrome, centring (`showEvent`) |
| `widgets/native/qvlcframe.cpp/.hpp` | Shared Widgets stylesheet; `styleStockDialogs()` event filter for QMessageBox/QInputDialog/QProgressDialog |
| `dialogs/toolbar/controlbar_profile_model.cpp` | Default Style bar (library button, 10 s buttons); migration of saved old Default Styles |
| `qt.cpp` | Inter font, title bar default, `qt-accent-color`, options |
| `medialibrary/mlrecentaudiomodel.cpp` (new), `mlrecentvideomodel.cpp` | Recent audio; Continue Watching "Remove from list" |
| `util/navigation_history.cpp/.hpp` | `next()`/`nextEmpty` (forward) |
| `dialogs/dialogs_provider.cpp/.hpp` | `releaseMouseEvents` restored (right-click on video, upstream 64e6301a6c lost it), stock dialog styling hook |
| `util/audio_device_model.*`, `player/input_models.cpp` | `refresh`, "external" track role |
| `maininterface/navigationmodel.cpp`, `mainui.cpp`, `mainctx.cpp`, `interface_window_handler.cpp`, `videosurface.cpp` | Sidebar entries, model registration, window size/placement, mouse release reporting |
| `player/control_list_model.hpp` | `LIBRARY_BUTTON` = 0x2B (was `RESERVED_0X2B`): a new control id; upstream may assign 0x2B differently, check on rebase |
| `medialibrary/mlurlmodel.cpp` | Saved streams for Network |
| `dialogs/firstrun/firstrunwizard.cpp`, `menus/custom_menus.cpp`, `widgets/native/interface_widgets.cpp`, `style/vlcicons.hpp`, `preferences_widgets.cpp` | Small styling and behaviour changes |

Deleted from upstream: `medialibrary/mlvideofoldersmodel.cpp/.hpp`,
`medialibrary/qml/VideoAllDisplay.qml`, `VideoAllSubDisplay.qml`, `VideoGroupDisplay.qml` (replaced
by the folder tree). `DiscoverDisplay` pages remain but are unreachable.

## Qt module QML and assets (low risk, large)

136 files added in the module, most of them QML pages/controls, SVG icons (`pixmaps/icons/redesign/`),
Inter fonts (`pixmaps/Inter-*.ttf`, OFL licence), and the regenerated `pixmaps/VLCIcons.ttf`. QML
diverges in almost every page; a rebase conflict there is resolved by keeping the fork's version and
re-applying upstream's functional fixes by hand.

## Rebase checklist

1. `git fetch upstream && git rebase upstream/master` on a branch, not on `redesign`.
2. Keep the high-risk changes above (re-read their diffs; they are small).
3. Check `control_list_model.hpp` ids, `Makefile.am` and `meson.build` file lists.
4. Build, run the full harness (07), compare QML warnings with the last run.
5. Run CI on the branch; merge only with every workflow green.
