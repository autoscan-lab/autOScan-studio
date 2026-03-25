<h1 align="center">autOScan Studio</h1>

<p align="center">
  <strong>Desktop grading workbench for C lab submissions</strong>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/electron-35+-47848F?style=flat&logo=electron&logoColor=white"></a>
  <a href="#"><img src="https://img.shields.io/badge/react-19-149ECA?style=flat&logo=react&logoColor=white"></a>
  <a href="#"><img src="https://img.shields.io/badge/pnpm-10-F69220?style=flat&logo=pnpm&logoColor=white"></a>
  <a href="#"><img src="https://img.shields.io/badge/engine-autOScan--engine-1f6feb?style=flat"></a>
</p>

<p align="center">
  Electron app for running, reviewing, and iterating on local grading workflows
</p>

---

## Overview

`autOScan Studio` is a local-first desktop app for teaching assistants grading C lab submissions.

It provides:

- Workspace folder browsing
- Read-only source preview with syntax highlighting
- YAML policy authoring and editing
- Submission and session runs through `autOScan-engine`
- Live engine output streaming
- Inspector views for grading results

The app uses:

- **Electron** for the desktop shell
- **React** for the renderer UI
- **electron-vite** for development and bundling
- **pnpm** for package management
- **`autOScan-engine`** via the `autoscan-bridge` release binary

---

## Requirements

You should have the following installed:

- **Node.js** 20+ recommended
- **pnpm** 10+
- **gcc**
- **macOS** for the current desktop workflow

Install `pnpm` if needed:

```/dev/null/install-pnpm.sh#L1-1
npm install -g pnpm
```

---

## Getting Started

Clone the project and install dependencies:

```/dev/null/setup.sh#L1-3
git clone https://github.com/autoscan-lab/autOScan-studio.git
cd autOScan-studio
pnpm install
```

Start the development app:

```/dev/null/dev.sh#L1-1
pnpm dev
```

The first run will download the pinned `autoscan-bridge` release binary automatically.

---

## Engine Setup

This app does **not** clone or build the engine from source during normal setup.

Instead, it downloads the `autoscan-bridge` binary from the public `autOScan-engine` release and stores it locally at:

```/dev/null/engine-path.txt#L1-1
Engine/autoscan-bridge
```

The pinned release tag lives in `package.json` under `config.engineTag`:

```/dev/null/engine-version.txt#L1-1
v1.1.1
```

You can fetch the engine binary explicitly with:

```/dev/null/package-json-script.txt#L1-1
pnpm run setup:engine
```

The package script downloads this release asset:

```/dev/null/release-asset.txt#L1-1
https://github.com/autoscan-lab/autOScan-engine/releases/download/v1.1.1/autoscan-bridge
```

---

## Available Scripts

```/dev/null/package-scripts.txt#L1-5
pnpm run setup:engine
pnpm dev
pnpm build
pnpm preview
pnpm package
```

### What they do

- `pnpm run setup:engine`  
  Downloads the pinned `autoscan-bridge` release binary if it is missing or out of date.

- `pnpm dev`  
  Ensures the engine binary exists, then starts the Electron + Vite development environment.

- `pnpm build`  
  Ensures the engine binary exists, then builds the Electron app output.

- `pnpm preview`  
  Runs the renderer preview flow.

- `pnpm package`  
  Builds the app and packages it with `electron-builder`.

---

## Project Structure

```/dev/null/project-structure.txt#L1-13
autOScan-studio/
├── Engine/
│   └── autoscan-bridge          # Downloaded engine binary
├── src/
│   ├── main/                    # Electron main process
│   ├── preload/                 # Secure bridge API
│   └── renderer/                # React UI
├── out/                         # Built Electron output
├── electron.vite.config.ts      # Electron + Vite config
├── package.json                 # Scripts and app packaging config
├── pnpm-lock.yaml               # pnpm lockfile
└── README.md
```

---

## How It Works

`autOScan Studio` launches the `autoscan-bridge` executable and communicates with it from the Electron main process.

High-level flow:

1. You open a workspace folder.
2. The app scans the workspace and policy files.
3. The renderer requests actions through the preload API.
4. The Electron main process handles filesystem, dialog, persistence, and engine operations.
5. `autoscan-bridge` streams output and structured events back into the app.
6. The UI updates the output and inspector panes in real time.

---

## Security Model

The Electron app is structured around a preload bridge rather than exposing Node APIs directly to the renderer.

Current architecture includes:

- Renderer-to-main communication through IPC
- A dedicated preload API surface
- `contextBridge` exposure to `window.api`
- External links opened outside the app shell

As the app evolves, keep Electron security defaults and IPC boundaries tight.

---

## Packaging Notes

Packaging expects the downloaded bridge binary to exist before `electron-builder` bundles the app.

Typical packaging flow:

```/dev/null/package-flow.sh#L1-2
pnpm run setup:engine
pnpm package
```

Or simply:

```/dev/null/package-shortcut.sh#L1-1
pnpm package
```

Since the `package` script already runs the build step first.

---

## Policy Basics

Policies are YAML files stored in the workspace `policies/` directory.

Example:

```/dev/null/policy-example.yaml#L1-12
name: "Lab 03"
compile:
  gcc: "gcc"
  flags: ["-Wall", "-Wextra"]
  source_file: "main.c"
run:
  test_cases:
    - name: "No args"
      expected_exit: "0"
library_files: []
test_files: []
```

The app includes a visual policy editor so you can iterate on policies without editing raw YAML by hand unless you want to.

---

## Notes for Migration

If you're migrating from the earlier native macOS/Xcode implementation:

- The active app workflow is now Electron-based
- Package management is now `pnpm`
- The Go engine remains shared across apps
- This repo now downloads the pinned engine release binary instead of bundling engine source
- Build and packaging expectations are centered around Electron and `electron-builder`

---

## Related Repositories

- [autOScan](https://github.com/autoscan-lab/autOScan) — TUI grading client
- [autOScan-engine](https://github.com/autoscan-lab/autOScan-engine) — shared grading engine

---

## License

MIT