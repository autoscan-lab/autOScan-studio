export interface WorkspaceNode {
  id: string
  name: string
  isDirectory: boolean
  children: WorkspaceNode[]
}

export interface FileTab {
  id: string
  title: string
}

export interface WorkspaceSnapshot {
  rootNodeID: string
  nodes: WorkspaceNode[]
  urlByNodeID: Record<string, string>
}
