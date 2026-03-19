import SwiftUI

struct InspectorPaneView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: StudioTheme.sidebarColor)
                .ignoresSafeArea()

            if let report = state.latestRunReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Latest Run")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)

                        summaryRow("Policy", report.summary.policyName)
                        summaryRow("Root", report.summary.root)
                        summaryRow("Submissions", "\(report.summary.totalSubmissions)")
                        summaryRow("Compile Pass", "\(report.summary.compilePass)")
                        summaryRow("Compile Fail", "\(report.summary.compileFail)")
                        summaryRow("Timeouts", "\(report.summary.compileTimeout)")
                        summaryRow("Banned Hits", "\(report.summary.bannedHitsTotal)")
                        summaryRow("Banned Submissions", "\(report.summary.submissionsWithBanned)")
                        summaryRow("Duration", "\(report.summary.durationMs) ms")

                        if let firstProblem = report.submissions.first(where: { !$0.compileOK || $0.bannedCount > 0 }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Submission With Issues")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(StudioTheme.textPrimary)

                                Text(firstProblem.id)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(StudioTheme.textSecondary)

                                Text("Status: \(firstProblem.status)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(StudioTheme.textSecondary)
                            }
                            .padding(.top, 4)
                        }

                        if let error = state.latestRunError {
                            Text(error)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inspector")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Text("Run a workspace to see summary stats and the latest grading result here.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .textSelection(.enabled)
        }
    }
}
