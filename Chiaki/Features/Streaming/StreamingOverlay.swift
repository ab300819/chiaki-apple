import SwiftUI

struct StreamingOverlay: View {
    @ObservedObject var viewModel: StreamingViewModel
    
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
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct StreamingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            StreamingOverlay(viewModel: StreamingViewModel())
        }
    }
}
