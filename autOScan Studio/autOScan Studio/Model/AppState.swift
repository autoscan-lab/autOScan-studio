import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    let workspaceRootNodeID = "__workspace_root__"

    struct SidebarNode: Identifiable, Hashable {
        let id: String
        let displayName: String
        let isDirectory: Bool
        let children: [SidebarNode]?
    }

    enum SidebarMode: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case policies = "Policies"
        case runs = "Runs"

        var id: String { rawValue }
    }

    var sidebarMode: SidebarMode = .workspace
    var isSidebarPresented = true
    var isInspectorPresented = false
    var isOutputPresented = false
    var workspaceTitle = ""
    var expandedDirectoryIDs: Set<String> = []
    var selectedPath: String? {
        didSet {
            updateEditorForSelection()
            if let selectedPath {
                expandAncestors(of: selectedPath)
            }
        }
    }
    var workspaceNodes: [SidebarNode] = []
    var editorText = ""

    var activePolicy = ""
    var runStatus = "Not run"
    var compileStatus = "Not run"
    var bannedStatus = "Not run"
    var bannedHits = 0
    var exportStatus = "Not exported"

    var outputText = ""

    private var workspaceURLsByID: [String: URL] = [:]

    init() {
        workspaceTitle = ""
    }

    var toolbarTitle: String {
        if let selectedPath, !selectedPath.isEmpty {
            return selectedPath
        }
        return "No file selected"
    }

    var sidebarNodes: [SidebarNode] {
        switch sidebarMode {
        case .workspace:
            workspaceNodes
        case .policies:
            filteredLeafNodes(matching: { id in
                id.hasSuffix(".yaml") || id.contains("policy")
            })
        case .runs:
            filteredLeafNodes(matching: { id in
                id.contains("report") || id.contains("run")
            })
        }
    }

    func openWorkspacePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open Workspace"
        panel.message = "Choose a folder to use as the workspace."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadWorkspace(at: url)
    }

    func loadWorkspace(at rootURL: URL) {
        var index: [String: URL] = [:]
        let children = makeNodes(in: rootURL, rootURL: rootURL, index: &index)

        workspaceTitle = rootURL.lastPathComponent + "/"
        workspaceNodes = children
        workspaceURLsByID = index
        expandedDirectoryIDs = []
        selectedPath = nil
    }

    func isDirectoryExpanded(_ id: String) -> Bool {
        expandedDirectoryIDs.contains(id)
    }

    func toggleDirectoryExpansion(_ id: String) {
        if expandedDirectoryIDs.contains(id) {
            expandedDirectoryIDs.remove(id)
            return
        }
        expandedDirectoryIDs.insert(id)
    }

    private func filteredLeafNodes(matching predicate: (String) -> Bool) -> [SidebarNode] {
        let matches = allNodeIDs(in: workspaceNodes)
            .filter { id in
                !id.hasSuffix("/") && predicate(id)
            }
            .sorted()
            .map { id in
                SidebarNode(
                    id: id,
                    displayName: id,
                    isDirectory: false,
                    children: nil
                )
            }

        return matches
    }

    private func allNodeIDs(in nodes: [SidebarNode]) -> [String] {
        nodes.flatMap { node in
            if let children = node.children {
                return [node.id] + allNodeIDs(in: children)
            }
            return [node.id]
        }
    }

    private func makeNodes(
        in directoryURL: URL,
        rootURL: URL,
        index: inout [String: URL]
    ) -> [SidebarNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
        let childURLs = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        let sorted = childURLs.sorted { lhs, rhs in
            let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if lhsIsDirectory != rhsIsDirectory {
                return lhsIsDirectory && !rhsIsDirectory
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        return sorted.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            if values?.isHidden == true || url.lastPathComponent.hasPrefix(".") {
                return nil
            }

            let isDirectory = values?.isDirectory ?? false
            let identifier = relativeIdentifier(for: url, rootURL: rootURL, isDirectory: isDirectory)
            index[identifier] = url

            if isDirectory {
                let children = makeNodes(in: url, rootURL: rootURL, index: &index)
                return SidebarNode(
                    id: identifier,
                    displayName: url.lastPathComponent + "/",
                    isDirectory: true,
                    children: children.isEmpty ? nil : children
                )
            }

            return SidebarNode(
                id: identifier,
                displayName: url.lastPathComponent,
                isDirectory: false,
                children: nil
            )
        }
    }

    private func relativeIdentifier(for url: URL, rootURL: URL, isDirectory: Bool) -> String {
        let rootPath = rootURL.path
        let fullPath = url.path
        var relative = fullPath
        if fullPath.hasPrefix(rootPath + "/") {
            relative = String(fullPath.dropFirst(rootPath.count + 1))
        }
        return isDirectory ? relative + "/" : relative
    }

    private func firstFileID(in nodes: [SidebarNode]) -> String? {
        for node in nodes {
            if node.isDirectory {
                if let childID = firstFileID(in: node.children ?? []) {
                    return childID
                }
                continue
            }
            return node.id
        }
        return nil
    }

    private func updateEditorForSelection() {
        guard let selectedPath else {
            editorText = ""
            return
        }

        guard let fileURL = workspaceURLsByID[selectedPath] else {
            editorText = ""
            return
        }

        if fileURL.hasDirectoryPath {
            editorText = """
            // \(selectedPath)
            // Folder selected.
            """
            return
        }

        do {
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            guard data.count <= 1_000_000 else {
                editorText = "// File too large to preview (>1MB)."
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                editorText = text
            } else {
                editorText = """
                // \(selectedPath)
                // Binary or unsupported text encoding.
                """
            }
        } catch {
            editorText = """
            // \(selectedPath)
            // Failed to load file: \(error.localizedDescription)
            """
        }
    }

    private func expandAncestors(of id: String) {
        let trimmed = id.hasSuffix("/") ? String(id.dropLast()) : id
        let parts = trimmed.split(separator: "/")
        guard parts.count > 1 else { return }

        var current = ""
        for part in parts.dropLast() {
            current += part + "/"
            expandedDirectoryIDs.insert(current)
        }
    }
}
