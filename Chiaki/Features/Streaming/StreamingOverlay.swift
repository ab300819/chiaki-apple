import SwiftUI

struct StreamingOverlay: View {
    var viewModel: StreamingViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                StatItem(icon: "display", value: viewModel.currentResolution)
                StatItem(icon: "speedometer", value: "\(viewModel.currentFrameRate) FPS")
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                StatItem(icon: "waveform.path.ecg", value: String(format: "%.1f ms", viewModel.latency))
                StatItem(icon: "antenna.radiowaves.left.and.right", value: String(format: "%.1f Mbps", viewModel.bitrate))
                
                #if os(iOS)
                if viewModel.pipManager.isPiPSupported {
                    Button(action: {
                        viewModel.pipManager.togglePiP()
                    }) {
                        Image(systemName: viewModel.pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                #endif
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            #if os(tvOS)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 24, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            #else
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            #endif
        }
    }
}

#Preview {
    ZStack {
        Color.black
        StreamingOverlay(viewModel: StreamingViewModel(host: MockData.hostPS5))
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
