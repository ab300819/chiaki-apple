import SwiftUI

/// View shown during auto-connect process at app launch
struct AutoConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(HostStore.self) private var hostStore

    let host: ConsoleHost
    let onConnected: () -> Void
    let onCancelled: () -> Void

    @State private var allowCancel = false
    @State private var showCancelHint = false
    @State private var statusMessage = "Waiting for console..."
    @State private var isCancelling = false
    @State private var connectionFailed = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Status message
                Text(statusMessage)
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(allowCancel ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: allowCancel)

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                // Cancel hint
                if showCancelHint && !isCancelling {
                    Text(cancelHintText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .transition(.opacity)
                }

                Spacer()

                // Console info
                VStack(spacing: 8) {
                    Image(systemName: host.isPS5 ? "playstation.logo" : "gamecontroller.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text(host.nickname)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))

                    Text(host.address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.bottom, 50)
            }
        }
        .onTapGesture {
            if allowCancel {
                cancelConnection()
            }
        }
        #if os(tvOS)
        .onExitCommand {
            if allowCancel {
                cancelConnection()
            }
        }
        #endif
        #if os(macOS)
        .onKeyPress(.escape) {
            if allowCancel {
                cancelConnection()
                return .handled
            }
            return .ignored
        }
        #endif
        .task {
            // Wait 1.5 seconds before allowing cancel
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                allowCancel = true
                showCancelHint = true
            }

            // Start the connection process
            await startConnection()
        }
    }

    private var cancelHintText: String {
        #if os(tvOS)
        return "Press Menu to cancel"
        #elseif os(macOS)
        return "Press Escape or click to cancel"
        #else
        return "Tap to cancel"
        #endif
    }

    private func cancelConnection() {
        guard !isCancelling else { return }

        isCancelling = true
        showCancelHint = false
        statusMessage = "Cancelling connection..."

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            onCancelled()
        }
    }

    private func startConnection() async {
        // If wake-up is enabled, try to wake the console first
        if settingsStore.autoConnectWakeUp && host.state == .standby {
            statusMessage = "Waking up console..."
            // Wake up logic would be handled by DiscoveryService
            // For now, we'll wait a bit then proceed
            try? await Task.sleep(for: .seconds(2))
        }

        // Check if host is online
        if host.state == .online || host.state == .standby {
            statusMessage = "Connecting..."
            try? await Task.sleep(for: .seconds(0.5))

            if !isCancelling {
                onConnected()
            }
        } else {
            // Host not reachable
            statusMessage = "Console not found. Exiting..."
            connectionFailed = true

            try? await Task.sleep(for: .seconds(2))
            if !isCancelling {
                onCancelled()
            }
        }
    }
}

#Preview {
    AutoConnectView(
        host: ConsoleHost(nickname: "PS5", address: "192.168.1.100"),
        onConnected: {},
        onCancelled: {}
    )
    .environment(SettingsStore())
    .environment(HostStore())
}
