# Security policy

## Reporting a vulnerability

If you find a security issue in Security Pulse, please do not file
a public GitHub issue. Send the details to **casper@venode.au**.

Useful to include:

- The version (output of `security-pulse --version`).
- Distro and Plasma version.
- Reproduction steps. A minimal script or `journalctl` excerpt
  beats a screenshot.
- The impact you see. Even better, the worst-case impact you can
  reason about.

You will get a first reply within seven days. Most fixes ship within
fourteen days of confirmation. If you cannot wait that long, say so
in the report and the timeline gets renegotiated.

## What's in scope

- The collector, CLI and plasmoid in this repo.
- The systemd units and installer.
- The threat-feed parsers and the CVE-to-package matcher.

## What's out of scope

- The upstream feed providers (CISA KEV, NVD, GHSA, EPSS, Arch ALSA).
  Report issues to the feed owner.
- Issues that require physical access to an unlocked machine.
- Issues in `pacman`, `journalctl`, `iptables` and other base-system
  tools the probes call out to.

## Disclosure

Once a fix is shipped, the advisory is published on the GitHub
Security Advisories tab with credit to the reporter unless they
ask to stay anonymous.
