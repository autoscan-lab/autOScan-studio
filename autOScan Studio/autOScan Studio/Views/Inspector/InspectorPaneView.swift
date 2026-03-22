import SwiftUI

struct InspectorPaneView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: StudioTheme.sidebarColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                gradingSection

                if let report = state.latestRunReport {
                    resultsSection(report)
                } else {
                    emptyResultsSection
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gradingSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Grading")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Spacer(minLength: 0)

                    statusLabel
                }

                HStack(alignment: .center, spacing: 8) {
                    Text("Policy")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Menu {
                        ForEach(state.policies) { policy in
                            Button {
                                state.activatePolicy(policyID: policy.id)
                            } label: {
                                HStack {
                                    Text(policy.name)
                                    if policy.id == state.activePolicyID {
                                        Spacer(minLength: 8)
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        policyPickerLabel
                    }
                    .menuStyle(.borderlessButton)

                    Spacer(minLength: 0)

                    Button("Edit") {
                        state.openActivePolicyEditor()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(StudioTheme.accent)
                    .disabled(state.activePolicy == nil)
                }

                HStack(spacing: 8) {
                    Button("Run Workspace") {
                        state.runWorkspaceSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                    .disabled(!state.canRunWorkspace)

                    Button("Run Submission") {
                        state.runSelectedSubmission()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.canRunSelectedSubmission)
                }

                if let selectedSubmissionName = state.selectedSubmissionName {
                    Text("Selected submission: \(selectedSubmissionName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(1)
                }

                Text(runStatusDetail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(runStatusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func resultsSection(_ report: EngineRunReport) -> some View {
        sectionCard(fillHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Results")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Spacer(minLength: 0)

                    Button("Export") {
                        state.exportLatestRunReport()
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    summaryValue("\(report.summary.totalSubmissions)", label: "Submissions")
                    summaryValue("\(report.summary.compileFail)", label: "Compile Fail")
                    summaryValue("\(report.summary.bannedHitsTotal)", label: "Banned Hits")
                    summaryValue(durationLabel(report.summary.durationMs), label: "Duration")
                }

                if let topBannedSummary {
                    Text(topBannedSummary)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(2)
                }

                Table(orderedSubmissions(report)) {
                    TableColumn("Submission") { submission in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(submission.id)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(StudioTheme.textPrimary)
                                .lineLimit(1)

                            Text(submission.status)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(StudioTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("Compile") { submission in
                        Text(submission.compileOk ? "OK" : "Fail")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(submission.compileOk ? .green : .red)
                    }
                    .width(min: 54, ideal: 60)

                    TableColumn("Banned") { submission in
                        Text("\(submission.bannedCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(submission.bannedCount > 0 ? .orange : StudioTheme.textSecondary)
                    }
                    .width(min: 54, ideal: 60)

                    TableColumn("Time") { submission in
                        Text(durationLabel(submission.compileTimeMs))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(StudioTheme.textSecondary)
                    }
                    .width(min: 58, ideal: 72)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var emptyResultsSection: some View {
        sectionCard(fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Results")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Text("Run a workspace or submission to populate compile results, banned-call hits, and submission rows here.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var policyPickerLabel: some View {
        HStack(spacing: 8) {
            Text(state.activePolicy?.name ?? "Choose active policy")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(StudioTheme.hover)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var statusLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(runStatusColor)
                .frame(width: 8, height: 8)

            Text(runStatusTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private var runStatusTitle: String {
        if state.isRunInProgress {
            return "Running"
        }

        if state.latestRunError != nil {
            return "Failed"
        }

        if state.latestRunReport != nil {
            return "Ready"
        }

        return "Idle"
    }

    private var runStatusColor: Color {
        if state.isRunInProgress {
            return StudioTheme.accent
        }

        if state.latestRunError != nil {
            return .red
        }

        if state.latestRunReport != nil {
            return .green
        }

        return StudioTheme.textSecondary
    }

    private var runStatusDetail: String {
        if let latestRunError = state.latestRunError {
            return latestRunError
        }

        return state.runStatusMessage
    }

    private var topBannedSummary: String? {
        guard
            let report = state.latestRunReport,
            !report.summary.topBannedFunctions.isEmpty
        else {
            return nil
        }

        let topItems = report.summary.topBannedFunctions
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")

        return "Top banned functions: \(topItems)"
    }

    private func orderedSubmissions(_ report: EngineRunReport) -> [EngineRunSubmission] {
        report.submissions.sorted { lhs, rhs in
            let lhsHasIssues = !lhs.compileOk || lhs.bannedCount > 0
            let rhsHasIssues = !rhs.compileOk || rhs.bannedCount > 0

            if lhsHasIssues != rhsHasIssues {
                return lhsHasIssues && !rhsHasIssues
            }

            if lhs.bannedCount != rhs.bannedCount {
                return lhs.bannedCount > rhs.bannedCount
            }

            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func sectionCard<Content: View>(fillHeight: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func durationLabel(_ durationMs: Int64) -> String {
        if durationMs >= 1000 {
            let seconds = Double(durationMs) / 1000
            return "\(seconds.formatted(.number.precision(.fractionLength(1))))s"
        }

        return "\(durationMs)ms"
    }
}
