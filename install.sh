#!/usr/bin/env bash
# Pulse installer.
#
# Idempotent. Installs into XDG locations under $HOME, no root needed
# at any step. Symlink-friendly: re-running this from the same checkout
# updates every binary, unit, config example and the plasmoid in place.
#
# Locations:
#   ~/.local/bin/pulse                          CLI
#   ~/.local/bin/pulse-collector                background collector
#   ~/.local/share/plasma/plasmoids/com.casper.pulse/   widget
#   ~/.config/systemd/user/pulse.{service,timer}
#   ~/.config/pulse/config.toml                 (created from example on first run)
#   ~/.config/environment.d/pulse.conf
#
# After install: systemctl --user daemon-reload, enable+start the timer.

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="$HOME/.local/bin"
PLASMA_DIR="$HOME/.local/share/plasma/plasmoids"
SYSTEMD_DIR="$HOME/.config/systemd/user"
ENV_DIR="$HOME/.config/environment.d"
CONF_DIR="$HOME/.config/pulse"

say() { printf '[pulse-install] %s\n' "$*"; }

# Refuse on non-Arch hosts. The collector reads /var/log/pacman.log and
# uses pacman -Qi for installed-package inventory; nothing else works.
if [[ ! -r /etc/arch-release && ! -r /etc/os-release ]] \
   || ! grep -qiE 'arch' /etc/os-release 2>/dev/null; then
    say 'Pulse targets Arch Linux. /etc/os-release does not look like Arch; refusing.'
    say 'Pass PULSE_FORCE=1 to install anyway.'
    [[ "${PULSE_FORCE:-0}" == "1" ]] || exit 1
fi

# Required runtime deps.
for tool in jq curl pacman ss; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        say "missing dependency: $tool"
        exit 1
    fi
done

mkdir -p "$BIN_DIR" "$PLASMA_DIR" "$SYSTEMD_DIR" "$ENV_DIR" "$CONF_DIR"

say "binaries -> $BIN_DIR"
install -m 0755 "$REPO_ROOT/bin/pulse"           "$BIN_DIR/pulse"
install -m 0755 "$REPO_ROOT/bin/pulse-collector" "$BIN_DIR/pulse-collector"
install -m 0755 "$REPO_ROOT/bin/pulse-brief"     "$BIN_DIR/pulse-brief"

say "plasmoid -> $PLASMA_DIR/com.casper.pulse"
rm -rf -- "$PLASMA_DIR/com.casper.pulse"
cp -r "$REPO_ROOT/plasmoid/com.casper.pulse" "$PLASMA_DIR/"

say "systemd units -> $SYSTEMD_DIR"
install -m 0644 "$REPO_ROOT/systemd/pulse.service" "$SYSTEMD_DIR/pulse.service"
install -m 0644 "$REPO_ROOT/systemd/pulse.timer"   "$SYSTEMD_DIR/pulse.timer"

say "environment.d hook -> $ENV_DIR"
install -m 0644 "$REPO_ROOT/config/pulse.conf" "$ENV_DIR/pulse.conf"

if [[ ! -f "$CONF_DIR/config.toml" ]]; then
    say "seeding $CONF_DIR/config.toml (no existing file)"
    install -m 0644 "$REPO_ROOT/config/config.toml.example" "$CONF_DIR/config.toml"
else
    say "$CONF_DIR/config.toml already present, not overwriting"
fi

say 'reloading user systemd'
systemctl --user daemon-reload

say 'enabling and starting pulse.timer'
systemctl --user enable --now pulse.timer

say 'refreshing the KDE service cache'
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

say 'done. Add the Pulse widget from the panel widget picker.'
say 'First collection runs within one minute; rerun on demand with: systemctl --user start pulse.service'
