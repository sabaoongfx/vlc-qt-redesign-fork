#!/usr/bin/env bash
# Signs the Arch package(s) and makes the signed pacman repository "vlc-juxtopposed".
# Used by redesign-release.yml (job arch-repo, in an archlinux container); runnable on Arch/Manjaro.
# usage: make-arch-repo.sh <dir with *.pkg.tar.zst> <output dir>
# The key comes from $PACKAGES_GPG_PRIVATE_KEY when set, else the keyring's default secret key.
set -euo pipefail
src=$1
out=$2

if [[ -n "${PACKAGES_GPG_PRIVATE_KEY:-}" ]]; then
  printf '%s\n' "$PACKAGES_GPG_PRIVATE_KEY" | gpg --batch --import
fi

mkdir -p "$out"
cp "$src"/*.pkg.tar.zst "$out"/
cd "$out"
for pkg in *.pkg.tar.zst; do
  gpg --batch --yes --detach-sign --no-armor "$pkg"
done
repo-add --sign --include-sigs vlc-juxtopposed.db.tar.gz ./*.pkg.tar.zst

# repo-add makes vlc-juxtopposed.db/.files (and their .sig) symlinks to the .tar.gz files;
# GitHub Pages serves no symlinks, so replace them with copies
find . -maxdepth 1 -type l -print0 | while IFS= read -r -d '' link; do
  cp --remove-destination "$(readlink -f "$link")" "$link"
done
ls -la
