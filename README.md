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

## Repository Layout

```text
autOScan-studio/
  autOScan Studio/        # Xcode project + SwiftUI sources
```

## Run In Xcode

1. Open `autOScan Studio/autOScan Studio.xcodeproj`
2. Select scheme `autOScan Studio`
3. Press Run

## Related Repositories

- `autOScan` (TUI client)
- `autOScan-engine` (shared grading engine)
