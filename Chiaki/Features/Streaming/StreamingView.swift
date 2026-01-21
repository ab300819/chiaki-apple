import SwiftUI

struct StreamingView: View {
    @State private var viewModel: StreamingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(HostStore.self) private var hostStore
    @StateObject private var rendererHolder = VideoRendererHolder()
    @State private var showingDisconnectConfirmation = false
    @State private var shouldGoToBedOnDisconnect = false
    @State private var pinVerified = false

    private let host: ConsoleHost

    private var requiresPin: Bool {
        ConsolePinManager.shared.requiresPinEntry(for: host)
    }

    init(host: ConsoleHost) {
        self.host = host
        _viewModel = State(initialValue: StreamingViewModel(host: host))
    }
    
    var body: some View {
        Group {
            if requiresPin && !pinVerified {
                pinEntryContent
            } else {
                streamingContent
            }
        }
    }

    @ViewBuilder
    private var pinEntryContent: some View {
        ConsolePinEntryView(host: host) {
            pinVerified = true
        } onCancel: {
            dismiss()
        }
    }

    private func handleDisconnectAction() {
        switch settingsStore.disconnectAction {
        case .doNothing:
            viewModel.disconnect()
            dismiss()
        case .enterSleepMode:
            viewModel.goToBed()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.disconnect()
                dismiss()
            }
        case .ask:
            showingDisconnectConfirmation = true
        }
    }

    @ViewBuilder
    private var streamingContent: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if viewModel.state == .streaming {
                VideoStreamView(
                    renderer: rendererHolder.renderer,
                    displayMode: viewModel.displayMode.toVideoDisplayMode,
                    zoomFactor: Float(viewModel.zoomFactor)
                ) { mtkView in
                    #if os(iOS)
                    viewModel.pipManager.setup(with: mtkView)
                    #endif
                }
            } else {
                VideoPlaceholderView(state: viewModel.state)
            }
            
            #if os(iOS)
            if viewModel.state == .connected && settingsStore.streamSettings.isTouchControllerEnabled {
                VirtualControllerView { input in
                    viewModel.handleInput(input)
                }
                .zIndex(1)
            }
            #endif
            
            if viewModel.isOverlayVisible {
                VStack {
                    HStack(alignment: .center) {
                        Button(action: {
                            handleDisconnectAction()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .accessibilityLabel(String(localized: "accessibility.disconnectStream"))

                        Spacer()

                        // Control menu button
                        Button(action: { viewModel.toggleControlMenu() }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "accessibility.openControlsMenu"))

                        StreamingOverlay(viewModel: viewModel)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    Spacer()
                    
                    if viewModel.isOverlayVisible && settingsStore.streamSettings.showControllerHints {
                        ControllerHintView(controllerType: ControllerManager.shared.detectedControllerType)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }

            // Control menu overlay
            if viewModel.isControlMenuVisible {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.toggleControlMenu() }
                    .zIndex(3)

                StreamingControlsView(
                    viewModel: viewModel,
                    onSaveSettings: { volume, displayMode, zoomFactor in
                        settingsStore.updateVolume(volume)
                        settingsStore.updateDisplayMode(displayMode)
                        settingsStore.updateZoomFactor(zoomFactor)
                    },
                    onDisconnect: {
                        viewModel.toggleControlMenu()
                        handleDisconnectAction()
                    },
                    onGoToBed: {
                        viewModel.goToBed()
                        viewModel.toggleControlMenu()
                    },
                    onToggleMic: viewModel.isMicEnabled ? { viewModel.toggleMic() } : nil
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(4)
            }
        }
        #if os(iOS)
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        #endif
        .onTapGesture {
            viewModel.toggleOverlay()
        }
        .confirmationDialog(
            L10n.Streaming.disconnectConfirmTitle,
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Streaming.disconnectOnly, role: .destructive) {
                viewModel.disconnect()
                dismiss()
            }

            Button(L10n.Streaming.restModeAndDisconnect) {
                viewModel.goToBed()
                // Give it a tiny bit of time to send the command before disconnecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.disconnect()
                    dismiss()
                }
            }

            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Streaming.disconnectConfirmMessage)
        }
        #if os(tvOS)
        .onExitCommand {
            handleDisconnectAction()
        }
        .onPlayPauseCommand {
            viewModel.toggleOverlay()
        }
        #endif
        .onAppear {
            rendererHolder.initialize()
            if let renderer = rendererHolder.renderer {
                viewModel.setVideoRenderer(renderer)
            }
            // Setup onConnected callback
            viewModel.onConnected = {
                var updatedHost = viewModel.host
                updatedHost.lastConnectedAt = Date()
                hostStore.updateHost(updatedHost)
            }
            // Apply saved playback settings
            viewModel.applySettings(from: settingsStore.streamSettings)
            viewModel.connect(settings: settingsStore.streamSettings, isRemote: settingsStore.useRemoteProfile)
            // Mark streaming active for macOS menu
            navigationManager.isStreaming = true
        }
        .onDisappear {
            viewModel.disconnect()
            rendererHolder.cleanup()
            // Mark streaming inactive
            navigationManager.isStreaming = false
        }
        #if os(macOS)
        // Handle macOS menu commands
        .onChange(of: navigationManager.toggleControlMenuTrigger) { _, _ in
            viewModel.toggleControlMenu()
        }
        .onChange(of: navigationManager.displayModeChangeTrigger) { _, newMode in
            if let mode = newMode {
                viewModel.setDisplayMode(mode)
                navigationManager.displayModeChangeTrigger = nil
            }
        }
        .onChange(of: navigationManager.volumeChangeTrigger) { _, newVolume in
            if let volume = newVolume {
                viewModel.setVolume(volume)
                navigationManager.volumeChangeTrigger = nil
            }
        }
        #endif
    }
}

private struct VideoPlaceholderView: View {
    let state: StreamingViewModel.ConnectionState
    
    var body: some View {
        ZStack {
            GridPattern()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .background(Color.black)
            
            VStack(spacing: 20) {
                if state == .connecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text(L10n.Streaming.connecting)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                } else if case .error(let message) = state {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    
                    Text(message)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if state == .connected {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.1))

                    Text(String(localized: "streaming.videoPlaceholder"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40
        
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, to: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

#Preview(traits: .landscapeLeft) {
    StreamingView(host: MockData.hostPS5)
        .environment(SettingsStore())
        .environment(NavigationManager())
}
