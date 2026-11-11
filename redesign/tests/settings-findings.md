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

## Rows that show the wrong value

| Row (page) | Option | Shows | vlcrc default | Seen |
|---|---|---|---|---|
| Last.fm submission URL (Privacy) | `scrobbler-url` | empty | `post.audioscrobbler.com` | load check |
| Preferred decoders (Performance, Advanced) | `codec` | empty | `any` | load check |

## Full run

Pending: the full run (233 scenes) results go here.
