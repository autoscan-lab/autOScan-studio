import { useCallback } from "react";
import { useAppStore } from "../../stores/appStore";
import type { WorkspaceNode } from "../../types/workspace";
import { FileIcon } from "../FileIcon";

export function FileTree() {
  const nodes = useAppStore((s) => s.workspaceNodes);
  const expandedIDs = useAppStore((s) => s.expandedDirectoryIDs);
  const selectedID = useAppStore((s) => s.selectedFileNodeID);
  const selectFile = useAppStore((s) => s.selectFile);
  const toggleDirectory = useAppStore((s) => s.toggleDirectory);

  return (
    <div className="flex-1 overflow-y-auto py-1">
      {nodes.map((node) => (
        <TreeNode
          key={node.id}
          node={node}
          depth={0}
          expandedIDs={expandedIDs}
          selectedID={selectedID}
          onSelect={selectFile}
          onToggle={toggleDirectory}
        />
      ))}
    </div>
  );
}

function TreeNode({
  node,
  depth,
  expandedIDs,
  selectedID,
  onSelect,
  onToggle,
}: {
  node: WorkspaceNode;
  depth: number;
  expandedIDs: Set<string>;
  selectedID: string | null;
  onSelect: (id: string) => Promise<void>;
  onToggle: (id: string) => void;
}) {
  const isExpanded = expandedIDs.has(node.id);
  const isSelected = selectedID === node.id;

  const handleClick = useCallback(() => {
    if (node.isDirectory) {
      onToggle(node.id);
    } else {
      onSelect(node.id);
    }
  }, [node.id, node.isDirectory, onToggle, onSelect]);

  return (
    <>
      <div
        onClick={handleClick}
        className={`
          mx-1.5 my-0.5 flex items-center h-[27px] rounded-md px-2 cursor-default text-[12px]
          ${isSelected ? "bg-selection text-text-primary" : "text-text-secondary hover:bg-hover hover:text-text-primary"}
        `}
        style={{ paddingLeft: `${depth * 14 + 10}px` }}
      >
        <span className="mr-2 shrink-0 flex items-center">
          <FileIcon
            name={node.name}
            isDirectory={node.isDirectory}
            isOpen={isExpanded}
            size={node.isDirectory ? 14 : 12}
          />
        </span>
        <span className="truncate font-medium">{node.name}</span>
      </div>

      {node.isDirectory && isExpanded && (
        <>
          {node.children.map((child) => (
            <TreeNode
              key={child.id}
              node={child}
              depth={depth + 1}
              expandedIDs={expandedIDs}
              selectedID={selectedID}
              onSelect={onSelect}
              onToggle={onToggle}
            />
          ))}
        </>
      )}
    </>
  );
}
