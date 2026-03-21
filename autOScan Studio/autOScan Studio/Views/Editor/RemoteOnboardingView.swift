import SwiftUI

struct RemoteOnboardingView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let preset = state.selectedRemotePreset {
                    summaryCard(for: preset)
                    accountCard(for: preset)
                    if shouldShowSetupSteps {
                        stepsCard
                    }
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

                    Text(summarySubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                Spacer(minLength: 0)

                summaryStatusBadge
            }

            VStack(alignment: .leading, spacing: 6) {
                infoLine("Host", preset.primaryText)
                infoLine("Shell alias", "ssh \(preset.name.lowercased())")
            }

            if state.remoteSetupState == .ready, state.remoteConnectionState == .connected {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SSH is live for \(preset.name). Upload, sync, and later grading actions should route through this remote session.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button("Disconnect") {
                            state.disconnectRemoteConnection()
                        }
                        .buttonStyle(.bordered)

                        Text("Stay on La Salle VPN or campus Wi-Fi while the session is active.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(StudioTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let connectionStatusMessage {
                inlineStatusMessage(connectionStatusMessage)
            }

            if state.isRemoteInstallerVisible {
                installerCard(for: preset)
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

            Text("When setup starts, Studio opens your `~/.ssh` folder directly and asks for one-time permission so the same aliases work outside Studio too.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let accountStatusMessage {
                inlineStatusMessage(accountStatusMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SSH Setup")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text(setupHelperText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(state.remoteOnboardingSteps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        stepIndicator(for: step.state)

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

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Setup")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text("Choose a university server from the sidebar to configure SSH access and open a live remote session here.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var summarySubtitle: String {
        switch state.remoteSetupState {
        case .needsSetup:
            return "SSH setup required before the remote session can open."
        case .settingUp:
            return "Preparing local SSH access in the background."
        case .ready:
            switch state.remoteConnectionState {
            case .disconnected:
                return "SSH is ready on this Mac. Use the left sidebar tag when you want to open a live remote session."
            case .connecting:
                return "Opening a live SSH session for remote compile and run actions."
            case .connected:
                return "Remote session is live and ready for workspace actions."
            }
        }
    }

    private var shouldShowSetupSteps: Bool {
        state.remoteSetupState == .settingUp
    }

    private var accountStatusMessage: String? {
        guard let message = state.remoteStatusMessage else {
            return nil
        }

        let lowered = message.lowercased()
        if lowered.contains("name.lastname")
            || lowered.contains(".ssh")
            || lowered.contains("ssh setup was cancelled")
            || lowered.contains("local ssh key")
            || lowered.contains("ssh config")
            || lowered.contains("salle aliases") {
            return message
        }

        return nil
    }

    private var connectionStatusMessage: String? {
        guard let message = state.remoteStatusMessage else {
            return nil
        }

        if accountStatusMessage == message {
            return nil
        }

        return message
    }

    private var setupHelperText: String {
        "Studio is handling the local SSH pieces automatically. Once this finishes, it will try to open the remote session for you."
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
    private var summaryStatusBadge: some View {
        if state.isRemoteInstallerVisible {
            statusBadge(state.isRemoteInstallerRunning ? "Install" : "Review")
        } else {
            switch state.remoteSetupState {
            case .needsSetup:
                statusBadge("Needs Setup")
            case .settingUp:
                statusBadge("Setup")
            case .ready:
                switch state.remoteConnectionState {
                case .disconnected:
                    statusBadge("Ready")
                case .connecting:
                    statusBadge("Joining")
                case .connected:
                    statusBadge("Connected")
                }
            }
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
        switch state.remoteSetupState {
        case .needsSetup:
            return StudioTheme.hover
        case .settingUp:
            return Color.orange
        case .ready:
            switch state.remoteConnectionState {
            case .disconnected:
                return StudioTheme.hover
            case .connecting:
                return Color.orange
            case .connected:
                return StudioTheme.accent
            }
        }
    }

    @ViewBuilder
    private func stepIndicator(for state: StudioAppState.RemoteOnboardingStep.State) -> some View {
        switch state {
        case .pending:
            Circle()
                .fill(stepColor(for: state))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
        case .active:
            ProgressView()
                .controlSize(.small)
                .padding(.top, 2)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(stepColor(for: state))
                .padding(.top, 2)
        }
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

    private func installerCard(for preset: StudioAppState.RemotePreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Install Public Key")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer(minLength: 0)

                if state.isRemoteInstallerRunning {
                    statusChip("Waiting")
                } else {
                    statusChip("Stopped")
                }
            }

            Text("Studio is using `ssh-copy-id` for \(preset.name). If the server asks for your La Salle password or host confirmation, respond below and the install will continue without leaving the app.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(state.remoteInstallerOutput.isEmpty ? "Installer output will appear here." : state.remoteInstallerOutput)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(state.remoteInstallerOutput.isEmpty ? StudioTheme.textSecondary : StudioTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 140, maxHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(StudioTheme.editor.opacity(0.88))
            )

            if let prompt = state.remoteInstallerPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text(promptLabel(for: prompt))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)

                    promptField(for: prompt)
                }
            } else if state.isRemoteInstallerRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Waiting for the next SSH prompt…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                if state.remoteInstallerPrompt != nil {
                    Button("Send") {
                        state.submitRemoteInstallerInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                    .disabled(state.remoteInstallerInput.isEmpty)
                } else if !state.isRemoteInstallerRunning {
                    Button("Try Again") {
                        state.dismissRemoteInstaller()
                        state.handleRemoteConnectionAction(for: preset)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.accent)
                }

                Button(state.isRemoteInstallerRunning ? "Cancel" : "Close") {
                    if state.isRemoteInstallerRunning {
                        state.cancelRemoteInstaller()
                    } else {
                        state.dismissRemoteInstaller()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StudioTheme.editor.opacity(0.42))
        )
    }

    private func promptLabel(for prompt: RemoteInstallerPrompt) -> String {
        switch prompt {
        case .secure(let text), .plain(let text):
            return text
        }
    }

    @ViewBuilder
    private func promptField(for prompt: RemoteInstallerPrompt) -> some View {
        switch prompt {
        case .secure(let text):
            SecureField(text, text: $state.remoteInstallerInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StudioTheme.editor.opacity(0.88))
                )
                .onSubmit {
                    state.submitRemoteInstallerInput()
                }
        case .plain(let text):
            TextField(text, text: $state.remoteInstallerInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StudioTheme.editor.opacity(0.88))
                )
                .onSubmit {
                    state.submitRemoteInstallerInput()
                }
        }
    }

    private func statusChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(StudioTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.orange.opacity(0.18))
            )
    }

    private func inlineStatusMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(StudioTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.14))
            )
    }
}
