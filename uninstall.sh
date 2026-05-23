#!/usr/bin/env bash
# Security Pulse uninstaller. Removes everything install.sh laid down.
# Config and state are removed too; pass --keep-config or --keep-state
# to preserve either.
#
# Author: Kaspar Tavitian

set -eu

keep_config=0
keep_state=0
for arg in "$@"; do
    case "$arg" in
        --keep-config) keep_config=1 ;;
        --keep-state)  keep_state=1 ;;
        -h|--help)
            cat <<EOF
usage: uninstall.sh [--keep-config] [--keep-state]
EOF
            exit 0
            ;;
    esac
done

echo "stopping + disabling timer"
systemctl --user disable --now security-pulse.timer 2>/dev/null || true

echo "removing binaries"
rm -f "$HOME/.local/bin/security-pulse"
rm -f "$HOME/.local/bin/security-pulse-collector"

echo "removing plasmoid"
rm -rf "$HOME/.local/share/plasma/plasmoids/com.casper.securitypulse"

echo "removing systemd units"
rm -f "$HOME/.config/systemd/user/security-pulse.timer"
rm -f "$HOME/.config/systemd/user/security-pulse.service"
rm -f "$HOME/.config/systemd/user/timers.target.wants/security-pulse.timer"

echo "removing environment override"
rm -f "$HOME/.config/environment.d/security-pulse.conf"

systemctl --user daemon-reload

if (( keep_config == 0 )); then
    echo "removing config"
    rm -rf "$HOME/.config/security-pulse"
else
    echo "keeping $HOME/.config/security-pulse"
fi

if (( keep_state == 0 )); then
    echo "removing state"
    rm -rf "$HOME/.local/state/security-pulse"
else
    echo "keeping $HOME/.local/state/security-pulse"
fi

echo "done"
