import SwiftUI

struct StreamingView: View {
    @State private var viewModel: StreamingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @StateObject private var rendererHolder = VideoRendererHolder()
    
    init(host: ConsoleHost) {
        _viewModel = State(initialValue: StreamingViewModel(host: host))
    }
    
    var body: some View {
            ZStack {
            Color.black
                .ignoresSafeArea()
            
            if viewModel.state == .streaming {
                VideoStreamView(
                    renderer: $rendererHolder.renderer,
                    displayMode: .normal,
                    zoomFactor: 1.0
                )
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
                            viewModel.disconnect()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .accessibilityLabel("Disconnect and close stream")
                        
                        Spacer()
                        
                        StreamingOverlay(viewModel: viewModel)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        #if os(iOS)
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        #endif
        .onTapGesture {
            viewModel.toggleOverlay()
        }
        .onAppear {
            rendererHolder.initialize()
            if let renderer = rendererHolder.renderer {
                viewModel.setVideoRenderer(renderer)
            }
            viewModel.connect(settings: settingsStore.streamSettings)
        }
        .onDisappear {
            viewModel.disconnect()
            rendererHolder.cleanup()
        }
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
                    
                    Text("Connecting to Console...")
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
                    
                    Text("Video Stream Placeholder")
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
}
