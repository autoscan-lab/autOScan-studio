# SSH + Terminal Plan

## Goals

1. Fast connect to common university servers.
2. Run grading workflow where student code/build environment already lives.
3. Keep terminal logs visible in grading context.

## v1 Capabilities

1. Saved SSH profiles (host, user, port, key path label)
2. One-click connect from UI
3. Terminal tab per session
4. Command shortcuts (optional presets)

## Security Notes

1. Never store plaintext passwords.
2. Use macOS Keychain for sensitive secrets.
3. Show active host/session clearly to avoid grading on wrong server.
