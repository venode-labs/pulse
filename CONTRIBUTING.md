# Contributing

Security Pulse is small on purpose. Patches are welcome. So is a
filed issue that says 'this doesn't fit my workflow because X'.

## Before you start

- For anything beyond a one-line fix, open an issue first so we
  can agree the shape. Saves rework.
- Read the README so you know what the project is and isn't.
- For UI changes to the plasmoid, attach a screenshot.

## Local checks

```
shellcheck bin/security-pulse bin/security-pulse-collector install.sh uninstall.sh
qmllint plasmoid/contents/ui/*.qml
```

CI runs both on every push.

## Coding style

- Bash: portable enough to run on a normal Arch box. Stdlib first.
  `jq`, `curl`, `pacman` are fair game. Anything heavier earns its
  place with a why-not in the commit message.
- QML: match what's already in `plasmoid/contents/ui/*.qml`. No
  hand-imported frameworks. Plasma 6 components only.
- Australian English in any user-visible string.

## Commits

Imperative, lowercase, under 72 characters. Body explains the why
when the what isn't obvious. No bot or AI co-author trailers, no
'generated with' footers.

## Pull requests

One concern per PR. A PR description that says 'see commits' is fine
if the commits already explain themselves. Mention the issue number
when there is one.
