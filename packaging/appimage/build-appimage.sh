#!/usr/bin/env bash
# Build a Pulse AppImage. Single self-contained binary the user can
# drop anywhere. Requires `appimagetool` on the build host.
#
#   bash packaging/appimage/build-appimage.sh
#
# Output: pulse-<version>-x86_64.AppImage in the repo root.

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
VERSION=$(sed -n 's/^pkgver=//p' "$REPO_ROOT/packaging/arch/pulse/PKGBUILD" | head -1)
APPDIR=$(mktemp -d -t pulse-appdir.XXXXXX)
trap 'rm -rf "$APPDIR"' EXIT

mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/pulse" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"

install -Dm755 "$REPO_ROOT/bin/pulse"           "$APPDIR/usr/bin/pulse"
install -Dm755 "$REPO_ROOT/bin/pulse-collector" "$APPDIR/usr/bin/pulse-collector"
install -Dm644 "$REPO_ROOT/config/config.toml.example" "$APPDIR/usr/share/pulse/config.toml"
install -Dm644 "$REPO_ROOT/.assets/venode-wordmark.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/pulse.svg"
install -Dm644 "$REPO_ROOT/LICENSE" "$APPDIR/usr/share/pulse/LICENSE"

cat > "$APPDIR/usr/share/applications/pulse.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Pulse
Comment=Host security pulse-check
Exec=pulse
Icon=pulse
Terminal=true
Categories=System;Security;
DESKTOP

# AppImage entry point
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE=$(dirname -- "$(readlink -f -- "$0")")
export PATH="$HERE/usr/bin:$PATH"
exec "$HERE/usr/bin/pulse" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
ln -sf usr/share/applications/pulse.desktop  "$APPDIR/pulse.desktop"
ln -sf usr/share/icons/hicolor/scalable/apps/pulse.svg "$APPDIR/pulse.svg"

cd "$REPO_ROOT"
ARCH=x86_64 appimagetool "$APPDIR" "pulse-${VERSION}-x86_64.AppImage"
echo "built: pulse-${VERSION}-x86_64.AppImage"
