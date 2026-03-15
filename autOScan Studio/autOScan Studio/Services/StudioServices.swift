import AppKit
import Foundation

struct PolicyFile: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
}

struct WorkspaceSnapshot {
    let rootURL: URL
    let rootNodeID: String
    let nodes: [WorkspaceNode]
    let urlByNodeID: [String: URL]
}

enum WorkspaceFileLoadResult {
    case text(String)
    case tooLarge
    case unsupportedEncoding
}

@MainActor
protocol WorkspaceService {
    func chooseWorkspaceURL() -> URL?
    func loadWorkspace(at rootURL: URL) throws -> WorkspaceSnapshot
    func readFile(at fileURL: URL) throws -> WorkspaceFileLoadResult
    func listPolicies(in rootURL: URL) throws -> [PolicyFile]
    func readPolicy(_ policy: PolicyFile) throws -> String
    func createPolicy(named name: String, content: String, in rootURL: URL) throws -> PolicyFile
    func updatePolicy(_ policy: PolicyFile, content: String) throws
    func deletePolicy(_ policy: PolicyFile) throws
}

@MainActor
final class LocalWorkspaceService: WorkspaceService {
    private static let maxTextFileSize = 1_000_000

    func chooseWorkspaceURL() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open Workspace"
        panel.message = "Choose a folder to use as the workspace."

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func loadWorkspace(at rootURL: URL) throws -> WorkspaceSnapshot {
        var index: [String: URL] = [:]
        let rootNode = try makeRootNode(for: rootURL, index: &index)

        return WorkspaceSnapshot(
            rootURL: rootURL,
            rootNodeID: rootNode.id,
            nodes: [rootNode],
            urlByNodeID: index
        )
    }

    func readFile(at fileURL: URL) throws -> WorkspaceFileLoadResult {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])

        guard data.count <= Self.maxTextFileSize else {
            return .tooLarge
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .unsupportedEncoding
        }

        return .text(text)
    }

    func listPolicies(in rootURL: URL) throws -> [PolicyFile] {
        let policiesDirectory = rootURL.appendingPathComponent("policies", isDirectory: true)
        guard FileManager.default.fileExists(atPath: policiesDirectory.path) else {
            return []
        }

        let policyURLs = try FileManager.default.contentsOfDirectory(
            at: policiesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "yaml" || ext == "yml"
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        return policyURLs.map { url in
            let relativePath = relativeID(for: url, rootURL: rootURL, isDirectory: false)
            return PolicyFile(id: relativePath, name: url.lastPathComponent, url: url)
        }
    }

    func readPolicy(_ policy: PolicyFile) throws -> String {
        let data = try Data(contentsOf: policy.url, options: [.mappedIfSafe])
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createPolicy(named name: String, content: String, in rootURL: URL) throws -> PolicyFile {
        let policiesDirectory = rootURL.appendingPathComponent("policies", isDirectory: true)
        if !FileManager.default.fileExists(atPath: policiesDirectory.path) {
            try FileManager.default.createDirectory(at: policiesDirectory, withIntermediateDirectories: true)
        }

        let safeBaseName = sanitizedPolicyName(name)
        let fileURL = uniquePolicyFileURL(baseName: safeBaseName, in: policiesDirectory)
        guard let data = content.data(using: .utf8, allowLossyConversion: false) else {
            throw NSError(domain: "autOScanStudio.WorkspaceService", code: 1)
        }
        try data.write(to: fileURL, options: .atomic)

        let relativePath = relativeID(for: fileURL, rootURL: rootURL, isDirectory: false)
        return PolicyFile(id: relativePath, name: fileURL.lastPathComponent, url: fileURL)
    }

    func updatePolicy(_ policy: PolicyFile, content: String) throws {
        guard let data = content.data(using: .utf8, allowLossyConversion: false) else {
            throw NSError(domain: "autOScanStudio.WorkspaceService", code: 2)
        }
        try data.write(to: policy.url, options: .atomic)
    }

    func deletePolicy(_ policy: PolicyFile) throws {
        guard FileManager.default.fileExists(atPath: policy.url.path) else {
            return
        }
        try FileManager.default.removeItem(at: policy.url)
    }

    private func makeRootNode(for rootURL: URL, index: inout [String: URL]) throws -> WorkspaceNode {
        let rootID = rootURL.lastPathComponent + "/"
        index[rootID] = rootURL
        let children = try makeChildren(in: rootURL, rootURL: rootURL, index: &index)

        return WorkspaceNode(
            id: rootID,
            name: rootURL.lastPathComponent + "/",
            isDirectory: true,
            children: children
        )
    }

    private func makeChildren(
        in directoryURL: URL,
        rootURL: URL,
        index: inout [String: URL]
    ) throws -> [WorkspaceNode] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
        let childURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )

        let sortedChildURLs = childURLs.sorted { lhs, rhs in
            let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if lhsIsDirectory != rhsIsDirectory {
                return lhsIsDirectory && !rhsIsDirectory
            }

            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        return try sortedChildURLs.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            if values?.isHidden == true || url.lastPathComponent.hasPrefix(".") {
                return nil
            }

            let isDirectory = values?.isDirectory ?? false
            let nodeID = relativeID(for: url, rootURL: rootURL, isDirectory: isDirectory)
            index[nodeID] = url

            if isDirectory {
                let children = try makeChildren(in: url, rootURL: rootURL, index: &index)
                return WorkspaceNode(
                    id: nodeID,
                    name: url.lastPathComponent + "/",
                    isDirectory: true,
                    children: children
                )
            }

            return WorkspaceNode(
                id: nodeID,
                name: url.lastPathComponent,
                isDirectory: false,
                children: []
            )
        }
    }

    private func relativeID(for url: URL, rootURL: URL, isDirectory: Bool) -> String {
        let fullPath = url.path
        let rootPath = rootURL.path

        var relative = fullPath
        if fullPath.hasPrefix(rootPath + "/") {
            relative = String(fullPath.dropFirst(rootPath.count + 1))
        }

        if isDirectory {
            return relative + "/"
        }

        return relative
    }

    private func uniquePolicyFileURL(baseName: String, in directoryURL: URL) -> URL {
        var candidateName = baseName
        var suffix = 1

        while true {
            let candidateURL = directoryURL.appendingPathComponent(candidateName).appendingPathExtension("yaml")
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            suffix += 1
            candidateName = "\(baseName)-\(suffix)"
        }
    }

    private func sanitizedPolicyName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "policy"
        }

        let filtered = trimmed
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber || character == "-" || character == "_" {
                    return character
                }
                return "-"
            }

        let collapsed = String(filtered)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))

        return collapsed.isEmpty ? "policy" : collapsed
    }
}

