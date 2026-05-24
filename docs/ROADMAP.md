# Roadmap

## v0.3, shipped

- Composite score, fourteen probes, four feeds, plasmoid.
- Every probe surfaces `status` and `message`. No opaque severities.
- `listening_ports` resolves port to service when `ss` can't see the owning process. Allowlist driven.
- `ssh` uses `sshd -T` first, then `sshd_config` + drop-ins, then documented OpenSSH defaults. Source labelled so the operator sees what was measured vs inferred.
- ALSA matcher honours the `status` field. KEV and NVD cross-reference Arch's fixed-set so vintage CVEs do not re-surface.

## v0.4, near term (still bash)

- `pulse allow add <process>`. Push a row into config.toml without hand-editing.
- `pulse suid baseline`. Promote `suid.txt.new` to `suid.txt` after the operator has eyeballed the delta.
- `pulse explain <cve>`. Single CVE, full provenance chain in plain text. The differentiator vs arch-audit.
- `--format sarif|json|table|csv` on the CVE list. SARIF 2.1.0 means GitHub code-scanning picks pulse up for free.
- AppArmor / SELinux honest no-op. If neither LSM is installed, the probe is `info`, not `warn`.
- Rename config + state dirs to `~/.config/pulse-sec` and `~/.local/state/pulse-sec` to avoid the PulseAudio namespace collision in `~/.config/pulse/`. Migration script included.
- Per-distro packaging shipped: `packaging/{arch,debian,fedora,appimage,flatpak}` with a single source of truth for version.

## v1.0, the Go rewrite

Replace the bash collector. Keep the plasmoid (it works fine). Drop the systemd timer in favour of a `pulse watch` daemon with a local HTTP/JSON endpoint the widget can poll.

### Why Go

- One static binary, no toolchain on the host.
- Native JSON, semver, HTTP, goroutines.
- Real CPE 2.3 parsing for NVD version-range comparison.
- Type-checked matcher logic.
- Cross-compile for AUR `-bin`, .deb, .rpm and AppImage from a single `goreleaser` config.

### Layout

```
pulse/
├── cmd/pulse/                  CLI entry point
├── internal/
│   ├── feed/                   one file per source
│   │   ├── alsa.go             archlinux.org/issues/all.json
│   │   ├── kev.go              CISA KEV
│   │   ├── nvd.go              NVD 2.0 + CPE 2.3 parse
│   │   ├── ghsa.go             GitHub Advisory DB
│   │   └── epss.go             FIRST EPSS
│   ├── inventory/
│   │   ├── pacman.go           pacman -Qi parse
│   │   ├── dpkg.go             dpkg -l parse
│   │   ├── rpm.go              rpm -qa parse
│   │   └── vercmp.go           pacman vercmp / dpkg --compare-versions / rpmdev-vercmp
│   ├── match/
│   │   ├── alsa_match.go       status filter + vercmp against .fixed
│   │   ├── nvd_match.go        CPE versionStartIncluding / versionEndExcluding
│   │   ├── kev_match.go        cross-reference fixed-set
│   │   ├── vex.go              VEX / ignore rules
│   │   └── fixed_set.go        union builder
│   ├── probe/                  one file per local probe
│   ├── plugin/                 pulse-probe-* discovery
│   ├── reach/                  /proc/*/maps library reachability
│   ├── score/composite.go      health + relevance + EPSS weighting
│   ├── store/state.go          XDG state writer + reader
│   ├── cache/                  $XDG_CACHE_HOME/pulse, ORAS-aware
│   └── output/                 table, json, sarif, cyclonedx-vex, openvex, csv
├── plasmoid/                   unchanged from v0.3
├── pkg/pulse/                  library, for downstream embeds
├── tests/fixtures/             real ALSA / KEV / NVD samples for matcher tests
├── go.mod
├── .goreleaser.yml             one release pipeline -> AUR / GitHub Releases / SLSA
└── packaging/                  per-distro manifests
```

### Sub-commands

| Command | What it does |
|---|---|
| `pulse scan` | One-shot: fetch, match, write, exit. |
| `pulse watch` | Long-running daemon. Replaces the systemd timer. Serves JSON on a local unix socket. |
| `pulse json <topic>` | Stable JSON contract the widget reads. |
| `pulse score` | One integer. Useful in tmux / shell prompts. |
| `pulse list --vuln` | Only Arch-Vulnerable entries. |
| `pulse list --kev` | KEV hits. |
| `pulse list --epss-gt 0.5` | Filter on EPSS percentile. |
| `pulse explain <cve>` | Single CVE: installed version, affected range, fixed version, source feed, EPSS, KEV flag, ALSA reference, upstream fix. |
| `pulse sarif` | SARIF 2.1.0 for CI consumers. |
| `pulse sbom --cyclonedx` | CycloneDX SBOM of the local install, vulnerability-tagged. |
| `pulse vex` | OpenVEX statements for findings ack'd in `.pulse.yaml`. |
| `pulse allow add <process>` | Edit the listening allowlist from the CLI. |
| `pulse db update` | Refresh the local feed cache. Supports ORAS pull from an OCI registry. |
| `pulse tui` | Bubble Tea three-pane view: profile / findings / detail. |

