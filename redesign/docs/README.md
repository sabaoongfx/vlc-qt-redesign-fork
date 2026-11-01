# VLC (juxtopposed): project documents

VLC media player with Juxtopposed's redesigned interface, ported into VLC 4's Qt/QML interface
(`modules/gui/qt`). Unofficial; not made or endorsed by VideoLAN. Website: https://vlc.sabaoon.dev.
Repository: https://github.com/sabaoongfx/vlc-qt-redesign-fork (branch `redesign`).

These documents describe the product, how it is built, tested and released, and why it is the way
it is. They were written on 2026-11-02 from the repository and its history (457 commits on top of
upstream `dd056f2640`, 2026-10-20). Where a statement is unverified it says so.

| # | Document | Read it when |
|---|---|---|
| 01 | [Product requirements](01-product-requirements.md) | You need the goals, audience, scope and what "done" means |
| 02 | [Functional requirements (FRS)](02-functional-requirements.md) | You build, change or test a feature: numbered, testable requirements |
| 03 | [Architecture](03-architecture.md) | You need to know where code lives and how QML, C++ models and the VLC core connect |
| 04 | [Upstream divergence log](04-upstream-divergence.md) | You rebase onto upstream VLC or send a patch upstream |
| 05 | [Build and packaging](05-build-and-packaging.md) | You build locally or touch a CI workflow, the AppImage, deb, rpm, Arch, Windows or macOS package |
| 06 | [Release runbook](06-release-runbook.md) | You publish a version, or a release went wrong |
| 07 | [Test strategy and coverage](07-test-strategy.md) | You add a feature (and its test) or wonder what is not tested |
| 08 | [Decision records](08-decision-records.md) | You want to know why something was done a certain way before changing it |
| 09 | [Signing and keys](09-signing-and-keys.md) | You handle the package signing key, or plan code signing |
| 10 | [Changelog](10-changelog.md) | You want what changed per version |
| 11 | [User guide and FAQ](11-user-guide.md) | You support users, or write the website/help text |
| 12 | [Known issues and roadmap](12-known-issues-and-roadmap.md) | You plan the next work |

Other documents already in the repository (not repeated here):

- `CLAUDE.md` (repository root): working notes, gotchas, machine setup, release history in detail.
- `redesign/PLAN.md`: the phased test/fix/polish plan. `redesign/MACOS-PLAN.md`: the macOS plan (M1-M5).
- `redesign/TOKENS.md`: prototype-to-Qt design token map. `redesign/SETTINGS-MAP.md`: Settings rows to VLC options.
- `redesign/remaining/index.html`: status per Figma frame.
- The website repository `sabaoongfx/vlc-web` (blog posts, install guide).

## Keeping them current

- A feature change updates the FRS requirement (or adds one with a new ID; IDs are never reused) and,
  if it has one, its test in `redesign/tests/` (07 lists the mapping).
- A change outside `modules/gui/qt` QML (core, include, other modules, packaging) gets a line in 04.
- A release adds a section to 10. A non-obvious choice gets a record in 08.
- Docs-only commits carry `[skip ci]`; push a code commit on its own first when one sits underneath
  (a `[skip ci]` head commit starts no workflow, and a release needs the runs of its commit).
