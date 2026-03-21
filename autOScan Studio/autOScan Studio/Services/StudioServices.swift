import AppKit
import Foundation

struct PolicyFile: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
}

struct PolicyDraft: Equatable {
    static let defaultCompiler = "gcc"

    struct TestCase: Identifiable, Equatable {
        let id: UUID
        var name: String
        var args: [String]
        var input: String
        var expectedExit: String
        var expectedOutputFile: String

        var singleArgument: String {
            args.first ?? ""
        }

        init(
            id: UUID = UUID(),
            name: String = "",
            args: [String] = [],
            input: String = "",
            expectedExit: String = "",
            expectedOutputFile: String = ""
        ) {
            self.id = id
            self.name = name
            self.args = args
            self.input = input
            self.expectedExit = expectedExit
            self.expectedOutputFile = expectedOutputFile
        }
    }

    var name: String
    var gcc: String
    var flags: [String]
    var sourceFile: String
    var libraryFiles: [String]
    var testFiles: [String]
    var testCases: [TestCase]

    init(
        name: String = "",
        gcc: String = "gcc",
        flags: [String] = [],
        sourceFile: String = "",
        libraryFiles: [String] = [],
        testFiles: [String] = [],
        testCases: [TestCase] = []
    ) {
        self.name = name
        self.gcc = gcc
        self.flags = flags
        self.sourceFile = sourceFile
        self.libraryFiles = libraryFiles
        self.testFiles = testFiles
        self.testCases = testCases
    }

    static func starter(named name: String) -> PolicyDraft {
        PolicyDraft(
            name: name,
            gcc: defaultCompiler,
            flags: ["-Wall", "-Wextra"],
            sourceFile: "main.c",
            testCases: [
                TestCase(
                    name: "No args",
                    expectedExit: "0"
                )
            ]
        )
    }

    static func parse(_ text: String) -> PolicyDraft {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var draft = PolicyDraft()
        var index = 0

        func currentIndent(for line: String) -> Int {
            line.prefix { $0 == " " }.count
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = currentIndent(for: line)
            guard indent == 0 else {
                index += 1
                continue
            }

            if trimmed.hasPrefix("name:") {
                draft.name = parseYAMLScalar(String(trimmed.dropFirst("name:".count)).trimmingCharacters(in: .whitespaces))
                index += 1
                continue
            }

            if trimmed == "compile:" {
                index += 1
                parseCompileSection(lines: lines, index: &index, into: &draft)
                continue
            }

            if trimmed == "run:" {
                index += 1
                parseRunSection(lines: lines, index: &index, into: &draft)
                continue
            }

            if trimmed == "library_files:" {
                index += 1
                draft.libraryFiles = parseScalarList(lines: lines, index: &index, minimumIndent: 2)
                continue
            }

            if trimmed == "test_files:" {
                index += 1
                draft.testFiles = parseScalarList(lines: lines, index: &index, minimumIndent: 2)
                continue
            }

            index += 1
        }

        if draft.testCases.isEmpty {
            draft.testCases = [PolicyDraft.TestCase(name: "No args", expectedExit: "0")]
        }

        return draft
    }

