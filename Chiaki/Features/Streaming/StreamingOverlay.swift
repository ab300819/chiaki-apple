import SwiftUI

struct StreamingOverlay: View {
    var viewModel: StreamingViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Video stats
            HStack(spacing: 16) {
                StatItem(icon: "display", value: viewModel.currentResolution)
                StatItem(
                    icon: "speedometer",
                    value: String(format: "%.0f FPS", viewModel.currentFrameRate)
                )
            }

            Spacer()

            // Right side: Network stats + controls
            HStack(spacing: 16) {
                // Network quality indicator
                NetworkQualityIndicator(quality: viewModel.connectionQuality)

                StatItem(
                    icon: "waveform.path.ecg",
                    value: String(format: "%.0f ms", viewModel.latency)
                )
                StatItem(
                    icon: "antenna.radiowaves.left.and.right",
                    value: String(format: "%.1f Mbps", viewModel.bitrate)
                )

                // Packet loss with semantic color
                PacketLossItem(
                    packetLoss: viewModel.packetLoss,
                    droppedFrames: viewModel.droppedFrames,
                    recoveredFrames: viewModel.recoveredFrames
                )

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
        .cornerRadius(ChiakiTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ChiakiTheme.Radius.medium)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Network Quality Indicator

private struct NetworkQualityIndicator: View {
    let quality: ConnectionQuality

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < quality.signalBars ? barColor : Color.gray.opacity(0.3))
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .frame(height: maxBarHeight)
        .accessibilityLabel(String(localized: "accessibility.networkQuality \(quality.rawValue)"))
    }

    private var barColor: Color {
        switch quality {
        case .excellent: return ChiakiTheme.Status.excellent
        case .good: return ChiakiTheme.Status.good
        case .fair: return ChiakiTheme.Status.fair
        case .poor: return ChiakiTheme.Status.poor
        case .unknown: return ChiakiTheme.Status.offline
        }
    }

    #if os(tvOS)
    private let barWidth: CGFloat = 6
    private let maxBarHeight: CGFloat = 20
    #else
    private let barWidth: CGFloat = 3
    private let maxBarHeight: CGFloat = 12
    #endif

    private func barHeight(for index: Int) -> CGFloat {
        let ratio = CGFloat(index + 1) / 4.0
        return maxBarHeight * (0.4 + ratio * 0.6)
    }
}

// MARK: - Packet Loss Item

private struct PacketLossItem: View {
    let packetLoss: Double
    let droppedFrames: Int
    let recoveredFrames: Int

    var body: some View {
        HStack(spacing: 6) {
            #if os(tvOS)
            Image(systemName: "xmark.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(lossColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f%%", packetLoss))
                    .font(.system(size: 20, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(lossColor)

                if droppedFrames > 0 || recoveredFrames > 0 {
                    HStack(spacing: 8) {
                        if droppedFrames > 0 {
                            Text(String(localized: "overlay.dropped \(droppedFrames)"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        if recoveredFrames > 0 {
                            Text(String(localized: "overlay.recovered \(recoveredFrames)"))
                                .font(.system(size: 14))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
            }
            #else
            Image(systemName: "xmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(lossColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f%%", packetLoss))
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(lossColor)

                if droppedFrames > 0 || recoveredFrames > 0 {
                    HStack(spacing: 4) {
                        if droppedFrames > 0 {
                            Text(String(localized: "overlay.drop \(droppedFrames)"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        if recoveredFrames > 0 {
                            Text(String(localized: "overlay.rec \(recoveredFrames)"))
                                .font(.system(size: 9))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
            }
            #endif
        }
        .accessibilityLabel(String(localized: "accessibility.packetLossStats \(packetLoss) \(droppedFrames) \(recoveredFrames)"))
    }

    private var lossColor: Color {
        if packetLoss > 5.0 {
            return ChiakiTheme.Status.poor
        } else if packetLoss > 1.0 {
            return ChiakiTheme.Status.fair
        } else if packetLoss > 0.1 {
            return .orange
        } else {
            return ChiakiTheme.Status.excellent
        }
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
