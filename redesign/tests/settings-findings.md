# Settings findings (collected, not fixed)

Found by the settings tests (`settings_options.py`, `settings.txt` scenes, `check_settings.py`). The user asked to
collect these and plan the fixes later (2026-11-11). Each entry: what is wrong, where, how it was seen.

## Rows that cannot keep a change

| Row (page) | Option | Why | Seen |
|---|---|---|---|
| Use S/PDIF when available (Audio) | `spdif` | obsolete on Linux (`src/libvlc-module.c:1626`, `add_obsolete_bool` outside the platform branch): the row shows, Save drops it | load check, 2026-11-11 |
| HTTP proxy (Network) | `http-proxy` | obsolete since 4.0 on this system (`src/libvlc-module.c:1964`) | load check |
| HTTP proxy password (Network) | `http-proxy-pwd` | same as HTTP proxy | load check |
| Show minor warnings (General, Advanced) | `verbose` | never written to vlcrc (volatile) | load check |
| Rescan plugins at the next start (Performance) | `reset-plugins-cache` | never written to vlcrc (volatile) | load check |

## Full run (2026-11-11, second run after the harness fixes)

523 passed, 10 failed, 8 skipped (233 scenes + baseline). All 10 failures are the five rows above, each failing save
and reload: the row changes, Save drops the change, and after a restart it shows the old value again.
The 8 skips are the same five (never in vlcrc, so load cannot compare), Check for updates automatically
(`qt-updates-notif` is not in this build, the row is hidden), and Start minimized to the tray (no reload scene).

Not a finding: Last.fm submission URL and Preferred decoders were listed here as "shows empty" after the first run.
That was the harness reading text fields wrong; they show `post.audioscrobbler.com` and `any`.
