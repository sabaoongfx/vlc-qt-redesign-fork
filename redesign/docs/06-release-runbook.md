# 06 Release runbook

## Versioning

- `vX.Y.Z` tags on `redesign`. `vX.Y.Z-rcN` = release candidate: published as a GitHub pre-release,
  skipped by the apt/pacman repositories.
- Every other tag, 0.x included, is a **full** release, because `releases/latest/download/<name>`
  (used by the website's fallback links) skips pre-releases.
- Assets have fixed names without a version (the tag carries it): `VLC-juxtopposed-x64-setup.exe`,
  `-x64-portable.zip`, `-x86_64.AppImage`, `-x86_64.tar.gz`, `-amd64.deb`, `-x86_64.rpm`,
  `-arm64.dmg`, plus `SHA256SUMS`.

## Before tagging

1. The commit to release is pushed to `redesign` and is a code commit (not `[skip ci]`): the release
   workflow waits for the runs **of that exact commit**.
2. All four workflows on it are green: Linux build, Linux packages (with `install-test`), Windows,
   macOS. `gh run list -R sabaoongfx/vlc-qt-redesign-fork -c <sha>`
3. Screenshots and the QML warning list of the Linux build were looked at (a green check does not
   mean the UI is right).
4. Manual checklist on the artifacts (at least the platform you can run):
   - [ ] Starts, Home shows the library, no QML warnings at `--verbose=1`.
   - [ ] Videos folder tree: open a folder, play a video (player view), right-click Play on a folder.
   - [ ] Fullscreen: bars appear only near their edge.
   - [ ] Settings: change one option, Save, reopen.
   - [ ] Linux AppImage on a Wayland session plays video without it disappearing.
   - [ ] Windows: installer installs next to VideoLAN's VLC; a Delete playlist box is dark in Night.
5. Ask the owner before pushing the tag: it publishes a release, updates the repositories and is
   visible to users.

## Tagging

```bash
git tag -a v0.1.7 <sha> -m "VLC (juxtopposed) v0.1.7: <one line of what changed>"
git push origin v0.1.7
```

## What the release workflow does (`redesign-release.yml`)

1. `release` job: waits for the Windows, Linux packages and macOS runs of the tagged commit (fails if
   any failed or never ran), downloads their artifacts, names the assets, builds the deb/rpm/Arch
   packages from the tarball with the tag's version (rpm signed with `PACKAGES_GPG_PRIVATE_KEY`),
   writes `SHA256SUMS`, attests every asset (`actions/attest-build-provenance`), creates the release
   with the standard notes, keeps the Arch package as an artifact.
2. `arch-repo` job (full releases): Arch container, signs the package and runs `repo-add --sign`.
3. `pages` job: reprepro apt repository from the release's deb, pacman repo from `arch-repo`,
   `KEY.gpg`, deploys GitHub Pages. If `arch-repo` fails, Pages is left as it was.

## After the release

- [ ] The release page lists all assets; `sha256sum -c SHA256SUMS --ignore-missing` passes on a download.
- [ ] `gh attestation verify VLC-juxtopposed-x86_64.AppImage -R sabaoongfx/vlc-qt-redesign-fork` passes.
- [ ] https://sabaoongfx.github.io/vlc-qt-redesign-fork/dists/stable/InRelease and `/arch/x86_64/vlc-juxtopposed.db` exist.
- [ ] apt: `sudo apt update && apt policy vlc-juxtopposed` shows the new version (on a machine with the repo).
- [ ] pacman: `sudo pacman -Sy && pacman -Si vlc-juxtopposed` shows the new version.
- [ ] Website (`sabaoongfx/vlc-web`): download buttons fill from the GitHub API on their own; push
      any copy changes; blog posts that mention behaviour stay true.
- [ ] Add the version to 10 (changelog) and `CLAUDE.md`.

## When something goes wrong

| Problem | Fix |
|---|---|
| A workflow of the tagged commit failed | Fix, push a new commit, delete the tag (`git push --delete origin vX; git tag -d vX`), tag the new commit |
| Release published with a broken asset | `gh release delete vX --cleanup-tag --yes`, fix, re-tag (done for v0.1.0) |
| Tag pushed on a `[skip ci]` commit | No runs exist: delete the tag, push an empty code commit (`git commit --allow-empty`), tag that (done for v0.1.2) |
| `pages` failed | Re-run the job (`gh run rerun <id> --failed`); the old site stays up meanwhile |
| Linux packages: `apt-get build-dep` hang | `gh run rerun <id> --failed` |
| `deploy-pages` refuses the tag | The `github-pages` environment must allow `v*` tags (Settings > Environments) |

## Communication

Release notes are generated (platform table, signing caveats, checksum and attestation commands,
repository link). The website and the YouTube description link the release; say "unofficial, not
affiliated with VideoLAN" everywhere it is announced.