enum EngineClientError: Error {
    case notImplemented(String)
}

struct RunSessionRequest: Sendable {
    let workspacePath: String
    let policyPath: String?
}

struct RunSubmissionRequest: Sendable {
    let submissionPath: String
    let policyPath: String?
}

struct ComputeSimilarityRequest: Sendable {
    let workspacePath: String
}

struct ComputeAIDetectionRequest: Sendable {
    let workspacePath: String
}

struct ExportReportRequest: Sendable {
    let outputPath: String
}

struct EngineCommandResponse: Sendable {
    let summary: String
}

@MainActor
protocol EngineClient {
    func runSession(request: RunSessionRequest) async throws -> EngineCommandResponse
    func runSubmission(request: RunSubmissionRequest) async throws -> EngineCommandResponse
    func computeSimilarity(request: ComputeSimilarityRequest) async throws -> EngineCommandResponse
    func computeAIDetection(request: ComputeAIDetectionRequest) async throws -> EngineCommandResponse
    func exportReport(request: ExportReportRequest) async throws -> EngineCommandResponse
}

@MainActor
final class PlaceholderEngineClient: EngineClient {
    func runSession(request: RunSessionRequest) async throws -> EngineCommandResponse {
        throw EngineClientError.notImplemented("runSession")
    }

    func runSubmission(request: RunSubmissionRequest) async throws -> EngineCommandResponse {
        throw EngineClientError.notImplemented("runSubmission")
    }

    func computeSimilarity(request: ComputeSimilarityRequest) async throws -> EngineCommandResponse {
        throw EngineClientError.notImplemented("computeSimilarity")
    }

    func computeAIDetection(request: ComputeAIDetectionRequest) async throws -> EngineCommandResponse {
        throw EngineClientError.notImplemented("computeAIDetection")
    }

    func exportReport(request: ExportReportRequest) async throws -> EngineCommandResponse {
        throw EngineClientError.notImplemented("exportReport")
    }
}

@MainActor
protocol TerminalService {
    var output: String { get }
    func append(_ line: String)
    func clear()
}

@MainActor
final class InMemoryTerminalService: TerminalService {
    private(set) var output = ""

    func append(_ line: String) {
        if output.isEmpty {
            output = line
            return
        }

        output += "\n" + line
    }

    func clear() {
        output = ""
    }
}

struct SSHProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var user: String
    var port: Int
    var keyLabel: String?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String,
        port: Int = 22,
        keyLabel: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.keyLabel = keyLabel
    }
}

@MainActor
protocol SSHProfileStore {
    func listProfiles() -> [SSHProfile]
    func saveProfile(_ profile: SSHProfile)
    func deleteProfile(id: UUID)
}

@MainActor
final class InMemorySSHProfileStore: SSHProfileStore {
    private var profiles: [SSHProfile] = []

    func listProfiles() -> [SSHProfile] {
        profiles.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func saveProfile(_ profile: SSHProfile) {
        if let existingIndex = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[existingIndex] = profile
            return
        }

        profiles.append(profile)
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
    }
}
