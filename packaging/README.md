# packaging

Per-distro builds. Single source of truth for version is the `pkgver=` line in `packaging/arch/pulse/PKGBUILD`. Bump there first, every other manifest reads it.

## Distros, ranked by fit

| Distro | Path | Notes |
|---|---|---|
| **Arch** | `arch/pulse/PKGBUILD` + `arch/pulse-plasmoid/PKGBUILD` | Primary target. Best support, native pacman inventory. Push to AUR as `pulse-bin` once a release is tagged. |
| **Fedora / RHEL / openSUSE** | `fedora/pulse.spec` | Builds the same two-package split. Pacman probe is a no-op until the dnf backend lands in v1.x. |
| **Debian / Ubuntu** | `debian/debian/` | Standard dh-style. Same note: package-inventory probe is a no-op until a dpkg backend exists. |
| **AppImage** | `appimage/build-appimage.sh` | Single-file fallback for distros without a native package. Calls out to the host's `pacman`, `ss`, `systemctl`. |
| **Flatpak** | `flatpak/ai.venode.Pulse.yml` | Possible but a bad fit. Sandbox isolation hides `/proc`, the package db, and the journal. Listed for completeness. |

## Build recipes

```sh
# Arch
cd packaging/arch/pulse && makepkg -si
cd packaging/arch/pulse-plasmoid && makepkg -si

# Fedora / RHEL
cp packaging/fedora/pulse.spec ~/rpmbuild/SPECS/
spectool -g -R ~/rpmbuild/SPECS/pulse.spec
rpmbuild -ba ~/rpmbuild/SPECS/pulse.spec

# Debian / Ubuntu
cp -r packaging/debian/debian .
dpkg-buildpackage -us -uc -b

# AppImage
bash packaging/appimage/build-appimage.sh

# Flatpak
flatpak-builder build packaging/flatpak/ai.venode.Pulse.yml
```

## Release workflow

1. Bump `pkgver` in `packaging/arch/pulse/PKGBUILD`.
2. `git tag v$NEW && git push --tags`.
3. GitHub Release auto-built from the tag.
4. Update AUR `pulse-bin` PKGBUILD with the new tarball hash.
