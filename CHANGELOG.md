# Changelog

All notable changes to pulse. Format inspired by Keep a Changelog. Versioning is SemVer once v1.0 lands; pre-1.0 is unstable.

## [Unreleased]

### Planned for v0.4

- `pulse allow add <process>` to edit the listening allowlist from the CLI.
- `pulse suid baseline` to promote `suid.txt.new` to `suid.txt`.
- `pulse explain <cve>` to print one finding's full provenance chain.
- `--format sarif|json|table|csv` on `pulse cves`.
- AppArmor / SELinux honest no-op when neither LSM is installed.
- Rename config + state dirs to avoid the PulseAudio namespace.

## [0.3.0] - 2026-05-24

### Added

- Initial public release.
- Bash collector with fourteen host probes.
- CVE matcher across Arch ALSA, CISA KEV, NVD, EPSS.
- KDE Plasma 6 widget under `com.casper.pulse`.
- XDG-clean installer + uninstaller, no root.
- Packaging surface: AUR PKGBUILDs, debian/, fedora.spec, AppImage, Flatpak manifest.

### Fixed

Compared to internal v0.2:

- ALSA matcher honours the `status` field. `Fixed` and `Not affected` entries no longer surface as critical.
- KEV and NVD entries cross-reference Arch's fixed-set. Vintage CVEs that Arch has patched do not re-appear.
- Every probe now emits `status` + `message`. No black-box `Critical` labels.
- `listening_ports` resolves ports to services when `ss` cannot see the owning process.
- `ssh` probe falls back through `sshd -T`, then `sshd_config` + drop-ins, then documented OpenSSH defaults, with the source labelled.
- Composite score now reflects measured probe state.

### Known limitations

- NVD CPE 2.3 version-range parsing is not implemented. A CVE for `bind 9.20.0..9.20.22` will surface even when 9.20.23 is installed.
- Package-inventory probe is Arch-only. Debian/Ubuntu/Fedora backends arrive with the Go rewrite in v1.0.
