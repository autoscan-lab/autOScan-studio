import { ipcMain } from "electron";
import {
  readdir,
  stat,
  readFile,
  writeFile,
  mkdir,
  rename,
  unlink,
} from "fs/promises";
import { join, basename, extname } from "path";
type WorkspaceNode = {
  id: string;
  name: string;
  isDirectory: boolean;
  children: WorkspaceNode[];
};

type WorkspaceSnapshot = {
  rootNodeID: string;
  nodes: WorkspaceNode[];
  urlByNodeID: Record<string, string>;
};

const MAX_FILE_SIZE = 1_000_000; // 1MB

export function registerWorkspaceHandlers(): void {
  ipcMain.handle(
    "workspace:load",
    async (_event, rootPath: string): Promise<WorkspaceSnapshot> => {
      const urlByNodeID: Record<string, string> = {};

      async function buildTree(dirPath: string): Promise<WorkspaceNode[]> {
        const entries = await readdir(dirPath, { withFileTypes: true });
        const nodes: WorkspaceNode[] = [];

        const sorted = entries
          .filter((e) => !e.name.startsWith("."))
          .sort((a, b) => {
            if (a.isDirectory() && !b.isDirectory()) return -1;
            if (!a.isDirectory() && b.isDirectory()) return 1;
            return a.name.localeCompare(b.name);
          });

        for (const entry of sorted) {
          const fullPath = join(dirPath, entry.name);
          const nodeID = fullPath;

          urlByNodeID[nodeID] = fullPath;

          if (entry.isDirectory()) {
            const children = await buildTree(fullPath);
            nodes.push({
              id: nodeID,
              name: entry.name,
              isDirectory: true,
              children,
            });
          } else {
            nodes.push({
              id: nodeID,
              name: entry.name,
              isDirectory: false,
              children: [],
            });
          }
        }

        return nodes;
      }

      const children = await buildTree(rootPath);
      const rootNodeID = rootPath;
      urlByNodeID[rootNodeID] = rootPath;

      const rootNode: WorkspaceNode = {
        id: rootNodeID,
        name: basename(rootPath),
        isDirectory: true,
        children,
      };

      return { rootNodeID, nodes: [rootNode], urlByNodeID };
    },
  );

  ipcMain.handle(
    "workspace:read-file",
    async (_event, filePath: string): Promise<string> => {
      const info = await stat(filePath);
      if (info.size > MAX_FILE_SIZE) {
        return `File is too large to preview (${(info.size / 1024).toFixed(0)} KB).`;
      }

      const buffer = await readFile(filePath);
      return buffer.toString("utf-8");
    },
  );

  ipcMain.handle(
    "workspace:write-text-file",
    async (_event, filePath: string, content: string): Promise<void> => {
      await writeFile(filePath, content, "utf-8");
    },
  );

  ipcMain.handle(
    "workspace:list-policies",
    async (_event, rootPath: string) => {
      const policiesDir = join(rootPath, "policies");
      try {
        const entries = await readdir(policiesDir, { withFileTypes: true });
        return entries
          .filter(
            (e) =>
              !e.isDirectory() &&
              (e.name.endsWith(".yaml") || e.name.endsWith(".yml")),
          )
          .map((e) => ({
            id: join(policiesDir, e.name),
            name: e.name.replace(/\.(yaml|yml)$/, ""),
            path: join(policiesDir, e.name),
          }));
      } catch {
        return [];
      }
    },
  );

  ipcMain.handle(
    "workspace:read-policy",
    async (_event, policyPath: string): Promise<string> => {
      const buffer = await readFile(policyPath);
      return buffer.toString("utf-8");
    },
  );

  ipcMain.handle(
    "workspace:save-policy",
    async (_event, policyPath: string, content: string): Promise<void> => {
      await writeFile(policyPath, content, "utf-8");
    },
  );

  ipcMain.handle(
    "workspace:create-policy",
    async (
      _event,
      rootPath: string,
      fileName: string,
      content: string,
    ): Promise<string> => {
      const policiesDir = join(rootPath, "policies");
      await mkdir(policiesDir, { recursive: true });
      const fullPath = join(policiesDir, fileName);
      await writeFile(fullPath, content, "utf-8");
      return fullPath;
    },
  );

  ipcMain.handle(
    "workspace:rename-policy",
    async (
      _event,
      policyPath: string,
      nextFileName: string,
      content: string,
    ): Promise<string> => {
      const nextPath = join(
        policyPath.slice(0, policyPath.lastIndexOf("/")),
        nextFileName,
      );
      await writeFile(policyPath, content, "utf-8");
      await rename(policyPath, nextPath);
      return nextPath;
    },
  );

  ipcMain.handle(
    "workspace:delete-policy",
    async (_event, policyPath: string): Promise<void> => {
      await unlink(policyPath);
    },
  );

  ipcMain.handle(
    "workspace:file-extension",
    (_event, filePath: string): string => {
      return extname(filePath).toLowerCase();
    },
  );

  ipcMain.handle(
    "workspace:import-files",
    async (
      _event,
      rootPath: string,
      subdir: string,
      filePaths: string[],
    ): Promise<string[]> => {
      const normalizedSubdir =
        subdir === "expected-output" ? "expected_outputs" : subdir;
      const targetDir = join(rootPath, ".autoscan", normalizedSubdir);
      await mkdir(targetDir, { recursive: true });

      const importedPaths: string[] = [];

      for (const src of filePaths) {
        const fileName = basename(src);
        const dest = join(targetDir, fileName);
        const content = await readFile(src);
        await writeFile(dest, content);
        importedPaths.push(join(".autoscan", normalizedSubdir, fileName));
      }

      return importedPaths;
    },
  );
}
