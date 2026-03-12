import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum SidebarMode: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case policies = "Policies"
        case runs = "Runs"

        var id: String { rawValue }
    }

    var sidebarMode: SidebarMode = .workspace
    var isSidebarPresented = true

    var selectedPath: String?
    var fileTree: [String] = [
        "submissions/",
        "submissions/lab1/student_001/main.c",
        "submissions/lab1/student_002/main.c",
        "policies/default-policy.yaml",
        "reports/latest/"
    ]

    var editorText = """
    // autOScan Studio
    // Minimal shell scaffold.

    int main(void) {
        return 0;
    }
    """

    var activePolicy = "default-policy.yaml"
    var compileStatus = "Not run"
    var aiStatus = "Not run"

    var outputText = """
    --- expected/main.c
    +++ actual/main.c
    @@ -1,4 +1,4 @@
     int main(void) {
    -    return 0;
    +    return 1;
     }
    """

    init() {
        selectedPath = fileTree.first
    }
}
