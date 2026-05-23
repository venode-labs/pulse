# Security Pulse

A lightweight, no-daemon, KDE-native pulse for a personal Linux workstation.
Reads five public threat feeds, cross-references every CVE against the
packages installed on the local box, and surfaces what is genuinely
actionable: a composite risk score, a tabbed widget on your panel, a CLI,
and a desktop notification when a new exploit lands against something you
actually run.

Built for Arch Linux + Plasma 6. Most of it (the CLI, the collector,
the feeds layer) is distro-agnostic and runs anywhere bash, jq and curl do.

## What you get

- **Five feeds**: CISA KEV (known exploited), Arch ALSA, NVD recent,
  GitHub Security Advisories, FIRST EPSS exploit-probability.
- **Fourteen local probes** without root: firewall, AppArmor, USBGuard,
  pending updates, Secure Boot, TPM, LUKS, failed-login counter,
  external listeners, VPN tunnel, kernel age, SUID inventory with
  baseline diff, sshd hardening, days since last `pacman -Syu`.
- **Installed-package correlation**. Every published CVE is matched
  against `pacman -Q` via tokenised vendor/product equality (KEV) and
  structured CPE extraction (NVD), with a recency window so 2010 noise
  doesn't drown the signal.
- **Composite risk score** (0-100), persisted with a rolling
  history window. The plasmoid renders the trend as a sparkline.
- **Tabbed Plasma 6 widget**: Overview (score gauge + top relevant CVEs),
  Threats (combo across all four feeds), Local (every probe in priority
  order), History (score trend).
- **Real CLI**: `security-pulse status`, `cves --relevant`, `score`,
  `report`, `set-baseline`, `notify-test`, `config --edit`.
- **Desktop notifications** with cooldown when a new high-or-critical
  relevant CVE lands.
- **No daemon**. One systemd user timer, one short-lived collector run
  every five minutes. Nothing listens.

## Why not something else

- `arch-audit` is CLI only and ALSA only. Security Pulse is a superset.
- OpenCVE is a server-side platform. Heavyweight for a single workstation.
- Wazuh is an agent-based SIEM with a backend. Overkill for one box.
- osquery is SQL telemetry with no dashboard, no feed integration.
- Falco is eBPF runtime detection aimed at containers.
- OpenVAS is a network vulnerability scanner.

Security Pulse sits in the personal-workstation gap: native KDE,
no daemon, no agent, live threat-feed-to-package correlation, with a
score you can put on your panel.

## Install

```sh
git clone https://github.com/venode-labs/security-pulse.git
cd security-pulse
./install.sh
```

The installer copies the collector and CLI to `~/.local/bin`, the
widget to `~/.local/share/plasma/plasmoids/`, the systemd units to
`~/.config/systemd/user/`, the QML XHR environment override to
`~/.config/environment.d/`, and seeds `~/.config/security-pulse/config.toml`
from the bundled example if you do not already have one.

It then enables the user-level timer and runs the collector once.

## Add the widget

Once installed and the collector has run at least once:

1. Right-click an empty bit of your KDE panel or desktop.
2. Pick **Add Widgets...**
3. Search for **Security Pulse**.
4. Drag onto the panel or desktop.

The compact representation shows a coloured dot and the composite
score. Click for the full popup.

If the widget does not appear in the search, refresh the Plasma cache:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

## Use the CLI

```sh
security-pulse status         # one-line score plus the local rundown
security-pulse cves --relevant
security-pulse cves --kev     # full KEV recent list (no installed-package filter)
security-pulse score          # composite, breakdown, history sparkline
security-pulse report         # markdown report of current state
security-pulse set-baseline   # snapshot SUID inventory so the next run detects drift
security-pulse notify-test    # confirm desktop notifications are wired
security-pulse config --edit  # open config in $EDITOR
security-pulse run            # run the collector now
security-pulse help
```

## Configuration

Lives at `~/.config/security-pulse/config.toml`. See
`config/config.toml.example` for the full schema with comments. The
shape is plain `key = value`, one per line, no nested tables.

Notable knobs:

- `severity_threshold` (low | medium | high | critical). Floor for
  relevance and notifications. Default `high`.
- `notify_cooldown_minutes`. Minimum gap between desktop notifications.
  Default `60`.
- `kev_max_age_days` / `nvd_max_age_days`. How far back to look in
  each feed for relevance. The full feeds are still queryable with
  `security-pulse cves --kev` and `--all`.
- `score_history_days`. Rolling window for the score sparkline.
- `llm_endpoint` / `llm_token`. Optional. If set, the collector POSTs
  a compact snapshot to your own LLM endpoint and stores a one-line
  briefing under `briefing.json`. Default is blank, so no data leaves
  your box.

## Where everything lives

| What | Path |
|---|---|
| Collector script | `~/.local/bin/security-pulse-collector` |
| CLI | `~/.local/bin/security-pulse` |
| Widget code | `~/.local/share/plasma/plasmoids/com.casper.securitypulse/` |
| Config | `~/.config/security-pulse/config.toml` |
| SUID baseline | `~/.config/security-pulse/baselines/suid.txt` |
| Systemd timer + service | `~/.config/systemd/user/security-pulse.{timer,service}` |
| Environment override | `~/.config/environment.d/security-pulse.conf` |
| State (JSON the widget reads) | `~/.local/state/security-pulse/` |

## Requirements

Hard:

- `bash`, `curl`, `jq` (commonly: `pacman -S jq`).
- A systemd user manager (Plasma sessions run one by default).
- KDE Plasma 6 if you want the widget.

Soft (each missing piece downgrades a probe to "unknown" instead of
failing the run):

- `pacman` for installed-package correlation and the Arch update probe.
- `checkupdates` (`pacman-contrib`) for the pending-updates count.
- `bootctl` for Secure Boot state.
- `notify-send` (`libnotify`) for desktop alerts.

## Honesty floor

What this is not:

- A vulnerability scanner with version-aware CPE matching. The current
  matcher is tokenised + recency-windowed; a 2027 release will swap to
  full CPE version-range comparison.
- A SIEM. It does not centralise logs, query at scale, or run agents
  across hosts. One personal machine, one timer.
- A replacement for `lynis`, `arch-audit`, or `rkhunter`. It pulls
  data from a different angle and they are complementary.

## License

MIT. See `LICENSE`.

## Author

Kaspar Tavitian.
