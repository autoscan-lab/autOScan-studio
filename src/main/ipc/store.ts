import { ipcMain } from "electron";
const Store = require("electron-store").default;

const store = new Store({
  name: "autoscan-studio-preferences",
  defaults: {
    workspacePath: null as string | null,
    expandedDirectoryIDs: [] as string[],
    selectedFileNodeID: null as string | null,
    activePolicyID: null as string | null,
    sidebarMode: "workspace",
    isSidebarVisible: true,
    isInspectorVisible: false,
    isOutputVisible: false,
  },
});

export function registerStoreHandlers(): void {
  ipcMain.handle("store:get", (_event, key: string) => {
    return store.get(key);
  });

  ipcMain.handle("store:set", (_event, key: string, value: unknown) => {
    store.set(key, value);
  });
}
