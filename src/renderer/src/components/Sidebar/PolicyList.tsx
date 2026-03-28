import { useEffect, useMemo, useState } from "react";
import { MdDescription, MdMoreHoriz } from "react-icons/md";
import { useAppStore } from "../../stores/appStore";

type ContextMenuState = {
  x: number;
  y: number;
  policyID: string;
} | null;

export function PolicyList() {
  const policies = useAppStore((s) => s.policies);
  const selectedPolicyID = useAppStore((s) => s.selectedPolicyID);
  const selectPolicyForEditing = useAppStore((s) => s.selectPolicyForEditing);
  const createPolicy = useAppStore((s) => s.createPolicy);
  const renamePolicy = useAppStore((s) => s.renamePolicy);
  const deletePolicy = useAppStore((s) => s.deletePolicy);
  const [isCreating, setIsCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [contextMenu, setContextMenu] = useState<ContextMenuState>(null);

  const contextPolicy = useMemo(
    () =>
      policies.find((policy) => policy.id === contextMenu?.policyID) ?? null,
    [contextMenu?.policyID, policies],
  );

  useEffect(() => {
    if (!contextMenu) return;

    const closeMenu = () => setContextMenu(null);
    window.addEventListener("click", closeMenu);
    window.addEventListener("blur", closeMenu);

    return () => {
      window.removeEventListener("click", closeMenu);
      window.removeEventListener("blur", closeMenu);
    };
  }, [contextMenu]);

  const handleCreate = () => {
    if (newName.trim()) {
      createPolicy(newName.trim());
      setNewName("");
      setIsCreating(false);
    }
  };

  const handleRename = () => {
    if (!contextPolicy) return;
    const nextName = window.prompt("Rename policy", contextPolicy.name)?.trim();
    if (!nextName || nextName === contextPolicy.name) {
      setContextMenu(null);
      return;
    }

    renamePolicy(contextPolicy.id, nextName);
    setContextMenu(null);
  };

  const handleDelete = () => {
    if (!contextPolicy) return;
    if (confirm(`Delete policy "${contextPolicy.name}"?`)) {
      deletePolicy(contextPolicy.id);
    }
    setContextMenu(null);
  };

  return (
    <div className="relative flex h-full flex-col">
      <div className="border-b border-separator p-2">
        {isCreating ? (
          <div className="flex gap-1.5">
            <input
              autoFocus
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") handleCreate();
                if (e.key === "Escape") setIsCreating(false);
              }}
              placeholder="Policy name…"
              className="flex-1 bg-canvas rounded px-2 py-1 text-[12px] text-text-primary outline-none border border-separator focus:border-accent"
            />
            <button
              onClick={handleCreate}
              className="text-[11px] text-accent hover:text-accent-hover px-1.5"
            >
              Add
            </button>
          </div>
        ) : (
          <button
            onClick={() => setIsCreating(true)}
            className="w-full rounded-md bg-hover/70 px-2 py-1.5 text-[11px] font-medium text-text-primary hover:bg-hover cursor-default"
          >
            + New Policy
          </button>
        )}
      </div>

      <div className="flex-1 overflow-y-auto py-1">
        {policies.map((policy) => (
          <div
            key={policy.id}
            onClick={() => selectPolicyForEditing(policy.id)}
            onContextMenu={(e) => {
              e.preventDefault();
              setContextMenu({
                x: Math.min(e.clientX, window.innerWidth - 156),
                y: Math.min(e.clientY, window.innerHeight - 80),
                policyID: policy.id,
              });
            }}
            className={`
              mx-1.5 my-0.5 flex items-center justify-between rounded-md px-3 h-[30px] cursor-default text-[12px] group
              ${selectedPolicyID === policy.id ? "bg-selection text-text-primary" : "text-text-primary hover:bg-hover hover:text-text-primary"}
            `}
          >
            <span className="truncate flex items-center gap-2 min-w-0">
              <MdDescription size={16} className="shrink-0 text-text-primary" />
              <span className="truncate font-medium">{policy.name}</span>
            </span>
            <button
              onClick={(e) => {
                e.stopPropagation();
                const rect = e.currentTarget.getBoundingClientRect();
                setContextMenu({
                  x: Math.max(
                    8,
                    Math.min(rect.right - 148, window.innerWidth - 156),
                  ),
                  y: Math.max(
                    8,
                    Math.min(rect.top - 72, window.innerHeight - 82),
                  ),
                  policyID: policy.id,
                });
              }}
              className="opacity-0 group-hover:opacity-100 flex h-6 w-6 items-center justify-center rounded text-text-primary/80 hover:bg-hover hover:text-text-primary"
              title="Policy actions"
            >
              <MdMoreHoriz size={16} />
            </button>
          </div>
        ))}

        {policies.length === 0 && (
          <p className="text-[11px] text-text-secondary/70 px-3 py-2">
            No policies yet.
          </p>
        )}
      </div>

      {contextMenu && contextPolicy && (
        <div
          className="fixed z-50 min-w-[148px] overflow-hidden rounded-md border border-separator bg-pane shadow-lg"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={handleRename}
            className="block w-full px-3 py-2 text-left text-[12px] text-text-primary hover:bg-hover cursor-default"
          >
            Rename
          </button>
          <button
            onClick={handleDelete}
            className="block w-full px-3 py-2 text-left text-[12px] text-red-300 hover:bg-hover cursor-default"
          >
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
