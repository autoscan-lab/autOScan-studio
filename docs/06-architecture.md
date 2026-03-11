# Architecture (macOS-first)

## Layers

1. UI Layer (SwiftUI + AppKit bridges)
2. Application Layer (state, view models, command orchestration)
3. Integration Layer (engine adapter, SSH adapter, terminal adapter)
4. Storage Layer (settings/profiles/cache)

## Recommended Stack

1. Swift + SwiftUI (native macOS UX)
2. Monaco in WKWebView for robust editing features
3. PTY-backed terminal component for shell/SSH sessions
4. `autOScan-engine` process integration for grading logic

## Why this stack

- Native performance and macOS quality for core shell
- Reuse proven editor capabilities instead of building an editor from scratch
- Preserve single source of truth for grading behavior
