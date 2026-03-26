import { create } from "zustand";
import type {
  WorkspaceNode,
  FileTab,
  WorkspaceSnapshot,
} from "../types/workspace";
import type { PolicyFile, PolicyDraft, TestCase } from "../types/policy";
import type { EngineRunReport, EngineRunEvent } from "../types/engine";
import { createTestCase, createStarterPolicy } from "../types/policy";
import { parsePolicy, serializePolicy } from "../lib/policyYaml";

export type SidebarMode = "workspace" | "policies";
export type EditorDocumentKind = "source" | "notice";
export type BannerKind = "success" | "error" | "info";

export interface PolicyBanner {
  id: string;
  kind: BannerKind;
  message: string;
}

interface AppState {
  // Sidebar
  sidebarMode: SidebarMode;
  isSidebarVisible: boolean;
  isInspectorVisible: boolean;
  isOutputVisible: boolean;

  // Workspace
  workspaceRootPath: string | null;
  workspaceNodes: WorkspaceNode[];
  urlByNodeID: Record<string, string>;
  expandedDirectoryIDs: Set<string>;
  selectedFileNodeID: string | null;
  openFileNodeIDs: string[];
  toolbarTitle: string;

  // Editor
  editorText: string;
  editorDocumentKind: EditorDocumentKind;
  editorFilePath: string | null;

  // Policies
  policies: PolicyFile[];
  selectedPolicyID: string | null;
  activePolicyID: string | null;
  selectedPolicyDraft: PolicyDraft | null;
  loadedPolicyText: string;
  selectedPolicyTestCaseID: string | null;
  policyBanner: PolicyBanner | null;
  isPolicyDirty: boolean;

  // Run
  runOutputText: string;
  isRunInProgress: boolean;
  runStatusMessage: string;
  latestRunReport: EngineRunReport | null;
  latestRunError: string | null;

  // Actions
  setSidebarMode: (mode: SidebarMode) => void;
  toggleSidebar: () => void;
  toggleInspector: () => void;
  toggleOutput: () => void;
  openWorkspace: () => Promise<void>;
  loadWorkspace: (
    rootPath: string,
    restoredExpanded?: string[],
    restoredSelected?: string | null,
  ) => Promise<void>;
  selectFile: (nodeID: string | null) => Promise<void>;
  toggleDirectory: (nodeID: string) => void;
  closeTab: (nodeID: string) => void;
  refreshPolicies: () => Promise<void>;
  selectPolicyForEditing: (policyID: string) => Promise<void>;
  updatePolicyDraft: (draft: PolicyDraft) => void;
  addTestCase: () => void;
  removeTestCase: (id: string) => void;
  updateTestCase: (id: string, updates: Partial<TestCase>) => void;
  savePolicy: () => Promise<void>;
  createPolicy: (name: string) => Promise<void>;
  renamePolicy: (policyID: string, nextName: string) => Promise<void>;
  deletePolicy: (policyID: string) => Promise<void>;
  setActivePolicy: (policyID: string | null) => void;
  runWorkspaceSession: () => Promise<void>;
  runSubmission: (submissionPath: string) => Promise<void>;
  cancelRun: () => Promise<void>;
  clearOutput: () => void;
  handleEngineEvent: (event: EngineRunEvent) => void;
  appendOutput: (text: string) => void;
  setRunDone: (code: number) => void;
  setPolicyBanner: (kind: BannerKind, message: string) => void;
  clearPolicyBanner: () => void;
  restoreSession: () => Promise<void>;
  persist: () => void;
}

function getOpenFileTabs(nodes: WorkspaceNode[], openIDs: string[]): FileTab[] {
  const nameMap: Record<string, string> = {};
  function walk(n: WorkspaceNode): void {
    nameMap[n.id] = n.name;
    n.children.forEach(walk);
  }
  nodes.forEach(walk);
  return openIDs.map((id) => ({
    id,
    title: nameMap[id] || id.split("/").pop() || "unknown",
  }));
}

