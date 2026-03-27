import { contextBridge, ipcRenderer } from "electron";

export const api = {
  // Workspace
  loadWorkspace: (rootPath: string) =>
    ipcRenderer.invoke("workspace:load", rootPath),
  readFile: (filePath: string) =>
    ipcRenderer.invoke("workspace:read-file", filePath),
  listPolicies: (rootPath: string) =>
    ipcRenderer.invoke("workspace:list-policies", rootPath),
  readPolicy: (policyPath: string) =>
    ipcRenderer.invoke("workspace:read-policy", policyPath),
  savePolicy: (policyPath: string, content: string) =>
    ipcRenderer.invoke("workspace:save-policy", policyPath, content),
  createPolicy: (rootPath: string, fileName: string, content: string) =>
    ipcRenderer.invoke("workspace:create-policy", rootPath, fileName, content),
  renamePolicy: (policyPath: string, nextName: string, content?: string) =>
    ipcRenderer.invoke(
      "workspace:rename-policy",
      policyPath,
      nextName,
      content,
    ),
  deletePolicy: (policyPath: string) =>
    ipcRenderer.invoke("workspace:delete-policy", policyPath),
  fileExtension: (filePath: string) =>
    ipcRenderer.invoke("workspace:file-extension", filePath),
  importFiles: (rootPath: string, subdir: string, filePaths: string[]) =>
    ipcRenderer.invoke(
      "workspace:import-files",
      rootPath,
      subdir,
      filePaths,
    ) as Promise<string[]>,

  // Dialogs
  openDirectory: () => ipcRenderer.invoke("dialog:open-directory"),
  openFiles: (
    title: string,
    filters?: { name: string; extensions: string[] }[],
  ) => ipcRenderer.invoke("dialog:open-files", title, filters),

  // Engine
  runSession: (
    workspacePath: string,
    policyPath: string,
    submissionPath?: string,
  ) =>
    ipcRenderer.invoke(
      "engine:run-session",
      workspacePath,
      policyPath,
      submissionPath,
    ),
  cancelRun: () => ipcRenderer.invoke("engine:cancel"),
  onEngineEvent: (callback: (event: unknown) => void) => {
    const handler = (_: unknown, event: unknown) => callback(event);
    ipcRenderer.on("engine:event", handler);
    return () => ipcRenderer.removeListener("engine:event", handler);
  },
  onEngineOutput: (callback: (text: string) => void) => {
    const handler = (_: unknown, text: string) => callback(text);
    ipcRenderer.on("engine:output", handler);
    return () => ipcRenderer.removeListener("engine:output", handler);
  },
  onEngineDone: (callback: (code: number) => void) => {
    const handler = (_: unknown, code: number) => callback(code);
    ipcRenderer.on("engine:done", handler);
    return () => ipcRenderer.removeListener("engine:done", handler);
  },

  // Store (persistence)
  storeGet: (key: string) => ipcRenderer.invoke("store:get", key),
  storeSet: (key: string, value: unknown) =>
    ipcRenderer.invoke("store:set", key, value),

  // Menu events
  onMenuEvent: (channel: string, callback: () => void) => {
    const handler = () => callback();
    ipcRenderer.on(channel, handler);
    return () => ipcRenderer.removeListener(channel, handler);
  },

  onWindowFullscreenChanged: (callback: (isFullscreen: boolean) => void) => {
    const handler = (_: unknown, isFullscreen: boolean) => callback(isFullscreen);
    ipcRenderer.on("window:fullscreen-changed", handler);
    return () => ipcRenderer.removeListener("window:fullscreen-changed", handler);
  },
};

export type ElectronAPI = typeof api;

contextBridge.exposeInMainWorld("api", api);
