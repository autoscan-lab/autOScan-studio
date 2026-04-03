import { BrowserWindow, app, ipcMain } from "electron";
import { spawn, type ChildProcess } from "child_process";
import { join } from "path";
import { createInterface } from "readline";

let activeProcess: ChildProcess | null = null;

function getBridgePath(): string {
  if (app.isPackaged) {
    return join(process.resourcesPath, "autoscan-bridge");
  }
  return join(__dirname, "../../Engine/autoscan-bridge");
}

function getTargetWindow(): BrowserWindow | null {
  return BrowserWindow.getFocusedWindow() ?? BrowserWindow.getAllWindows()[0] ?? null;
}

function stopActiveProcess(): void {
  if (activeProcess) {
    activeProcess.kill();
    activeProcess = null;
  }
}

function workspaceConfigDir(workspacePath: string): string {
  return join(workspacePath, ".autoscan");
}

function startBridgeStreaming(args: string[]): void {
  const win = getTargetWindow();
  if (!win) return;

  stopActiveProcess();

  const bridgePath = getBridgePath();
  const proc = spawn(bridgePath, args, {
    stdio: ["ignore", "pipe", "pipe"],
  });
  activeProcess = proc;

  const rl = createInterface({ input: proc.stdout! });

  rl.on("line", (line) => {
    try {
      const event = JSON.parse(line);
      win.webContents.send("engine:event", event);
    } catch {
      win.webContents.send("engine:output", line);
    }
  });

  let stderrChunks = "";
  proc.stderr?.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stderrChunks += text;
    win.webContents.send("engine:output", text);
  });

  proc.on("close", (code) => {
    activeProcess = null;
    if (code !== 0) {
      win.webContents.send("engine:event", {
        type: "error",
        message: stderrChunks || `Engine exited with code ${code}`,
      });
    }
    win.webContents.send("engine:done", code);
  });

  proc.on("error", (err) => {
    activeProcess = null;
    win.webContents.send("engine:event", {
      type: "error",
      message: err.message,
    });
    win.webContents.send("engine:done", -1);
  });
}

async function runBridgeJSONCommand(args: string[]): Promise<unknown> {
  return await new Promise((resolve, reject) => {
    const bridgePath = getBridgePath();
    const proc = spawn(bridgePath, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    proc.stdout?.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    proc.on("error", (err) => reject(err));
    proc.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `Bridge exited with code ${code}`));
        return;
      }

      const lines = stdout
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean);

      const last = lines.at(-1);
      if (!last) {
        reject(new Error("Bridge returned no JSON output"));
        return;
      }

      try {
        resolve(JSON.parse(last));
      } catch {
        reject(new Error("Bridge returned invalid JSON output"));
      }
    });
  });
}

export function registerEngineHandlers(): void {
  ipcMain.handle(
    "engine:run-session",
    async (
      _event: Electron.IpcMainInvokeEvent,
      workspacePath: string,
      policyPath: string,
    ): Promise<void> => {
      startBridgeStreaming([
        "run-session",
        "--workspace",
        workspacePath,
        "--policy",
        policyPath,
        "--config-dir",
        workspaceConfigDir(workspacePath),
      ]);
    },
  );

  ipcMain.handle(
    "engine:run-test-case",
    async (
      _event: Electron.IpcMainInvokeEvent,
      workspacePath: string,
      policyPath: string,
      submissionID: string,
      testCaseIndex: number,
    ): Promise<void> => {
      startBridgeStreaming([
        "run-test-case",
        "--workspace",
        workspacePath,
        "--policy",
        policyPath,
        "--config-dir",
        workspaceConfigDir(workspacePath),
        "--submission-id",
        submissionID,
        "--test-case-index",
        String(testCaseIndex),
      ]);
    },
  );

  ipcMain.handle("engine:get-capabilities", async (): Promise<unknown> => {
    try {
      return await runBridgeJSONCommand(["capabilities"]);
    } catch {
      return {
        run_session: true,
        run_test_case: false,
        run_all_policy_tests: false,
        diff_payload: false,
      };
    }
  });

  ipcMain.handle("engine:cancel", async (): Promise<void> => {
    stopActiveProcess();
  });
}
