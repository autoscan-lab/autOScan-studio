# autOScan Studio

macOS-first grading workbench for teaching assistants.

## Mission

Provide a lightweight IDE-like grading environment with:
- file tree navigation
- code viewer/editor
- integrated terminal
- SSH shortcuts for university servers
- autOScan tool panel powered by `autOScan-engine`

## Scope (v1)

- macOS app only
- single-user local workflow
- consume `autOScan-engine` as grading core

## Non-Goals (v1)

- replacing full IDEs
- team collaboration backend
- LMS integrations

## Repository Layout

```text
autOScan-studio/
  apps/macos/             # macOS app project (to be created)
  docs/                   # product/technical planning docs
  assets/                 # design assets and mockups
  scripts/                # local helper scripts
```

## Related Repositories

- `autOScan` (TUI client)
- `autOScan-engine` (shared grading engine)
