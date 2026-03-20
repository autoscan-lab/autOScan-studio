import SwiftUI

struct RemoteOnboardingView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let preset = state.selectedRemotePreset {
                    summaryCard(for: preset)
                    accountCard(for: preset)
                    stepsCard
                    controlsCard(for: preset)
                } else {
                    emptyStateCard
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(StudioTheme.editor)
    }

    private func summaryCard(for preset: StudioAppState.RemotePreset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Text("SSH onboarding mock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                Spacer(minLength: 0)

                summaryAction(for: preset)
            }

            VStack(alignment: .leading, spacing: 6) {
                infoLine("Host", preset.primaryText)
                infoLine("Shell alias", "ssh \(preset.name.lowercased())")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func accountCard(for preset: StudioAppState.RemotePreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Salle Account")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioTheme.textSecondary)

                TextField("name.lastname", text: $state.remoteAccountUsername)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(StudioTheme.editor.opacity(0.85))
                    )

                Text("Studio will expand this to \(state.remoteLoginPreview(for: preset)).")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup Steps")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(state.remoteOnboardingSteps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        stepBadge(for: step.state)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(StudioTheme.textPrimary)

                            Text(step.detail)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(StudioTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func controlsCard(for preset: StudioAppState.RemotePreset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connection")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            HStack(spacing: 10) {
                switch state.remoteConnectionState {
                case .disconnected:
                    Text("Use the Connect tag above to start the SSH setup flow for \(preset.name).")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)

                case .linking:
                    Button("Next Step") {
                        state.advanceRemoteOnboardingMock()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)

                    Button("Reset") {
                        state.restartRemoteOnboardingMock()
                    }
                    .buttonStyle(.bordered)

                case .connected:
                    Text("SSH mock connected for \(preset.name).")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Button("Disconnect") {
                        state.disconnectRemoteConnection()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(helperText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Setup")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text("Choose a university server from the sidebar to preview the SSH onboarding flow here.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var helperText: String {
        switch state.remoteConnectionState {
        case .disconnected:
            return "This is where first-time users enter the `name.lastname` username before Studio generates or reuses SSH access."
        case .linking:
            return "Advance through the mock to preview the onboarding sequence that new users would follow."
        case .connected:
            return "In the real flow, this is where remote actions like upload and sync would become available."
        }
    }

    private func infoLine(_ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func summaryAction(for preset: StudioAppState.RemotePreset) -> some View {
        switch state.remoteConnectionState {
        case .disconnected:
            Button("Connect") {
                state.handleRemoteConnectionAction(for: preset)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(StudioTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(StudioTheme.accent.opacity(0.22))
            )

        case .linking:
            statusBadge("Linking")

        case .connected:
            statusBadge("Connected")
        }
    }

    private func statusBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(StudioTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(statusColor.opacity(0.2))
            )
    }

    private var statusColor: Color {
        switch state.remoteConnectionState {
        case .disconnected:
            return StudioTheme.hover
        case .linking:
            return Color.orange
        case .connected:
            return StudioTheme.accent
        }
    }

    private func stepBadge(for state: StudioAppState.RemoteOnboardingStep.State) -> some View {
        Circle()
            .fill(stepColor(for: state))
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }

    private func stepColor(for state: StudioAppState.RemoteOnboardingStep.State) -> Color {
        switch state {
        case .pending:
            return StudioTheme.hover
        case .active:
            return Color.orange
        case .done:
            return StudioTheme.accent
        }
    }
}
