# Architecture

Three processes, one JSON state directory, one widget.

```
                                                      ~/.local/state/pulse/
                                                      ├── health.json
                                                      ├── threats.json
                                                      ├── relevant.json
                                                      ├── score.json
                                                      └── briefing.json  (optional, LLM digest)
              writes                                          ▲
              ┌──────────────────────────────────────────────┘
              │
      [pulse-collector]                                       │ reads
   timer-driven, every 5 minutes                              │
   probes the system, fetches the feeds                       │
   correlates CVE x installed packages                        │
   computes health + composite scores                         │
              ▲                                       [com.casper.pulse plasmoid]
              │                                       (QML reads file:// JSON via
              │ runs                                   QML_XHR_ALLOW_FILE_READ=1)
       [pulse.timer]                                          │
       [pulse.service] (oneshot)                              │
                                                       [pulse CLI]
                                                       same JSON, terminal view
```

## Components

| Path | Role |
|---|---|
| `bin/pulse-collector` | The only writer. Runs as the user, no privileges. |
| `bin/pulse` | Read-only CLI over the JSON state. |
| `systemd/pulse.service` | Oneshot, runs the collector. |
| `systemd/pulse.timer` | Five-minute cadence. |
| `plasmoid/com.casper.pulse/` | KDE Plasma 6 widget. Reads JSON on its own one-minute timer. |
| `config/config.toml.example` | Seed config dropped at `~/.config/pulse/config.toml` on first install. |
| `config/pulse.conf` | environment.d hook setting `QML_XHR_ALLOW_FILE_READ=1` for the plasmoid file:// reads. |

## State files

All under `~/.local/state/pulse/`. Every file is a complete snapshot. Nothing append-only except the score history.

| File | Top-level keys | Writer |
|---|---|---|
| `health.json` | `updated, overall, score, host, items{...}` | collector probes |
| `threats.json` | `updated, kev, arch, nvd, ghsa, epss` | collector feeds |
| `relevant.json` | `updated, severity_floor, count, items[]` | collector matcher |
| `score.json` | `updated, score, health_score, relevant{}, history[]` | collector score step |
| `briefing.json` | LLM digest, optional, only when an endpoint is set | collector LLM step |

## Probe contract

Every probe in `bin/pulse-collector` returns a JSON object via the `emit_probe` helper:

```
{
  "severity": "ok | info | warn | critical",
  "status":   "short observation (one line)",
  "message":  "human-friendly evidence sentence",
  "...":      "per-probe facts: ports[], days, version, etc"
}
```

The widget renders `status` on the row and `message` on click / hover. A probe that fails to read its inputs returns `severity: info` with a message explaining why. `critical` is reserved for fact-based findings; missing data is never `critical`.

## CVE matcher contract

Every row in `relevant.json.items[]`:

```
{
  "source":     "arch | kev | nvd",
  "id":         "CVE-YYYY-NNNN or AVG-NNNN",
  "package":    "installed package name that matched",
  "severity":   "Critical | High | Medium | Low",
  "status":     "Vulnerable | Fixed | KnownExploited | Disclosed | ...",
  "cves":       ["CVE-..."],
  "title":      "...",
  "url":        "...",
  "epss":       0.42,
  "percentile": 0.95
}
```

Matching rules in the current bash implementation:

- **Arch ALSA**: package name must be installed AND status must be `Vulnerable`. `Fixed` and `Not affected` entries drop. This is the line that fixes the historical false positives.
- **CISA KEV**: token-match against vendor and product, then drop any CVE that appears in Arch's fixed-set.
- **NVD**: CPE product-name match against installed names, drop any CVE in Arch's fixed-set.
- **EPSS**: spliced onto every row by CVE id.

The one missing layer: NVD CPE version-range comparison. Tracked in ROADMAP.

## Score arithmetic

```
health_score = round( sum(probe_weight) * 100 / (n_probes * 10) )
   ok=10, info=8, warn=5, critical=0,  n_probes=14

cve_penalty  = clamp(0,  critical*8 + high*4 + medium*1,  60)

composite    = clamp(0,  health_score - cve_penalty,  100)
```

The 60-point cap on `cve_penalty` keeps the score recoverable. The weights are arbitrary; they are documented, not derived from CVSS or SSVC. An operator who wants standards alignment edits `compose_score` in `bin/pulse-collector`.

## Why bash for v0.3

It runs on a fresh Arch install with no toolchain. Dependency floor: `bash`, `jq`, `curl`, `pacman`, `ss`, `systemctl`. All present on every Arch + KDE box this targets.

Why not bash for v1.0: the NVD CPE version-range matcher needs proper semver / pkgver comparison. Doable in `jq`, but the maintenance cost is higher than the Go rewrite. See ROADMAP.

## File ownership

The user. No process in pulse needs root. `pulse-collector` runs as a systemd user timer. The widget reads JSON over `file://`, which is why `environment.d/pulse.conf` sets `QML_XHR_ALLOW_FILE_READ=1`.
