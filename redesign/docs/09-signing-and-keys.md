# 09 Signing and keys

## What is signed today

| Artifact | Signed? | How users verify |
|---|---|---|
| apt repository (`InRelease`, `Release.gpg`) | Yes, package key | apt checks it with `signed-by=/usr/share/keyrings/vlc-juxtopposed.gpg` |
| pacman repository (`vlc-juxtopposed.db.sig`) and package (`.pkg.tar.zst.sig`) | Yes, package key | pacman after `pacman-key --add` + `--lsign-key` |
| `.rpm` | Yes, package key (nfpm) | `rpm --import KEY.gpg; rpm -K VLC-juxtopposed-x86_64.rpm` |
| `.deb` (downloaded directly) | No (apt repo signature covers repo installs) | `SHA256SUMS`, attestation |
| All release assets | Build provenance attestation (Sigstore, GitHub) | `gh attestation verify <file> -R sabaoongfx/vlc-qt-redesign-fork` |
| Windows exe/zip | **No** Authenticode signature: SmartScreen warns | `SHA256SUMS`, attestation |
| macOS app/dmg | Ad-hoc signature, **not notarized**: Gatekeeper blocks the first launch | `SHA256SUMS`, attestation |
| AppImage, tarball | No | `SHA256SUMS`, attestation |

## The package signing key

- Name: **VLC juxtopposed packages** (no email in the user ID).
- Fingerprint: `F092723FE6C0D16999EB7F6019D03339EB84F8FB` (RSA 4096, sign only, no expiry, no passphrase).
- Created 2026-11-01 on the development machine.
- Where it lives:
  - the owner's GnuPG keyring on the development machine (backup copy);
  - the repository secret `PACKAGES_GPG_PRIVATE_KEY` on `sabaoongfx/vlc-qt-redesign-fork` (used by
    `redesign-release.yml`);
  - revocation certificate: `~/.gnupg/openpgp-revocs.d/F092723FE6C0D16999EB7F6019D03339EB84F8FB.rev`.
- Public key: `https://sabaoongfx.github.io/vlc-qt-redesign-fork/KEY.gpg` (published by each full release).
- Separate from the Open Task Manager key (`D734849DBBB31077DF6E32270A5A35129CB0BC7A`) on purpose (08, ADR-012).

### Recommended now

1. Make an offline backup of the private key and the revocation certificate (encrypted USB or password
   manager): `gpg --armor --export-secret-keys F092723FE6C0D16999EB7F6019D03339EB84F8FB > vlc-packages-key.asc`.
   Losing both copies means rotating the key and asking every user to re-import it.
2. Do not export it anywhere else; never print it in CI logs (the workflows write it to a mode-600 file
   and delete it).

### Rotating the key

1. Generate a new key, update the `PACKAGES_GPG_PRIVATE_KEY` secret.
2. For one release, publish both public keys in `KEY.gpg` (repositories are signed with the new one).
3. Announce on the website and release notes; update the install commands if the key name changed
   (`pacman-key --lsign-key "<name>"`).
4. If the old key was compromised, publish its revocation certificate and say so prominently.

## Code signing (not done; options)

| Option | Cost | Notes |
|---|---|---|
| Windows: Azure Trusted Signing | ~$10/month | Needs identity validation; a signing step before NSIS in `redesign-windows.yml` |
| Windows: OV/EV certificate | ~$100-400/year | SmartScreen reputation still builds slowly |
| Windows: SignPath Foundation | free for open source | The fork's GPL/VideoLAN relationship may complicate approval |
| macOS: Apple Developer ID + notarization | $99/year | Removes the Gatekeeper block; needs `notarytool` in `redesign-macos.yml` |

No decision taken yet.
