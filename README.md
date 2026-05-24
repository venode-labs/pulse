<p align="center">
  <img src=".assets/venode-wordmark.svg" alt="Venode" height="64">
</p>

# pulse

A host-security pulse-check for Arch Linux. One number, one screen, no theatre.

Fourteen probes against the live box (firewall, kernel age, listening ports, LUKS, SSH, secure boot, suid drift, ...) plus a CVE matcher across four public feeds (Arch ALSA, CISA KEV, NVD, EPSS), reconciled against actually-installed package versions. Surfaced through a CLI and a KDE Plasma 6 widget.

The product question this answers: *what is the security state of this machine, right now, in one number, plus the short list of things to look at?*

```
$ pulse
score    47 / 100         warn
probes   10 ok · 3 warn · 1 info
cves     0 critical · 8 high · 0 medium
top      libxml2: AVG-2898 (Vulnerable)
         pam:     AVG-2901 (Vulnerable)
         djvulibre: AVG-2907 (Vulnerable)
```

## Install

Arch (recommended):

```
yay -S pulse-bin
```

Anything else, the script-install path:

```
git clone https://github.com/keletonik/pulse
cd pulse && ./install.sh
```

Per-distro packages: `packaging/` carries the PKGBUILD, the debian/ tree, the .spec, the AppImage recipe and the Flatpak manifest. Pick the one for your distro.

XDG-clean install. No root, no daemon, no network listener of its own. Files land under `~/.local/bin`, `~/.local/share/plasma`, `~/.config/pulse`, `~/.local/state/pulse`, `~/.config/systemd/user`.

## What it actually checks

```
firewall          systemctl is-active against nftables / iptables / firewalld / ufw
apparmor          apparmor.service state, plus apparmor_status presence
usbguard          usbguard.service state
updates           checkupdates count; flags kernel-pending separately
secureboot        bootctl status
tpm               /dev/tpm0, /dev/tpmrm0
luks              lsblk -o FSTYPE looking for crypto_LUKS
failed_logins     journal scan, 24h window
listening_ports   ss -tunlp, port -> service fallback, allowlist driven
vpn               proton*, wg*, tun*, tailscale* interface presence
kernel            running kernel + days since pacman installed the matching package
suid              suid/sgid binary inventory, delta against a saved baseline
ssh               sshd -T first, then sshd_config + drop-ins, then documented defaults
last_upgrade      days since the most recent `starting full system upgrade` in pacman.log
```

Every probe reports *what it saw* alongside its severity. No black-box `Critical` labels.

## CVE matcher

Two ground rules, both learned the hard way during v0.x:

1. The package name must match an actually-installed package. Name-match alone gave 50 phantom criticals on a clean Arch box.
2. The advisory must be live. An ALSA entry marked `Fixed` does not count. A KEV or NVD entry whose CVE is in Arch's `Fixed` set does not count either.

What's still imperfect in v0.3: NVD CPE 2.3 version-range parsing. A CVE flagged by NVD against `bind 9.20.0 to 9.20.22` will surface when you have 9.20.23 installed. The Go rewrite in `docs/ROADMAP.md` fixes that.

## Composite score

```
health  = sum(probe_score) * 100 / (n_probes * 10),  ok=10 info=8 warn=5 critical=0
penalty = clamp(0, critical*8 + high*4 + medium*1, 60)
score   = clamp(0, health - penalty, 100)
```

The weights are deliberate but not from CVSS or SSVC. They are documented so an operator can disagree with them. Patch them in `bin/pulse-collector` if your threat model wants different.

## Config

`~/.config/pulse/config.toml`. Plain `key = value`. Highlights:

```toml
severity_threshold  = high
notify_enabled      = true
listening_allowlist = sshd, systemd-resolved, avahi-daemon, cups-browsed
score_history_days  = 30
```

`listening_allowlist` extends the set of services the listener probe considers expected. Look up an unknown port with `sudo ss -tunlp '( sport = :<port> )'` and add the owning process once you know what it is.

## Roadmap

This is the bash v0.3. It works end to end on current Arch. The Go rewrite is the next major and replaces:

- NVD CPE version-range comparison done properly.
- ALSA `vercmp` against the `fixed` field rather than the status alone.
- A `pulse explain <cve>` subcommand showing the full provenance chain for one finding.
- SARIF + CycloneDX JSON output (CI-friendly).
- HTTP-served JSON the widget polls instead of file:// reads.

Full plan in `docs/ROADMAP.md`.

## Non-goals

- Multi-host fleet view. This measures one machine. A fleet rollup belongs upstream.
- Container scanning. Use `grype` or `trivy` for that surface.
- Anything that scans beyond `localhost`.

## License

MIT. © 2026 Venode Labs.

## Acknowledgements

- [security.archlinux.org](https://security.archlinux.org/), ALSA tracker.
- [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog).
- [NVD](https://nvd.nist.gov/) and [FIRST EPSS](https://www.first.org/epss/).
- [arch-audit](https://gitlab.archlinux.org/archlinux/arch-audit) for the ALSA matcher pattern.
- [grype](https://github.com/anchore/grype) and [osv-scanner](https://github.com/google/osv-scanner) for the CLI shape this is moving towards.
