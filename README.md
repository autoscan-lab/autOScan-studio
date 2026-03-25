<h1 align="center">autOScan Studio</h1>

<p align="center">
  <strong>Desktop grading workbench for C lab submissions</strong>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/electron-35+-47848F?style=flat&logo=electron&logoColor=white" /></a>
  <a href="#"><img src="https://img.shields.io/badge/react-19-149ECA?style=flat&logo=react&logoColor=white" /></a>
  <a href="#"><img src="https://img.shields.io/badge/engine-autOScan--engine-1f6feb?style=flat" /></a>
  <a href="#"><img src="https://img.shields.io/badge/license-MIT-24292e?style=flat" /></a>
</p>

<p align="center">
  Local-first app for reviewing submissions, editing policies, and running grading sessions
</p>

---

## What It Does

`autOScan Studio` helps teaching assistants review C lab submissions in a desktop workspace built around grading policies and live engine feedback.

- Open a workspace folder and browse the submission tree
- Preview source files with syntax highlighting
- Create, edit, and manage grading policies
- Run full grading sessions through `autOScan-engine`
- Stream engine output live while runs are in progress
- Review compile results, scan results, and submission summaries
- Inspect grading outcomes in a dedicated results panel

---

## Installation

Requires: Node.js 20+, `pnpm` 10+, `gcc`

```bash
git clone https://github.com/autoscan-lab/autOScan-studio.git
cd autOScan-studio
pnpm install
pnpm dev
```

On first run, Studio downloads the pinned `autoscan-bridge` binary from the corresponding `autOScan-engine` release.

---

## Quickstart

```bash
pnpm dev
```

1. Open a workspace folder.
2. Select or create a policy.
3. Review source files in the editor pane.
4. Run a grading session or a specific submission.
5. Inspect output and results in the output and inspector panes.

---

## Policy Basics

Policies are stored in the workspace `policies/` directory.

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

Studio includes a visual policy editor so policies can be created and updated without editing YAML by hand.

---

## Packaging

```bash
pnpm package
```

The packaged app bundles the downloaded `autoscan-bridge` binary as an app resource.

---

## Related Repositories

- [autOScan](https://github.com/autoscan-lab/autOScan) — TUI grading client
- [autOScan-engine](https://github.com/autoscan-lab/autOScan-engine) — shared grading engine

---

## License

MIT