function collectDirectoryIDs(nodes: WorkspaceNode[]): Set<string> {
  const ids = new Set<string>();
  function walk(n: WorkspaceNode): void {
    if (n.isDirectory) {
      ids.add(n.id);
      n.children.forEach(walk);
    }
  }
  nodes.forEach(walk);
  return ids;
}

export const useAppStore = create<AppState>((set, get) => ({
  // Initial state
  sidebarMode: "workspace",
  isSidebarVisible: true,
  isInspectorVisible: false,
  isOutputVisible: false,
  workspaceRootPath: null,
  workspaceNodes: [],
  urlByNodeID: {},
  expandedDirectoryIDs: new Set(),
  selectedFileNodeID: null,
  openFileNodeIDs: [],
  toolbarTitle: "autOScan Studio",
  editorText: "Select a file to preview.",
  editorDocumentKind: "notice",
  editorFilePath: null,
  policies: [],
  selectedPolicyID: null,
  activePolicyID: null,
  selectedPolicyDraft: null,
  loadedPolicyText: "",
  selectedPolicyTestCaseID: null,
  policyBanner: null,
  isPolicyDirty: false,
  runOutputText: "",
  isRunInProgress: false,
  runStatusMessage: "Ready to run",
  latestRunReport: null,
  latestRunError: null,

  // Actions
  setSidebarMode: (mode) => {
    set({ sidebarMode: mode });
    get().persist();
  },

  toggleSidebar: () => {
    set((s) => ({ isSidebarVisible: !s.isSidebarVisible }));
    get().persist();
  },

  toggleInspector: () => {
    set((s) => ({ isInspectorVisible: !s.isInspectorVisible }));
    get().persist();
  },

  toggleOutput: () => {
    set((s) => ({ isOutputVisible: !s.isOutputVisible }));
    get().persist();
  },

  openWorkspace: async () => {
    const path = await window.api.openDirectory();
    if (path) {
      await get().loadWorkspace(path);
    }
  },

  loadWorkspace: async (rootPath, restoredExpanded, restoredSelected) => {
    const snapshot: WorkspaceSnapshot =
      await window.api.loadWorkspace(rootPath);
    const dirIDs = collectDirectoryIDs(snapshot.nodes);
    const restored = restoredExpanded
      ? new Set(restoredExpanded.filter((id) => dirIDs.has(id)))
      : new Set<string>();
    restored.add(snapshot.rootNodeID);

    set({
      workspaceRootPath: rootPath,
      workspaceNodes: snapshot.nodes,
      urlByNodeID: snapshot.urlByNodeID,
      toolbarTitle: rootPath.split("/").pop() || rootPath,
      expandedDirectoryIDs: restored,
      openFileNodeIDs: [],
      editorText: "Select a file to preview.",
      editorDocumentKind: "notice",
      editorFilePath: null,
      selectedFileNodeID: null,
    });

    await get().refreshPolicies();

    if (restoredSelected) {
      await get().selectFile(restoredSelected);
    }

    // Restore active policy
    const storedActivePolicyID = (await window.api.storeGet(
      "activePolicyID",
    )) as string | null;
    const policies = get().policies;
    if (
      storedActivePolicyID &&
      policies.some((p) => p.id === storedActivePolicyID)
    ) {
      set({ activePolicyID: storedActivePolicyID });
    } else if (policies.length > 0) {
      set({ activePolicyID: policies[0].id });
    }

    // Auto-select policy for editing
    const selectedPolicyID = get().selectedPolicyID;
    if (selectedPolicyID) {
      await get().selectPolicyForEditing(selectedPolicyID);
    } else {
      const active = get().activePolicyID ?? policies[0]?.id;
      if (active) await get().selectPolicyForEditing(active);
    }

    window.api.storeSet("workspacePath", rootPath);
    get().persist();
  },

  selectFile: async (nodeID) => {
    if (!nodeID) {
      set({
        selectedFileNodeID: null,
        editorText: "Select a file to preview.",
        editorDocumentKind: "notice",
        editorFilePath: null,
      });
      get().persist();
      return;
    }

    const { urlByNodeID } = get();
    const filePath = urlByNodeID[nodeID];
    if (!filePath) return;

    // Add to open tabs if not already there
    set((s) => {
      const ids = s.openFileNodeIDs.includes(nodeID)
        ? s.openFileNodeIDs
        : [...s.openFileNodeIDs, nodeID];
      return { openFileNodeIDs: ids, selectedFileNodeID: nodeID };
    });

    try {
      const content = await window.api.readFile(filePath);
      set({
        editorText: content,
        editorDocumentKind: "source",
        editorFilePath: filePath,
      });
    } catch {
      set({
        editorText: "Unable to read file.",
        editorDocumentKind: "notice",
        editorFilePath: null,
      });
    }
    get().persist();
  },

  toggleDirectory: (nodeID) => {
    set((s) => {
      const next = new Set(s.expandedDirectoryIDs);
      if (next.has(nodeID)) next.delete(nodeID);
      else next.add(nodeID);
      return { expandedDirectoryIDs: next };
    });
    get().persist();
  },

  closeTab: (nodeID) => {
    set((s) => {
      const ids = s.openFileNodeIDs.filter((id) => id !== nodeID);
      const needsNewSelection = s.selectedFileNodeID === nodeID;
      return {
        openFileNodeIDs: ids,
        selectedFileNodeID: needsNewSelection
          ? (ids[ids.length - 1] ?? null)
          : s.selectedFileNodeID,
      };
    });
    const { selectedFileNodeID } = get();
    if (selectedFileNodeID) {
      get().selectFile(selectedFileNodeID);
    } else {
      set({
        editorText: "Select a file to preview.",
        editorDocumentKind: "notice",
        editorFilePath: null,
      });
    }
  },

  refreshPolicies: async () => {
    const rootPath = get().workspaceRootPath;
    if (!rootPath) return;
    const policies: PolicyFile[] = await window.api.listPolicies(rootPath);
    set({ policies });
  },

  selectPolicyForEditing: async (policyID) => {
    const policy = get().policies.find((p) => p.id === policyID);
    if (!policy) return;

    set({ selectedPolicyID: policyID });

    try {
      const text = await window.api.readPolicy(policy.path);
      const draft = parsePolicy(text);
      set({
        selectedPolicyDraft: draft,
        loadedPolicyText: text,
        isPolicyDirty: false,
        selectedPolicyTestCaseID: draft.testCases[0]?.id ?? null,
      });
    } catch {
      set({
        selectedPolicyDraft: null,
        loadedPolicyText: "",
        isPolicyDirty: false,
      });
    }
  },

  updatePolicyDraft: (draft) => {
    const current = get().loadedPolicyText;
    const newText = serializePolicy(draft);
    set({
      selectedPolicyDraft: draft,
      isPolicyDirty: newText !== current,
    });
  },

  addTestCase: () => {
    const draft = get().selectedPolicyDraft;
    if (!draft) return;
    const tc = createTestCase({ name: `Test ${draft.testCases.length + 1}` });
    const updated = { ...draft, testCases: [...draft.testCases, tc] };
    get().updatePolicyDraft(updated);
    set({ selectedPolicyTestCaseID: tc.id });
  },

  removeTestCase: (id) => {
    const draft = get().selectedPolicyDraft;
    if (!draft) return;
    const updated = {
      ...draft,
      testCases: draft.testCases.filter((tc) => tc.id !== id),
    };
    get().updatePolicyDraft(updated);
    if (get().selectedPolicyTestCaseID === id) {
      set({ selectedPolicyTestCaseID: updated.testCases[0]?.id ?? null });
    }
  },

  updateTestCase: (id, updates) => {
    const draft = get().selectedPolicyDraft;
    if (!draft) return;
    const updated = {
      ...draft,
      testCases: draft.testCases.map((tc) =>
        tc.id === id ? { ...tc, ...updates } : tc,
      ),
    };
    get().updatePolicyDraft(updated);
  },

  savePolicy: async () => {
    const { selectedPolicyID, selectedPolicyDraft, policies } = get();
    if (!selectedPolicyID || !selectedPolicyDraft) return;

    const policy = policies.find((p) => p.id === selectedPolicyID);
    if (!policy) return;

    const yaml = serializePolicy(selectedPolicyDraft);
    try {
      await window.api.savePolicy(policy.path, yaml);
      set({ loadedPolicyText: yaml, isPolicyDirty: false });
      get().setPolicyBanner("success", "Policy saved.");
    } catch (err) {
      get().setPolicyBanner("error", `Save failed: ${err}`);
    }
  },

  createPolicy: async (name) => {
    const rootPath = get().workspaceRootPath;
    if (!rootPath) return;
    const draft = createStarterPolicy(name);
    const yaml = serializePolicy(draft);
    const fileName = name.toLowerCase().replace(/\s+/g, "-") + ".yaml";
    try {
      const fullPath = await window.api.createPolicy(rootPath, fileName, yaml);
      await get().refreshPolicies();
      set({ activePolicyID: fullPath });
      await get().selectPolicyForEditing(fullPath);
      get().setPolicyBanner("success", `Created policy "${name}".`);
    } catch (err) {
      get().setPolicyBanner("error", `Create failed: ${err}`);
    }
  },

  renamePolicy: async (policyID, nextName) => {
    const policies = get().policies;
    const policy = policies.find((p) => p.id === policyID);
    const trimmedName = nextName.trim();

    if (!policy || !trimmedName) return;

    try {
      const currentText = await window.api.readPolicy(policy.path);
      const draft = parsePolicy(currentText);
      const updatedDraft = { ...draft, name: trimmedName };
      const yaml = serializePolicy(updatedDraft);
      const fileName = trimmedName.toLowerCase().replace(/\s+/g, "-") + ".yaml";
      const fullPath = await window.api.renamePolicy(
        policy.path,
        fileName,
        yaml,
      );

      await get().refreshPolicies();

      const nextPolicies = get().policies;
      const renamedPolicy =
        nextPolicies.find((p) => p.id === fullPath) ?? nextPolicies[0];

      if (!renamedPolicy) {
        set({
          selectedPolicyID: null,
          activePolicyID: null,
          selectedPolicyDraft: null,
          loadedPolicyText: "",
          isPolicyDirty: false,
        });
        get().setPolicyBanner("success", `Renamed policy to "${trimmedName}".`);
        get().persist();
        return;
      }

      set({
        selectedPolicyID:
          get().selectedPolicyID === policyID
            ? renamedPolicy.id
            : get().selectedPolicyID,
        activePolicyID:
          get().activePolicyID === policyID
            ? renamedPolicy.id
            : get().activePolicyID,
      });

      await get().selectPolicyForEditing(renamedPolicy.id);

      get().setPolicyBanner("success", `Renamed policy to "${trimmedName}".`);
      get().persist();
    } catch (err) {
      get().setPolicyBanner("error", `Rename failed: ${err}`);
    }
  },

  deletePolicy: async (policyID) => {
    try {
      await window.api.deletePolicy(policyID);
      await get().refreshPolicies();
      const policies = get().policies;
      if (get().selectedPolicyID === policyID) {
        if (policies.length > 0) {
          await get().selectPolicyForEditing(policies[0].id);
        } else {
          set({ selectedPolicyID: null, selectedPolicyDraft: null });
        }
      }
      if (get().activePolicyID === policyID) {
        set({ activePolicyID: policies[0]?.id ?? null });
      }
      get().setPolicyBanner("info", "Policy deleted.");
    } catch (err) {
      get().setPolicyBanner("error", `Delete failed: ${err}`);
    }
  },

  setActivePolicy: (policyID) => {
    set({ activePolicyID: policyID });
    get().persist();
  },

  runWorkspaceSession: async () => {
    const { workspaceRootPath, activePolicyID, policies } = get();
    if (!workspaceRootPath || !activePolicyID) return;

    const policy = policies.find((p) => p.id === activePolicyID);
    if (!policy) return;

    set({
      isRunInProgress: true,
      runOutputText: "",
      runStatusMessage: "Starting…",
      latestRunReport: null,
      latestRunError: null,
      isOutputVisible: true,
    });

    await window.api.runSession(workspaceRootPath, policy.path);
  },

  runSubmission: async (submissionPath) => {
    const { workspaceRootPath, activePolicyID, policies } = get();
    if (!workspaceRootPath || !activePolicyID) return;

    const policy = policies.find((p) => p.id === activePolicyID);
    if (!policy) return;

    set({
      isRunInProgress: true,
      runOutputText: "",
      runStatusMessage: "Running submission…",
      latestRunReport: null,
      latestRunError: null,
      isOutputVisible: true,
    });

    await window.api.runSession(workspaceRootPath, policy.path, submissionPath);
  },

  cancelRun: async () => {
    await window.api.cancelRun();
    set({ isRunInProgress: false, runStatusMessage: "Cancelled" });
  },

  clearOutput: () => {
    set({ runOutputText: "" });
  },

  handleEngineEvent: (event) => {
    switch (event.type) {
      case "started":
        set({
          runStatusMessage: event.message || "Starting run…",
        });
        break;
      case "discovery_complete": {
        const discoveredCount = event.discovery?.submission_count;
        set((s) => ({
          runOutputText:
            s.runOutputText +
            `Discovered ${discoveredCount ?? "?"} submissions\n`,
          runStatusMessage:
            discoveredCount !== undefined
              ? `Discovered ${discoveredCount} submissions`
              : s.runStatusMessage,
        }));
        break;
      }
      case "compile_complete": {
        const compileStatus = event.compile?.timed_out
          ? "timeout"
          : event.compile?.ok
            ? "pass"
            : "fail";
        const submissionID = event.compile?.submission_id ?? "unknown";
        set((s) => ({
          runOutputText:
            s.runOutputText + `Compiled ${submissionID} (${compileStatus})\n`,
        }));
        break;
      }
      case "scan_complete": {
        const submissionID = event.scan?.submission_id ?? "unknown";
        const bannedHits = event.scan?.banned_hits ?? 0;
        set((s) => ({
          runOutputText:
            s.runOutputText +
            `Scanned ${submissionID} (${bannedHits} banned hits)\n`,
        }));
        break;
      }
      case "run_complete": {
        const report = {
          summary: {
            policyName: event.run.summary.policy_name,
            root: event.run.summary.root,
            startedAt: event.run.summary.started_at,
            finishedAt: event.run.summary.finished_at,
            durationMs: event.run.summary.duration_ms,
            totalSubmissions: event.run.summary.total_submissions,
            compilePass: event.run.summary.compile_pass,
            compileFail: event.run.summary.compile_fail,
            compileTimeout: event.run.summary.compile_timeout,
            cleanSubmissions: event.run.summary.clean_submissions,
            submissionsWithBanned: event.run.summary.submissions_with_banned,
            bannedHits: event.run.summary.banned_hits_total,
            topBannedFunctions: event.run.summary.top_banned_functions,
          },
          submissions: event.run.submissions.map((submission) => {
            const compileStatus: "pass" | "fail" | "timeout" =
              submission.compile_timeout
                ? "timeout"
                : submission.compile_ok
                  ? "pass"
                  : "fail";

            return {
              id: submission.id,
              submissionPath: submission.path,
              status: submission.status,
              cFiles: submission.c_files,
              compileOk: submission.compile_ok,
              compileStatus,
              compileTimeout: submission.compile_timeout,
              bannedHitCount: submission.banned_count,
              exitCode: submission.exit_code,
              compileTimeMs: submission.compile_time_ms,
              stderr: submission.stderr ?? "",
            };
          }),
        };

        set({
          latestRunReport: report,
          runStatusMessage: `Done — ${report.summary.totalSubmissions} submissions graded`,
          isInspectorVisible: true,
        });
        break;
      }
      case "error":
        set({
          latestRunError: event.message,
          runStatusMessage: "Error",
        });
        break;
    }
  },

  appendOutput: (text) => {
    set((s) => ({ runOutputText: s.runOutputText + text }));
  },

  setRunDone: (code) => {
    set((s) => ({
      isRunInProgress: false,
      runStatusMessage: s.latestRunReport
        ? s.runStatusMessage
        : code === 0
          ? "Done"
          : `Engine exited with code ${code}`,
    }));
  },

  setPolicyBanner: (kind, message) => {
    set({ policyBanner: { id: crypto.randomUUID(), kind, message } });
    setTimeout(() => {
      set({ policyBanner: null });
    }, 3000);
  },

  clearPolicyBanner: () => {
    set({ policyBanner: null });
  },

  restoreSession: async () => {
    const workspacePath = (await window.api.storeGet("workspacePath")) as
      | string
      | null;
    const expanded = (await window.api.storeGet("expandedDirectoryIDs")) as
      | string[]
      | null;
    const selected = (await window.api.storeGet("selectedFileNodeID")) as
      | string
      | null;
    const sidebarMode = (await window.api.storeGet(
      "sidebarMode",
    )) as SidebarMode | null;
    const isSidebarVisible = (await window.api.storeGet("isSidebarVisible")) as
      | boolean
      | null;
    const isInspectorVisible = (await window.api.storeGet(
      "isInspectorVisible",
    )) as boolean | null;
    const isOutputVisible = (await window.api.storeGet("isOutputVisible")) as
      | boolean
      | null;

    if (sidebarMode) set({ sidebarMode });
    if (isSidebarVisible !== null) set({ isSidebarVisible });
    if (isInspectorVisible !== null) set({ isInspectorVisible });
    if (isOutputVisible !== null) set({ isOutputVisible });

    if (workspacePath) {
      await get().loadWorkspace(workspacePath, expanded ?? undefined, selected);
    }
  },

  persist: () => {
    const s = get();
    window.api.storeSet("sidebarMode", s.sidebarMode);
    window.api.storeSet("isSidebarVisible", s.isSidebarVisible);
    window.api.storeSet("isInspectorVisible", s.isInspectorVisible);
    window.api.storeSet("isOutputVisible", s.isOutputVisible);
    window.api.storeSet(
      "expandedDirectoryIDs",
      Array.from(s.expandedDirectoryIDs),
    );
    window.api.storeSet("selectedFileNodeID", s.selectedFileNodeID);
    window.api.storeSet("activePolicyID", s.activePolicyID);
  },
}));

// Helpers
export function useOpenFileTabs(): FileTab[] {
  const nodes = useAppStore((s) => s.workspaceNodes);
  const openIDs = useAppStore((s) => s.openFileNodeIDs);
  return getOpenFileTabs(nodes, openIDs);
}

export function useHasWorkspace(): boolean {
  return useAppStore((s) => s.workspaceRootPath !== null);
}

export function useSelectedPolicyDisplayName(): string | null {
  const policies = useAppStore((s) => s.policies);
  const selectedID = useAppStore((s) => s.selectedPolicyID);
  return policies.find((p) => p.id === selectedID)?.name ?? null;
}
