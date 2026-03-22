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
    case bridgeNotFound
    case missingPolicyPath
    case invalidResponse(String)
    case bridgeFailed(String)
    case launchFailed(String)
}

extension EngineClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .bridgeNotFound:
            return "autOScan bridge wasn't found. Rebuild Studio to bundle it (requires Go and the Engine submodule)."
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

struct EngineRunSummary: Sendable, Codable {
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

struct EngineRunSubmission: Sendable, Codable, Identifiable {
    let id: String
    let path: String
    let status: String
    let cFiles: [String]
    let compileOk: Bool
    let compileTimeout: Bool
    let exitCode: Int
    let compileTimeMs: Int64
    let stderr: String?
    let bannedCount: Int
}

struct EngineRunReport: Sendable, Codable {
    let summary: EngineRunSummary
    let submissions: [EngineRunSubmission]
}

struct EngineDiscoverySubmission: Sendable, Codable {
    let id: String
    let path: String
    let cFiles: [String]
}

struct EngineDiscovery: Sendable, Codable {
    let submissionCount: Int
    let submissions: [EngineDiscoverySubmission]?
}

struct EngineCompileEvent: Sendable, Codable {
    let submissionId: String
    let ok: Bool
    let exitCode: Int
    let timedOut: Bool
    let durationMs: Int64
    let stdout: String?
    let stderr: String?
}

struct EngineScanEvent: Sendable, Codable {
    let submissionId: String
    let bannedHits: Int
    let parseErrors: [String]?
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
        if let bundledURL = Bundle.main.url(forAuxiliaryExecutable: "autoscan-bridge"),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        if let executableDirectoryURL = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundledURL = executableDirectoryURL.appendingPathComponent("autoscan-bridge")
            if FileManager.default.isExecutableFile(atPath: bundledURL.path) {
                return bundledURL
            }
        }

        throw EngineClientError.bridgeNotFound
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
