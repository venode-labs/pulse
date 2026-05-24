#!/usr/bin/env bash
# Pulse uninstaller. Removes everything install.sh placed.
#
#   --purge   also delete ~/.config/pulse (config + baselines) and
#             ~/.local/state/pulse (collector state + history).
#
# Without --purge, the config and history survive so a later install
# picks up where it left off.

set -euo pipefail

PURGE=0
[[ "${1:-}" == '--purge' ]] && PURGE=1

say() { printf '[pulse-uninstall] %s\n' "$*"; }

say 'stopping and disabling timer'
systemctl --user disable --now pulse.timer 2>/dev/null || true
systemctl --user stop pulse.service 2>/dev/null || true

say 'removing binaries'
rm -f -- "$HOME/.local/bin/pulse" "$HOME/.local/bin/pulse-collector"

say 'removing plasmoid'
rm -rf -- "$HOME/.local/share/plasma/plasmoids/com.casper.pulse"

say 'removing systemd units'
rm -f -- "$HOME/.config/systemd/user/pulse.service" \
         "$HOME/.config/systemd/user/pulse.timer"

say 'removing environment.d hook'
rm -f -- "$HOME/.config/environment.d/pulse.conf"

if (( PURGE == 1 )); then
    say 'purging config and state'
    rm -rf -- "$HOME/.config/pulse" "$HOME/.local/state/pulse"
else
    say "config kept at ~/.config/pulse, state kept at ~/.local/state/pulse"
    say 'pass --purge to remove them.'
fi

say 'reloading user systemd'
systemctl --user daemon-reload

say 'done.'