    func serializedYAML() -> String {
        var lines: [String] = []
        lines.append("name: \(yamlScalar(name))")
        lines.append("compile:")
        lines.append("  gcc: \(yamlScalar(Self.defaultCompiler))")
        lines.append("  flags:")
        if flags.isEmpty {
            lines.append("    - \(yamlScalar("-Wall"))")
            lines.append("    - \(yamlScalar("-Wextra"))")
        } else {
            for flag in flags {
                lines.append("    - \(yamlScalar(flag))")
            }
        }
        lines.append("  source_file: \(yamlScalar(sourceFile))")
        lines.append("run:")
        lines.append("  test_cases:")
        if testCases.isEmpty {
            lines.append("    - name: \(yamlScalar("No args"))")
            lines.append("      expected_exit: 0")
        } else {
            for testCase in testCases {
                lines.append("    - name: \(yamlScalar(testCase.name))")

                if !testCase.args.isEmpty {
                    lines.append("      args: \(yamlArray(testCase.args))")
                }

                if !testCase.input.isEmpty {
                    lines.append("      input: \(yamlScalar(testCase.input))")
                }

                if !testCase.expectedExit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("      expected_exit: \(testCase.expectedExit.trimmingCharacters(in: .whitespacesAndNewlines))")
                }

                if !testCase.expectedOutputFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("      expected_output_file: \(yamlScalar(testCase.expectedOutputFile))")
                }
            }
        }

        if !libraryFiles.isEmpty {
            lines.append("library_files:")
            for file in libraryFiles {
                lines.append("  - \(yamlScalar(file))")
            }
        }

        if !testFiles.isEmpty {
            lines.append("test_files:")
            for file in testFiles {
                lines.append("  - \(yamlScalar(file))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func parseCompileSection(lines: [String], index: inout Int, into draft: inout PolicyDraft) {
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            if indent == 0 {
                break
            }

            if indent == 2, trimmed.hasPrefix("gcc:") {
                draft.gcc = parseYAMLScalar(String(trimmed.dropFirst("gcc:".count)).trimmingCharacters(in: .whitespaces))
                index += 1
                continue
            }

            if indent == 2, trimmed.hasPrefix("source_file:") {
                draft.sourceFile = parseYAMLScalar(String(trimmed.dropFirst("source_file:".count)).trimmingCharacters(in: .whitespaces))
                index += 1
                continue
            }

            if indent == 2, trimmed == "flags:" {
                index += 1
                draft.flags = parseScalarList(lines: lines, index: &index, minimumIndent: 4)
                continue
            }

            index += 1
        }
    }

    private static func parseRunSection(lines: [String], index: inout Int, into draft: inout PolicyDraft) {
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            if indent == 0 {
                break
            }

            if indent == 2, trimmed == "test_cases:" {
                index += 1
                draft.testCases = parseTestCases(lines: lines, index: &index, minimumIndent: 4)
                continue
            }

            index += 1
        }
    }

    private static func parseScalarList(lines: [String], index: inout Int, minimumIndent: Int) -> [String] {
        var values: [String] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            if indent < minimumIndent {
                break
            }

            if trimmed.hasPrefix("- ") {
                values.append(parseYAMLScalar(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            }

            index += 1
        }

        return values
    }

    private static func parseTestCases(lines: [String], index: inout Int, minimumIndent: Int) -> [PolicyDraft.TestCase] {
        var testCases: [PolicyDraft.TestCase] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            if indent < minimumIndent {
                break
            }

            guard indent == minimumIndent, trimmed.hasPrefix("- ") else {
                index += 1
                continue
            }

            var testCase = PolicyDraft.TestCase()
            let firstEntry = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if firstEntry.hasPrefix("name:") {
                testCase.name = parseYAMLScalar(String(firstEntry.dropFirst("name:".count)).trimmingCharacters(in: .whitespaces))
            }

            index += 1

            while index < lines.count {
                let nestedLine = lines[index]
                let nestedTrimmed = nestedLine.trimmingCharacters(in: .whitespaces)

                if nestedTrimmed.isEmpty || nestedTrimmed.hasPrefix("#") {
                    index += 1
                    continue
                }

                let nestedIndent = nestedLine.prefix { $0 == " " }.count
                if nestedIndent <= minimumIndent {
                    break
                }

                if nestedTrimmed.hasPrefix("name:") {
                    testCase.name = parseYAMLScalar(String(nestedTrimmed.dropFirst("name:".count)).trimmingCharacters(in: .whitespaces))
                    index += 1
                    continue
                }

                if nestedTrimmed.hasPrefix("args:") {
                    let value = String(nestedTrimmed.dropFirst("args:".count)).trimmingCharacters(in: .whitespaces)
                    testCase.args = parseInlineArray(value)
                    index += 1
                    continue
                }

                if nestedTrimmed.hasPrefix("input:") {
                    let value = String(nestedTrimmed.dropFirst("input:".count)).trimmingCharacters(in: .whitespaces)
                    testCase.input = parseYAMLScalar(value)
                    index += 1
                    continue
                }

                if nestedTrimmed.hasPrefix("expected_exit:") {
                    testCase.expectedExit = String(nestedTrimmed.dropFirst("expected_exit:".count)).trimmingCharacters(in: .whitespaces)
                    index += 1
                    continue
                }

                if nestedTrimmed.hasPrefix("expected_output_file:") {
                    let value = String(nestedTrimmed.dropFirst("expected_output_file:".count)).trimmingCharacters(in: .whitespaces)
                    testCase.expectedOutputFile = parseYAMLScalar(value)
                    index += 1
                    continue
                }

                index += 1
            }

            testCases.append(testCase)
        }

        return testCases
    }

    private static func parseInlineArray(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            return trimmed.isEmpty ? [] : [parseYAMLScalar(trimmed)]
        }

        let inner = String(trimmed.dropFirst().dropLast())
        guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var values: [String] = []
        var current = ""
        var isInsideQuotes = false
        var isEscaping = false

        for character in inner {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaping = true
                continue
            }

            if character == "\"" {
                isInsideQuotes.toggle()
                current.append(character)
                continue
            }

            if character == ",", !isInsideQuotes {
                values.append(parseYAMLScalar(current.trimmingCharacters(in: .whitespaces)))
                current = ""
                continue
            }

            current.append(character)
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append(parseYAMLScalar(current.trimmingCharacters(in: .whitespaces)))
        }

        return values
    }
}

private func yamlScalar(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escaped)\""
}

private func yamlArray(_ values: [String]) -> String {
    "[" + values.map(yamlScalar).joined(separator: ", ") + "]"
}

private func parseYAMLScalar(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 else {
        return trimmed
    }

    let inner = String(trimmed.dropFirst().dropLast())
    var result = ""
    var isEscaping = false

    for character in inner {
        if isEscaping {
            switch character {
            case "n":
                result.append("\n")
            case "\"":
                result.append("\"")
            case "\\":
                result.append("\\")
            default:
                result.append(character)
            }
            isEscaping = false
            continue
        }

        if character == "\\" {
            isEscaping = true
        } else {
            result.append(character)
        }
    }

    return result
}

struct WorkspaceSnapshot {
    let rootURL: URL
    let rootNodeID: String
    let nodes: [WorkspaceNode]
    let urlByNodeID: [String: URL]
}

enum PolicyResourceKind {
    case library
    case testFile
    case expectedOutput

    var destinationFolderName: String {
        switch self {
        case .library:
            return "libraries"
        case .testFile:
            return "test_files"
        case .expectedOutput:
            return "expected_outputs"
        }
    }
}