### Architecture decisions, distilled from the leaders

| Idea | Source | Why |
|---|---|---|
| SBOM-as-input pipeline | grype + syft | Split collection from matching. Lets `pulse match --sbom file.cdx.json` run without re-probing. |
| Multi-source feeds with graceful degradation | vuls + opencve | Pull NVD + GHSA + KEV + EPSS + ALSA, store normalised, fall back when any source is offline. |
| `pulse explain <cve>` | grype | Single most-praised UX feature in the category. |
| First-class machine-readable output | sarif spec + cyclonedx | SARIF gets pulse into GitHub Actions for free. CycloneDX-VEX for compliance. |
| VEX / ignore rules as code | trivy + grype | `.pulse.yaml` with `ignore` blocks scoped by CVE, package, severity, with an expiry date. |
| OCI-distributed DB via ORAS | trivy | Air-gapped users `pulse db update` from any container registry. |
| Compliance profiles | lynis | `workstation.prf`, `laptop.prf`, `server.prf` toggle probe sets. Hardening index 0..100. |
| Probe plugin contract | gh extensions + cargo subcommands | Anything on `$PATH` named `pulse-probe-*` auto-discovered. Community adds probes without forking. |
| Library reachability via /proc/maps | osv-scanner (call-graph idea, simpler implementation) | A CVE in libfoo with no mapped process drops a tier. Pulse's true edge. |
| Offline mode + deterministic cache | most leaders | Cache feeds under `$XDG_CACHE_HOME/pulse/`, version the schema, refuse stale > N hours unless `--allow-stale`. |
| Bubble Tea TUI | charm | Right ecosystem for Go. Three-pane layout copies vuls's CVE viewer. |

### Milestones

1. **v1.0.0** engine port. Bash collector replaced by `pulse scan`. Same JSON layout. Widget unchanged.
2. **v1.0.1** NVD CPE 2.3 parsing. The bug class that survived v0.3.
3. **v1.0.2** `pulse explain`.
4. **v1.0.3** SARIF + CycloneDX-VEX + OpenVEX output.
5. **v1.0.4** `.pulse.yaml` VEX ignore rules.
6. **v1.0.5** AUR PKGBUILDs (`pulse-bin`, `pulse-plasmoid`), .deb, .rpm, AppImage, Flatpak. `goreleaser` one-shot.
7. **v1.1.0** widget reads `pulse json` over the local unix socket instead of file://. Removes the QML_XHR_ALLOW_FILE_READ hack.
8. **v1.2.0** probe plugin contract. `pulse-probe-*` on PATH auto-loaded.
9. **v1.2.1** `/proc/*/maps` reachability. A CVE in an unmapped library drops a tier.
10. **v1.3.0** Compliance profiles (CIS Arch L1/L2, ANSSI minimal). Hardening index.
11. **v1.4.0** Bubble Tea TUI.

### Reference designs

| Project | URL | What we steal |
|---|---|---|
| arch-audit | https://github.com/ilpianista/arch-audit | ALSA matcher correctness, single-purpose discipline |
| grype | https://github.com/anchore/grype | Package layout, JSON shape, `explain`, EPSS / KEV scoring |
| trivy | https://github.com/aquasecurity/trivy | OCI-distributed DB, WASM modules, VEX |
| osv-scanner | https://github.com/google/osv-scanner | Guided remediation, call-graph reachability idea |
| osv-scalibr | https://github.com/google/osv-scalibr | SCA-as-library pattern |
| syft | https://github.com/anchore/syft | SBOM generation, CycloneDX/SPDX output |
| vulnix | https://github.com/nix-community/vulnix | Whitelist design |
| lynis | https://github.com/CISOfy/lynis | Hardening index, profile files, audit voice |
| vuls | https://github.com/future-architect/vuls | TUI three-pane, multi-source feed aggregation |
| nuclei | https://github.com/projectdiscovery/nuclei | Template-driven plugin model |
| bubbletea | https://github.com/charmbracelet/bubbletea | TUI framework |
| lipgloss | https://github.com/charmbracelet/lipgloss | TUI styling |

## Non-goals

- Multi-host fleet view. Pulse measures one machine. A fleet rollup belongs upstream.
- Container scanning. Use `grype` or `trivy`.
- Anything that scans beyond `localhost`.
