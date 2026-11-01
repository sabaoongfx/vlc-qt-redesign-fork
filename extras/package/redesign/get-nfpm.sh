#!/bin/bash
# Downloads nfpm (deb/rpm/Arch packager) into <dir>, checked against its published SHA-256.
# usage: get-nfpm.sh <dir>   then use <dir>/nfpm
set -euo pipefail
V=2.47.0
SUM=0660ca602b2d2d2ae4781a06c692b3eeb9d437ffea05b831d76e41f4a3188783
mkdir -p "$1"
cd "$1"
curl -fsSL -o nfpm.tar.gz "https://github.com/goreleaser/nfpm/releases/download/v$V/nfpm_${V}_Linux_x86_64.tar.gz"
echo "$SUM  nfpm.tar.gz" | sha256sum -c
tar xzf nfpm.tar.gz nfpm
rm nfpm.tar.gz
./nfpm --version | grep -i gitversion
