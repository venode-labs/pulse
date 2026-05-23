#!/usr/bin/env bash
# Security Pulse installer.
# No root needed. Lays the collector, CLI, widget, systemd timer and
# config into the standard XDG locations, then arms the timer.
#
# Author: Kaspar Tavitian

set -eu

SRC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN="$HOME/.local/bin"
SHARE_PLASMOID="$HOME/.local/share/plasma/plasmoids/com.casper.securitypulse"
SYSTEMD_USER="$HOME/.config/systemd/user"
ENV_D="$HOME/.config/environment.d"
CONFIG_DIR="$HOME/.config/security-pulse"
STATE_DIR="$HOME/.local/state/security-pulse"

mkdir -p "$BIN" "$SHARE_PLASMOID" "$SYSTEMD_USER" "$ENV_D" "$CONFIG_DIR" "$STATE_DIR" \
         "$CONFIG_DIR/baselines"

echo "installing CLI + collector to $BIN"
install -m 755 "$SRC/bin/security-pulse"           "$BIN/security-pulse"
install -m 755 "$SRC/bin/security-pulse-collector" "$BIN/security-pulse-collector"

echo "installing plasmoid to $SHARE_PLASMOID"
mkdir -p "$SHARE_PLASMOID/contents/ui"
install -m 644 "$SRC/plasmoid/metadata.json"            "$SHARE_PLASMOID/metadata.json"
install -m 644 "$SRC/plasmoid/contents/ui/main.qml"     "$SHARE_PLASMOID/contents/ui/main.qml"
install -m 644 "$SRC/plasmoid/contents/ui/FullView.qml" "$SHARE_PLASMOID/contents/ui/FullView.qml"

echo "installing systemd units to $SYSTEMD_USER"
install -m 644 "$SRC/systemd/security-pulse.service" "$SYSTEMD_USER/security-pulse.service"
install -m 644 "$SRC/systemd/security-pulse.timer"   "$SYSTEMD_USER/security-pulse.timer"

echo "installing environment override to $ENV_D"
install -m 644 "$SRC/config/environment.d/security-pulse.conf" "$ENV_D/security-pulse.conf"

if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
    echo "seeding $CONFIG_DIR/config.toml from example"
    install -m 644 "$SRC/config/config.toml.example" "$CONFIG_DIR/config.toml"
else
    echo "leaving existing $CONFIG_DIR/config.toml in place"
fi

echo "reloading systemd user manager"
systemctl --user daemon-reload

echo "arming the timer (every 5 min, 1 min after boot)"
systemctl --user enable --now security-pulse.timer

echo "running the collector once"
"$BIN/security-pulse-collector" || true

cat <<EOF

Done.

Quick checks:
  security-pulse status
  systemctl --user status security-pulse.timer

Widget: right-click a Plasma panel or desktop, Add Widgets, search
"Security Pulse". If it does not appear, refresh Plasma's QML cache:
  kquitapp6 plasmashell && kstart plasmashell
EOF
