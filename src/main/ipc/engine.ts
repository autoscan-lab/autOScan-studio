import { ipcMain, BrowserWindow, app } from "electron";
import { spawn, type ChildProcess } from "child_process";
import { join } from "path";
import { createInterface } from "readline";

let activeProcess: ChildProcess | null = null;

function getBridgePath(): string {
  if (app.isPackaged) {
    return join(process.resourcesPath, "autoscan-bridge");
  }
  return join(__dirname, "../../../Engine/autoscan-bridge");
}

export function registerEngineHandlers(): void {
  ipcMain.handle(
    "engine:run-session",
    async (
      _event: Electron.IpcMainInvokeEvent,
      workspacePath: string,
      policyPath: string,
      submissionPath?: string,
    ): Promise<void> => {
      const win = BrowserWindow.getFocusedWindow();
      if (!win) return;

      if (activeProcess) {
        activeProcess.kill();
        activeProcess = null;
      }

      const bridgePath = getBridgePath();
      const args = submissionPath
        ? [
            "run-submission",
            "--workspace",
            workspacePath,
            "--policy",
            policyPath,
            "--submission",
            submissionPath,
          ]
        : ["run-session", "--workspace", workspacePath, "--policy", policyPath];

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
        stderrChunks += chunk.toString();
        win.webContents.send("engine:output", chunk.toString());
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
    },
  );

  ipcMain.handle("engine:cancel", async (): Promise<void> => {
    if (activeProcess) {
      activeProcess.kill();
      activeProcess = null;
    }
  });
}
