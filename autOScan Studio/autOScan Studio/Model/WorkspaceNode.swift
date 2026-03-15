import Foundation

final class WorkspaceNode: Identifiable {
    let id: String
    let name: String
    let isDirectory: Bool
    let children: [WorkspaceNode]

    init(id: String, name: String, isDirectory: Bool, children: [WorkspaceNode]) {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
        self.children = children
    }
}