enum WorkspaceFileLoadResult {
    case text(String)
    case tooLarge
    case unsupportedEncoding
}

@MainActor
protocol WorkspaceService {
    func chooseWorkspaceURL() -> URL?
    func chooseFileURL(prompt: String, message: String, directoryURL: URL?) -> URL?
    func loadWorkspace(at rootURL: URL) throws -> WorkspaceSnapshot
    func readFile(at fileURL: URL) throws -> WorkspaceFileLoadResult
    func listPolicies(in rootURL: URL) throws -> [PolicyFile]
    func readPolicy(_ policy: PolicyFile) throws -> String
    func createPolicy(named name: String, content: String, in rootURL: URL) throws -> PolicyFile
    func renamePolicy(_ policy: PolicyFile, to name: String, content: String, in rootURL: URL) throws -> PolicyFile
    func updatePolicy(_ policy: PolicyFile, content: String) throws
    func deletePolicy(_ policy: PolicyFile) throws
    func importPolicyResource(from sourceURL: URL, kind: PolicyResourceKind, in rootURL: URL) throws -> String
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

    func chooseFileURL(prompt: String, message: String, directoryURL: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = prompt
        panel.message = message
        panel.directoryURL = directoryURL

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
        let fileURL = uniquePolicyFileURL(baseName: safeBaseName, pathExtension: "yaml", in: policiesDirectory)
        guard let data = content.data(using: .utf8, allowLossyConversion: false) else {
            throw NSError(domain: "autOScanStudio.WorkspaceService", code: 1)
        }
        try data.write(to: fileURL, options: .atomic)

        let relativePath = relativeID(for: fileURL, rootURL: rootURL, isDirectory: false)
        return PolicyFile(id: relativePath, name: fileURL.lastPathComponent, url: fileURL)
    }

