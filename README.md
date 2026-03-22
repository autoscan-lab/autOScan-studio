# autOScan Studio

<p align="center">
  <strong>macOS grading workbench for C lab submissions</strong>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/swift-6.0+-F05138?style=flat&logo=swift&logoColor=white"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS-000000?style=flat&logo=apple&logoColor=white"></a>
  <a href="#"><img src="https://img.shields.io/badge/engine-autOScan--engine-1f6feb?style=flat"></a>
</p>

<p align="center">
  Native macOS app powered by <code>autOScan-engine</code>
</p>

---

## What It Does

`autOScan Studio` is a local-first grading workbench for teaching assistants.

- Open any workspace folder and browse the file tree
- Read-only code viewer with C/C++ syntax highlighting
- Create, edit, and manage grading policies
- Run submissions against policies with live output
- View compile results, banned function hits, and per-submission status
- Inspector panel with sortable grading results table

---

## Installation

Requires: Xcode 16+, Go 1.22+, `gcc`

```shell
git clone https://github.com/autoscan-lab/autOScan-studio.git
cd autOScan-studio
open "autOScan Studio/autOScan Studio.xcodeproj"
```

Press **Run** in Xcode. On first build, the engine is cloned and compiled automatically.

---

## How It Works

Studio embeds `autOScan-engine` via its `autoscan-bridge` CLI. The build phase:

1. Clones [autOScan-engine](https://github.com/autoscan-lab/autOScan-engine) into `Engine/` (gitignored)
2. Builds `autoscan-bridge` with `go build`
3. Bundles the binary into the app

The bridge communicates with Studio over newline-delimited JSON on stdout, streaming events as submissions are compiled and scanned.

---

## Project Layout

```
autOScan-studio/
├── autOScan Studio/          # Xcode project + Swift sources
│   └── autOScan Studio/
│       ├── App/              # App delegate, window controller, split view
│       ├── Model/            # App state, workspace nodes
│       ├── Services/         # Engine client, workspace service, terminal
│       ├── Views/            # Editor, sidebar, inspector, output panes
│       ├── Components/       # Code text view, line numbers
│       └── Theme/            # Colors and styling constants
└── Engine/                   # autOScan-engine (auto-cloned, gitignored)
```

---

## Policy Basics

Policies are YAML files stored in the `policies/` folder of your workspace.

```yaml
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

Studio includes a visual policy editor for creating and modifying policies without writing YAML directly.

---

## Related Repositories

- [autOScan](https://github.com/autoscan-lab/autOScan) — TUI grading client
- [autOScan-engine](https://github.com/autoscan-lab/autOScan-engine) — shared grading engine

---

## License

MIT
