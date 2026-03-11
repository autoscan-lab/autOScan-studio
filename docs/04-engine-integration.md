# Engine Integration Plan

## Dependency

Use `autOScan-engine` as the only grading core.

## Contract Strategy

Define a stable boundary before heavy UI implementation:
1. run grading session
2. execute submission/test case
3. compute similarity
4. compute AI detection
5. export report

## Integration Modes

v1 recommended:
- invoke engine via local process boundary (CLI/RPC wrapper)
- parse structured JSON responses in app layer

## Compatibility Rule

`autOScan` TUI and `autOScan Studio` must produce equivalent grading outputs for same inputs/settings.