    func renamePolicy(_ policy: PolicyFile, to name: String, content: String, in rootURL: URL) throws -> PolicyFile {
        let policiesDirectory = policy.url.deletingLastPathComponent()
        let safeBaseName = sanitizedPolicyName(name)
        let pathExtension = policy.url.pathExtension.nonEmpty ?? "yaml"
        let destinationURL = uniquePolicyFileURL(
            baseName: safeBaseName,
            pathExtension: pathExtension,
            in: policiesDirectory,
            excluding: policy.url
        )

        if destinationURL.standardizedFileURL != policy.url.standardizedFileURL {
            try FileManager.default.moveItem(at: policy.url, to: destinationURL)
        }

        guard let data = content.data(using: .utf8, allowLossyConversion: false) else {
            throw NSError(domain: "autOScanStudio.WorkspaceService", code: 6)
        }
        try data.write(to: destinationURL, options: .atomic)

        let relativePath = relativeID(for: destinationURL, rootURL: rootURL, isDirectory: false)
        return PolicyFile(id: relativePath, name: destinationURL.lastPathComponent, url: destinationURL)
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

    func importPolicyResource(from sourceURL: URL, kind: PolicyResourceKind, in rootURL: URL) throws -> String {
        let destinationDirectoryURL = try policyResourceDirectoryURL(for: kind, in: rootURL)
        let standardizedSourceDirectoryURL = sourceURL.deletingLastPathComponent().standardizedFileURL
        if standardizedSourceDirectoryURL == destinationDirectoryURL.standardizedFileURL {
            return sourceURL.lastPathComponent
        }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationFileURL = uniqueImportedResourceURL(
            fileName: sourceURL.lastPathComponent,
            in: destinationDirectoryURL
        )
        try FileManager.default.copyItem(at: sourceURL, to: destinationFileURL)
        return destinationFileURL.lastPathComponent
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

    private func uniquePolicyFileURL(
        baseName: String,
        pathExtension: String,
        in directoryURL: URL,
        excluding excludedURL: URL? = nil
    ) -> URL {
        var candidateName = baseName
        var suffix = 1

        while true {
            let candidateURL = directoryURL.appendingPathComponent(candidateName).appendingPathExtension(pathExtension)
            if candidateURL.standardizedFileURL == excludedURL?.standardizedFileURL || !FileManager.default.fileExists(atPath: candidateURL.path) {
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

    private func policyResourceDirectoryURL(for kind: PolicyResourceKind, in rootURL: URL) throws -> URL {
        let autoscanDirectoryURL = rootURL.appendingPathComponent(".autoscan", isDirectory: true)
        if !FileManager.default.fileExists(atPath: autoscanDirectoryURL.path) {
            try FileManager.default.createDirectory(at: autoscanDirectoryURL, withIntermediateDirectories: true)
        }

        let directoryURL = autoscanDirectoryURL.appendingPathComponent(kind.destinationFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }

    private func uniqueImportedResourceURL(fileName: String, in directoryURL: URL) -> URL {
        let sourceURL = URL(fileURLWithPath: fileName)
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.nonEmpty ?? "file"
        var candidateBaseName = baseName
        var suffix = 1

        while true {
            var candidateURL = directoryURL.appendingPathComponent(candidateBaseName, isDirectory: false)
            if !ext.isEmpty {
                candidateURL.appendPathExtension(ext)
            }

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
            candidateBaseName = "\(baseName)-\(suffix)"
        }
    }
}

enum EngineClientError: Error {
    case notImplemented(String)
    case bridgeNotFound
    case missingPolicyPath
    case invalidResponse(String)
    case bridgeFailed(String)
    case launchFailed(String)
}

extension EngineClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented(let operation):
            return "\(operation) isn't implemented yet."
        case .bridgeNotFound:
            return "autOScan bridge wasn't found. Rebuild Studio so it bundles autoscan-bridge, or set AUTOSCAN_BRIDGE_PATH."
        case .missingPolicyPath:
            return "A policy file is required before running the engine."
        case .invalidResponse(let message):
            return "The engine bridge returned an invalid response: \(message)"
        case .bridgeFailed(let message):
            return message
        case .launchFailed(let message):
            return "Couldn't launch the engine bridge: \(message)"
        }
    }
}

struct RunSessionRequest: Sendable {
    let workspacePath: String
    let policyPath: String?
    var configDirectoryPath: String? = nil
    var outputDirectoryPath: String? = nil
    var workerCount: Int? = nil
    var shortNames = false
}

struct RunSubmissionRequest: Sendable {
    let submissionPath: String
    let policyPath: String?
    var configDirectoryPath: String? = nil
    var outputDirectoryPath: String? = nil
    var workerCount: Int? = nil
    var shortNames = false
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

struct EngineRunSummary: Sendable, Decodable {
    let policyName: String
    let root: String
    let startedAt: String
    let finishedAt: String
    let durationMs: Int64
    let totalSubmissions: Int
    let compilePass: Int
    let compileFail: Int
    let compileTimeout: Int
    let cleanSubmissions: Int
    let submissionsWithBanned: Int
    let bannedHitsTotal: Int
    let topBannedFunctions: [String: Int]
}

struct EngineRunSubmission: Sendable, Decodable, Identifiable {
    let id: String
    let path: String
    let status: String
    let cFiles: [String]
    let compileOK: Bool
    let compileTimeout: Bool
    let exitCode: Int
    let compileTimeMs: Int64
    let stderr: String?
    let bannedCount: Int
}

struct EngineRunReport: Sendable, Decodable {
    let summary: EngineRunSummary
    let submissions: [EngineRunSubmission]
}

struct EngineDiscovery: Sendable, Decodable {
    let submissionCount: Int
}

struct EngineCompileEvent: Sendable, Decodable {
    let submissionID: String
    let ok: Bool
    let exitCode: Int
    let timedOut: Bool
    let durationMs: Int64
    let stdout: String?
    let stderr: String?
}

struct EngineScanEvent: Sendable, Decodable {
    let submissionID: String
    let bannedHits: Int
    let parseErrors: [String]
}

enum EngineRunEvent: Sendable {
    case started(String)
    case discoveryComplete(EngineDiscovery)
    case compileComplete(EngineCompileEvent)
    case scanComplete(EngineScanEvent)
    case runComplete(EngineRunReport)
    case error(String)
}

protocol EngineClient {
    func runSession(
        request: RunSessionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport
    func runSubmission(
        request: RunSubmissionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport
    func computeSimilarity(request: ComputeSimilarityRequest) async throws -> EngineCommandResponse
    func computeAIDetection(request: ComputeAIDetectionRequest) async throws -> EngineCommandResponse
    func exportReport(request: ExportReportRequest) async throws -> EngineCommandResponse
}

final class PlaceholderEngineClient: EngineClient {
    func runSession(
        request: RunSessionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport {
        throw EngineClientError.notImplemented("runSession")
    }

    func runSubmission(
        request: RunSubmissionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport {
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

final class BridgeEngineClient: EngineClient {
    private struct BridgeEnvelope: Decodable {
        let type: String
        let message: String?
        let discovery: EngineDiscovery?
        let compile: EngineCompileEvent?
        let scan: EngineScanEvent?
        let run: EngineRunReport?
    }

    func runSession(
        request: RunSessionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport {
        try await runBridgeCommand(
            command: "run-session",
            rootPath: request.workspacePath,
            policyPath: request.policyPath,
            configDirectoryPath: request.configDirectoryPath,
            outputDirectoryPath: request.outputDirectoryPath,
            workerCount: request.workerCount,
            shortNames: request.shortNames,
            onEvent: onEvent
        )
    }

    func runSubmission(
        request: RunSubmissionRequest,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport {
        try await runBridgeCommand(
            command: "run-submission",
            rootPath: request.submissionPath,
            policyPath: request.policyPath,
            configDirectoryPath: request.configDirectoryPath,
            outputDirectoryPath: request.outputDirectoryPath,
            workerCount: request.workerCount,
            shortNames: request.shortNames,
            onEvent: onEvent
        )
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

    private func runBridgeCommand(
        command: String,
        rootPath: String,
        policyPath: String?,
        configDirectoryPath: String?,
        outputDirectoryPath: String?,
        workerCount: Int?,
        shortNames: Bool,
        onEvent: @escaping @Sendable (EngineRunEvent) async -> Void
    ) async throws -> EngineRunReport {
        guard let policyPath else {
            throw EngineClientError.missingPolicyPath
        }

        let bridgeURL = try resolveBridgeExecutableURL()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let process = Process()
        process.executableURL = bridgeURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var arguments = [command, "--workspace", rootPath, "--policy", policyPath]
        if let configDirectoryPath, !configDirectoryPath.isEmpty {
            arguments.append(contentsOf: ["--config-dir", configDirectoryPath])
        }
        if let outputDirectoryPath, !outputDirectoryPath.isEmpty {
            arguments.append(contentsOf: ["--output-dir", outputDirectoryPath])
        }
        if let workerCount, workerCount > 0 {
            arguments.append(contentsOf: ["--workers", String(workerCount)])
        }
        if shortNames {
            arguments.append("--short-names")
        }
        process.arguments = arguments

        let decoder = JSONDecoder()
        let stdoutTask = Task { () throws -> EngineRunReport? in
            var finalReport: EngineRunReport?

            for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    continue
                }

                let envelope = try decoder.decode(BridgeEnvelope.self, from: Data(trimmed.utf8))
                let event = try map(envelope)
                await onEvent(event)

                if case .runComplete(let report) = event {
                    finalReport = report
                }
            }

            return finalReport
        }

        let stderrTask = Task { () async -> String in
            var lines: [String] = []
            do {
                for try await line in stderrPipe.fileHandleForReading.bytes.lines {
                    lines.append(line)
                }
            } catch {
                if let message = (error as NSError).localizedDescription.nonEmpty {
                    lines.append(message)
                }
            }
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let exitCodeTask = Task { () async throws -> Int32 in
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { terminatedProcess in
                    continuation.resume(returning: terminatedProcess.terminationStatus)
                }

                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }

        let exitCode: Int32
        do {
            exitCode = try await exitCodeTask.value
        } catch {
            stdoutTask.cancel()
            stderrTask.cancel()
            throw EngineClientError.launchFailed(error.localizedDescription)
        }

        let stderrOutput = await stderrTask.value
        let finalReport = try await stdoutTask.value

        if exitCode != 0 {
            let failureMessage = stderrOutput.nonEmpty
                ?? "The engine bridge exited with status \(exitCode)."
            throw EngineClientError.bridgeFailed(failureMessage)
        }

        guard let finalReport else {
            throw EngineClientError.invalidResponse("missing final run report")
        }

        return finalReport
    }

    private func map(_ envelope: BridgeEnvelope) throws -> EngineRunEvent {
        switch envelope.type {
        case "started":
            return .started(envelope.message ?? "Run started.")
        case "discovery_complete":
            guard let discovery = envelope.discovery else {
                throw EngineClientError.invalidResponse("discovery payload missing")
            }
            return .discoveryComplete(discovery)
        case "compile_complete":
            guard let compile = envelope.compile else {
                throw EngineClientError.invalidResponse("compile payload missing")
            }
            return .compileComplete(compile)
        case "scan_complete":
            guard let scan = envelope.scan else {
                throw EngineClientError.invalidResponse("scan payload missing")
            }
            return .scanComplete(scan)
        case "run_complete":
            guard let run = envelope.run else {
                throw EngineClientError.invalidResponse("run payload missing")
            }
            return .runComplete(run)
        case "error":
            return .error(envelope.message ?? "Unknown engine error.")
        default:
            throw EngineClientError.invalidResponse("unknown event type \(envelope.type)")
        }
    }

    private func resolveBridgeExecutableURL() throws -> URL {
        let fileManager = FileManager.default

        let environment = ProcessInfo.processInfo.environment
        if let overridePath = environment["AUTOSCAN_BRIDGE_PATH"],
           fileManager.isExecutableFile(atPath: overridePath) {
            return URL(fileURLWithPath: overridePath)
        }

        if let bundledURL = Bundle.main.url(forAuxiliaryExecutable: "autoscan-bridge"),
           fileManager.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        if let executableDirectoryURL = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundledExecutableURL = executableDirectoryURL.appendingPathComponent("autoscan-bridge")
            if fileManager.isExecutableFile(atPath: bundledExecutableURL.path) {
                return bundledExecutableURL
            }
        }

        if let pathEnvironment = environment["PATH"] {
            for directory in pathEnvironment.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(directory))
                    .appendingPathComponent("autoscan-bridge")
                if fileManager.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        for candidate in developmentBridgeCandidates() where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw EngineClientError.bridgeNotFound
    }

    private func developmentBridgeCandidates() -> [URL] {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let workspaceRoot = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return [
            workspaceRoot.appendingPathComponent("autOScan-engine/dist/autoscan-bridge"),
            workspaceRoot.appendingPathComponent("autOScan-engine/autoscan-bridge"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("../autOScan-engine/dist/autoscan-bridge")
                .standardizedFileURL
        ]
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

struct RemoteSSHHost: Sendable, Hashable {
    let alias: String
    let host: String
}

struct RemoteEnvironmentSnapshot: Sendable {
    let hasSSHAccess: Bool
    let isConfigured: Bool
    let detectedUsername: String?
    let message: String?
}

enum RemoteInstallerPrompt: Sendable, Equatable {
    case secure(String)
    case plain(String)
}

enum RemoteInstallerEvent: Sendable {
    case output(String)
    case inputRequested(RemoteInstallerPrompt)
    case finished(success: Bool, message: String?)
}

enum RemoteAccessError: Error {
    case setupCancelled
    case sshFolderAccessRequired
    case invalidUsername
    case keyGenerationFailed(String)
    case sshConfigUpdateFailed(String)
    case vpnRequired
    case publicKeyInstallRequired
    case connectionFailed(String)
}

extension RemoteAccessError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .setupCancelled:
            return "SSH setup was cancelled."
        case .sshFolderAccessRequired:
            return "Studio needs one-time access to `~/.ssh` before it can finish the Salle setup."
        case .invalidUsername:
            return "Enter your `name.lastname` Salle username first."
        case .keyGenerationFailed(let message):
            return "Couldn't create the local SSH key: \(message)"
        case .sshConfigUpdateFailed(let message):
            return "Couldn't update the SSH config: \(message)"
        case .vpnRequired:
            return "Connect to La Salle VPN or campus Wi-Fi first."
        case .publicKeyInstallRequired:
            return "Key-based login is not ready yet. Install your public key on the selected server first."
        case .connectionFailed(let message):
            return message
        }
    }
}

@MainActor
protocol RemoteAccessService {
    func inspectEnvironment(hosts: [RemoteSSHHost]) async -> RemoteEnvironmentSnapshot
    func performSetup(
        username: String,
        hosts: [RemoteSSHHost],
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> RemoteEnvironmentSnapshot
    func connect(to host: RemoteSSHHost) async throws
    func disconnect(from host: RemoteSSHHost) async
    func startPublicKeyInstall(
        to host: RemoteSSHHost,
        onEvent: @escaping @Sendable (RemoteInstallerEvent) async -> Void
    ) async throws
    func sendInstallerInput(_ input: String) async
    func cancelPublicKeyInstall() async
}

@MainActor
final class LocalRemoteAccessService: RemoteAccessService {
    private let defaults = UserDefaults.standard
    private var activeSecurityScopedSSHBaseURL: URL?
    private var installerProcess: Process?
    private var installerInputHandle: FileHandle?
    private var installerEventHandler: (@Sendable (RemoteInstallerEvent) async -> Void)?

    deinit {
        activeSecurityScopedSSHBaseURL?.stopAccessingSecurityScopedResource()
    }

    func inspectEnvironment(hosts: [RemoteSSHHost]) async -> RemoteEnvironmentSnapshot {
        guard let sshDirectoryURL = restoreSSHDirectoryIfPossible() else {
            return RemoteEnvironmentSnapshot(
                hasSSHAccess: false,
                isConfigured: false,
                detectedUsername: nil,
                message: "Grant Studio access to your `.ssh` folder to reuse or create the Salle aliases."
            )
        }

        let resolution = await inspectHostResolution(hosts: hosts, sshDirectoryURL: sshDirectoryURL)
        if resolution.allHostsMatch {
            return RemoteEnvironmentSnapshot(
                hasSSHAccess: true,
                isConfigured: true,
                detectedUsername: resolution.detectedUsername,
                message: "Existing Salle SSH aliases were detected on this Mac."
            )
        }

        return RemoteEnvironmentSnapshot(
            hasSSHAccess: true,
            isConfigured: false,
            detectedUsername: resolution.detectedUsername,
            message: "Studio can finish the Salle SSH setup on this Mac."
        )
    }

    func performSetup(
        username: String,
        hosts: [RemoteSSHHost],
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> RemoteEnvironmentSnapshot {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            throw RemoteAccessError.invalidUsername
        }

        let sshDirectoryURL = try ensureSSHDirectoryAccess()
        onProgress(0)

        let existingResolution = await inspectHostResolution(hosts: hosts, sshDirectoryURL: sshDirectoryURL)
        onProgress(1)

        if !existingResolution.allHostsMatch {
            let keyURL = sshDirectoryURL.appendingPathComponent("autoscan_salle_ed25519", isDirectory: false)
            try await ensureLocalKeyPair(at: keyURL, username: trimmedUsername)
            onProgress(2)

            try await ensureStudioSSHConfiguration(
                username: trimmedUsername,
                hosts: hosts,
                sshDirectoryURL: sshDirectoryURL,
                identityFileURL: keyURL
            )
        } else {
            onProgress(2)
        }

        let refreshedResolution = await inspectHostResolution(hosts: hosts, sshDirectoryURL: sshDirectoryURL)
        return RemoteEnvironmentSnapshot(
            hasSSHAccess: true,
            isConfigured: refreshedResolution.allHostsMatch,
            detectedUsername: refreshedResolution.detectedUsername ?? trimmedUsername,
            message: refreshedResolution.allHostsMatch
                ? "SSH aliases are ready. Connect to La Salle VPN or campus Wi-Fi first when opening the remote session."
                : "Studio prepared the local SSH config, but the Salle aliases are still incomplete."
        )
    }

    func connect(to host: RemoteSSHHost) async throws {
        guard let _ = restoreSSHDirectoryIfPossible() else {
            throw RemoteAccessError.sshFolderAccessRequired
        }

        let controlPathURL = try controlSocketURL(for: host.alias)
        if await isControlConnectionAlive(alias: host.alias, controlPathURL: controlPathURL) {
            return
        }

        let result = await runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: [
                "-M",
                "-N",
                "-f",
                "-S", controlPathURL.path,
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "ControlPersist=yes",
                host.alias
            ]
        )

        guard result.exitCode == 0 else {
            throw mapConnectionError(from: result.stderr.nonEmpty ?? result.stdout.nonEmpty)
        }
    }

    func disconnect(from host: RemoteSSHHost) async {
        guard let controlPathURL = try? controlSocketURL(for: host.alias) else {
            return
        }

        _ = await runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: [
                "-S", controlPathURL.path,
                "-O", "exit",
                host.alias
            ]
        )

        try? FileManager.default.removeItem(at: controlPathURL)
    }

    func startPublicKeyInstall(
        to host: RemoteSSHHost,
        onEvent: @escaping @Sendable (RemoteInstallerEvent) async -> Void
    ) async throws {
        let sshDirectoryURL = try ensureSSHDirectoryAccess()
        let publicKeyURL = sshDirectoryURL.appendingPathComponent("autoscan_salle_ed25519.pub", isDirectory: false)
        guard FileManager.default.fileExists(atPath: publicKeyURL.path) else {
            throw RemoteAccessError.keyGenerationFailed("Create the local SSH key before installing it on the server.")
        }

        await cancelPublicKeyInstall()

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = [
            "-q", "/dev/null",
            "/usr/bin/ssh-copy-id",
            "-i", publicKeyURL.path,
            host.alias
        ]
        process.environment = commandEnvironment()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        installerProcess = process
        installerInputHandle = stdinPipe.fileHandleForWriting
        installerEventHandler = onEvent

        let promptDetector = InstallerPromptDetector()

        let handleData: @Sendable (Data) -> Void = { [weak self] data in
            guard let self, !data.isEmpty else {
                return
            }

            let chunk = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if let handler = self.installerEventHandler {
                    await handler(.output(chunk))
                    if let prompt = promptDetector.prompt(in: chunk) {
                        await handler(.inputRequested(prompt))
                    }
                }
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            handleData(fileHandle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            handleData(fileHandle.availableData)
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let exitCode = terminatedProcess.terminationStatus
                let message: String?
                if exitCode == 0 {
                    message = "Public key installed successfully."
                } else {
                    message = "The key install exited with status \(exitCode)."
                }

                if let handler = self.installerEventHandler {
                    await handler(.finished(success: exitCode == 0, message: message))
                }

                self.finishInstallerSession()
            }
        }

        do {
            try process.run()
        } catch {
            finishInstallerSession()
            throw RemoteAccessError.connectionFailed("Couldn't start the key installer: \(error.localizedDescription)")
        }
    }

    func sendInstallerInput(_ input: String) async {
        guard let installerInputHandle else {
            return
        }

        do {
            let payload = input.hasSuffix("\n") ? input : input + "\n"
            try installerInputHandle.write(contentsOf: Data(payload.utf8))
        } catch {
            // Ignore write failures; termination will surface through the session.
        }
    }

    func cancelPublicKeyInstall() async {
        installerProcess?.terminate()
        finishInstallerSession()
    }

    private func ensureSSHDirectoryAccess() throws -> URL {
        if let resolvedURL = restoreSSHDirectoryIfPossible() {
            return resolvedURL
        }

        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let defaultSSHDirectoryURL = homeURL.appendingPathComponent(".ssh", isDirectory: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = "Grant Access"
        panel.directoryURL = defaultSSHDirectoryURL
        panel.message = "Grant access to your `~/.ssh` folder so Studio can reuse your SSH setup. If `.ssh` doesn't exist yet, grant access to your home folder and Studio will create it."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            throw RemoteAccessError.setupCancelled
        }

        beginAccessingSSHBaseURL(selectedURL)
        try persistSSHBookmark(for: selectedURL)

        let sshDirectoryURL = normalizeSSHDirectoryURL(from: selectedURL)
        if !FileManager.default.fileExists(atPath: sshDirectoryURL.path) {
            try FileManager.default.createDirectory(at: sshDirectoryURL, withIntermediateDirectories: true)
        }

        return sshDirectoryURL
    }

    private func restoreSSHDirectoryIfPossible() -> URL? {
        guard let bookmarkData = defaults.data(forKey: RemoteAccessPersistedKey.sshBookmarkData) else {
            return nil
        }

        do {
            var isStale = false
            let baseURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            beginAccessingSSHBaseURL(baseURL)
            if isStale {
                try persistSSHBookmark(for: baseURL)
            }
            return normalizeSSHDirectoryURL(from: baseURL)
        } catch {
            defaults.removeObject(forKey: RemoteAccessPersistedKey.sshBookmarkData)
            return nil
        }
    }

    private func beginAccessingSSHBaseURL(_ url: URL) {
        if activeSecurityScopedSSHBaseURL?.standardizedFileURL == url.standardizedFileURL {
            return
        }

        activeSecurityScopedSSHBaseURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedSSHBaseURL = nil

        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        activeSecurityScopedSSHBaseURL = url
    }

    private func persistSSHBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmarkData, forKey: RemoteAccessPersistedKey.sshBookmarkData)
    }

    private func normalizeSSHDirectoryURL(from baseURL: URL) -> URL {
        if baseURL.lastPathComponent == ".ssh" {
            return baseURL
        }
        return baseURL.appendingPathComponent(".ssh", isDirectory: true)
    }

    private func ensureLocalKeyPair(at keyURL: URL, username: String) async throws {
        let publicKeyURL = keyURL.appendingPathExtension("pub")
        if FileManager.default.fileExists(atPath: keyURL.path),
           FileManager.default.fileExists(atPath: publicKeyURL.path) {
            return
        }

        let result = await runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh-keygen"),
            arguments: [
                "-t", "ed25519",
                "-f", keyURL.path,
                "-N", "",
                "-C", "\(username)@salle.url.edu"
            ]
        )

        guard result.exitCode == 0 else {
            throw RemoteAccessError.keyGenerationFailed(result.stderr.nonEmpty ?? "ssh-keygen exited with status \(result.exitCode).")
        }
    }

    private func ensureStudioSSHConfiguration(
        username: String,
        hosts: [RemoteSSHHost],
        sshDirectoryURL: URL,
        identityFileURL: URL
    ) async throws {
        let includeFileURL = sshDirectoryURL.appendingPathComponent("autoscan_studio_hosts", isDirectory: false)
        let configURL = sshDirectoryURL.appendingPathComponent("config", isDirectory: false)
        let includeLine = "Include ~/.ssh/autoscan_studio_hosts"
        let renderedHosts = hosts.map { host in
            """
            Host \(host.alias)
              HostName \(host.host)
              User \(username)
              IdentityFile \(identityFileURL.path)
              IdentitiesOnly yes
            """
        }
        .joined(separator: "\n\n")
            + "\n"

        do {
            try renderedHosts.write(to: includeFileURL, atomically: true, encoding: .utf8)

            var configText = ""
            if FileManager.default.fileExists(atPath: configURL.path) {
                configText = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            }

            if !configText.contains(includeLine) {
                if !configText.isEmpty, !configText.hasSuffix("\n") {
                    configText.append("\n")
                }
                configText.append(includeLine + "\n")
                try configText.write(to: configURL, atomically: true, encoding: .utf8)
            }
        } catch {
            throw RemoteAccessError.sshConfigUpdateFailed(error.localizedDescription)
        }
    }

    private func inspectHostResolution(
        hosts: [RemoteSSHHost],
        sshDirectoryURL: URL
    ) async -> SSHResolutionSummary {
        var allHostsMatch = true
        var detectedUsername: String?

        for host in hosts {
            let result = await runCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
                arguments: ["-G", host.alias]
            )

            guard result.exitCode == 0,
                  let stdout = result.stdout.nonEmpty,
                  let parsedHostName = sshConfigValue(named: "hostname", in: stdout),
                  parsedHostName == host.host else {
                allHostsMatch = false
                continue
            }

            if detectedUsername == nil {
                detectedUsername = sshConfigValue(named: "user", in: stdout)
            }

            let identityValues = sshConfigValues(named: "identityfile", in: stdout)
            if identityValues.isEmpty {
                let fallbackKeyURL = sshDirectoryURL.appendingPathComponent("autoscan_salle_ed25519", isDirectory: false)
                if !FileManager.default.fileExists(atPath: fallbackKeyURL.path) {
                    allHostsMatch = false
                }
            }
        }

        return SSHResolutionSummary(
            allHostsMatch: allHostsMatch,
            detectedUsername: detectedUsername
        )
    }

    private func sshConfigValue(named key: String, in output: String) -> String? {
        sshConfigValues(named: key, in: output).first
    }

    private func sshConfigValues(named key: String, in output: String) -> [String] {
        var values: [String] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix(key + " ") else {
                continue
            }
            values.append(
                String(trimmed.dropFirst(key.count + 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return values
    }

    private func mapConnectionError(from stderr: String?) -> RemoteAccessError {
        let message = stderr?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if message.contains("operation timed out")
            || message.contains("connection timed out")
            || message.contains("no route to host")
            || message.contains("network is unreachable")
            || message.contains("could not resolve hostname")
            || message.contains("connection refused") {
            return .vpnRequired
        }

        if message.contains("permission denied")
            || message.contains("publickey") {
            return .publicKeyInstallRequired
        }

        return .connectionFailed(stderr?.nonEmpty ?? "Couldn't open the SSH session.")
    }

    private func controlSocketURL(for alias: String) throws -> URL {
        guard restoreSSHDirectoryIfPossible() != nil else {
            throw RemoteAccessError.sshFolderAccessRequired
        }

        let sanitizedAlias = alias
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]"#, with: "-", options: .regularExpression)
        let shortAlias = String(sanitizedAlias.prefix(3))
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("\(shortAlias).sock", isDirectory: false)
    }

    private func isControlConnectionAlive(alias: String, controlPathURL: URL) async -> Bool {
        let result = await runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: [
                "-S", controlPathURL.path,
                "-O", "check",
                alias
            ]
        )
        return result.exitCode == 0
    }

    private func runCommand(
        executableURL: URL,
        arguments: [String]
    ) async -> ProcessExecutionResult {
        let environment = commandEnvironment()
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = environment

            do {
                try process.run()
            } catch {
                return ProcessExecutionResult(
                    exitCode: 1,
                    stdout: "",
                    stderr: error.localizedDescription
                )
            }

            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            return ProcessExecutionResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }.value
    }

    private func commandEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        return environment
    }

    private func finishInstallerSession() {
        installerProcess?.terminationHandler = nil
        installerProcess = nil
        installerInputHandle = nil
        installerEventHandler = nil
    }
}

private struct SSHResolutionSummary {
    let allHostsMatch: Bool
    let detectedUsername: String?
}

private struct ProcessExecutionResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private enum RemoteAccessPersistedKey {
    static let sshBookmarkData = "studio.remote.sshBookmarkData"
}

private struct InstallerPromptDetector: Sendable {
    func prompt(in chunk: String) -> RemoteInstallerPrompt? {
        let lowered = chunk.lowercased()

        if lowered.contains("continue connecting")
            || lowered.contains("(yes/no")
            || lowered.contains("[yes/no]") {
            return .plain("Type yes to trust this host.")
        }

        if lowered.contains("password:")
            || lowered.contains("password for ") {
            return .secure("Enter your La Salle password.")
        }

        return nil
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
