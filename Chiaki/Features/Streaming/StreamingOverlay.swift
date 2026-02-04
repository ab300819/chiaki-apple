import SwiftUI

struct StreamingOverlay: View {
    let stats: StreamStatsManager
    let pipManager: PiPManager

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Video stats
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    StatItem(icon: "display", value: stats.currentResolution)
                    if stats.isHDR {
                        HDRBadge()
                    }
                }
                StatItem(
                    icon: "speedometer",
                    value: String(format: "%.0f FPS", stats.currentFrameRate)
                )
            }

            Spacer()

            // Right side: Network stats + controls
            HStack(spacing: 16) {
                // Network quality indicator
                NetworkQualityIndicator(quality: stats.connectionQuality)

                StatItem(
                    icon: "waveform.path.ecg",
                    value: String(format: "%.0f ms", stats.latency)
                )
                StatItem(
                    icon: "antenna.radiowaves.left.and.right",
                    value: String(format: "%.1f Mbps", stats.bitrate)
                )

                // Packet loss with semantic color
                PacketLossItem(
                    packetLoss: stats.packetLoss,
                    droppedFrames: stats.droppedFrames,
                    recoveredFrames: stats.recoveredFrames
                )
                
                // Performance Metrics
                // [satisfies] AC-085
                if stats.decodeTimeMs > 0 {
                    PerformanceStatsItem(stats: stats)
                }

                #if os(iOS)
                if pipManager.isPiPSupported {
                    Button(action: {
                        pipManager.togglePiP()
                    }) {
                        Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
                #endif
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: ChiakiTheme.Radius.medium))
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
        .accessibilityLabel(L10n.Accessibility.networkQuality(quality.rawValue))
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
                .foregroundStyle(lossColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f%%", packetLoss))
                    .font(.system(size: 20, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(lossColor)

                if droppedFrames > 0 || recoveredFrames > 0 {
                    HStack(spacing: 8) {
                        if droppedFrames > 0 {
                            Text(String(localized: "overlay.dropped \(droppedFrames)"))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        if recoveredFrames > 0 {
                            Text(String(localized: "overlay.recovered \(recoveredFrames)"))
                                .font(.system(size: 14))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                }
            }
            #else
            Image(systemName: "xmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(lossColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f%%", packetLoss))
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(lossColor)

                if droppedFrames > 0 || recoveredFrames > 0 {
                    HStack(spacing: 4) {
                        if droppedFrames > 0 {
                            Text(String(localized: "overlay.drop \(droppedFrames)"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        if recoveredFrames > 0 {
                            Text(String(localized: "overlay.rec \(recoveredFrames)"))
                                .font(.system(size: 9))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                }
            }
            #endif
        }
        .accessibilityLabel(L10n.Accessibility.packetLossStats(loss: packetLoss, dropped: droppedFrames, recovered: recoveredFrames))
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

// MARK: - HDR Badge

private struct HDRBadge: View {
    var body: some View {
        #if os(tvOS)
        Text("HDR")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        #else
        Text("HDR")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        #endif
    }
}

// MARK: - Performance Stats Item

private struct PerformanceStatsItem: View {
    let stats: StreamStatsManager

    var body: some View {
        HStack(spacing: 8) {
            #if os(tvOS)
            Image(systemName: "cpu")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "D: %.1fms R: %.1fms", stats.decodeTimeMs, stats.renderTimeMs))
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(String(format: "P95: %.0fms P99: %.0fms", stats.p95LatencyMs, stats.p99LatencyMs))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            #else
            Image(systemName: "cpu")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "D:%.1fms R:%.1fms", stats.decodeTimeMs, stats.renderTimeMs))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(String(format: "P95:%.0fms P99:%.0fms", stats.p95LatencyMs, stats.p99LatencyMs))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(width: 1)
                .padding(.vertical, 4)
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            #if os(tvOS)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            #else
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            #endif
        }
    }
}

#Preview {
    ZStack {
        Color.black
        StreamingOverlay(
            stats: StreamStatsManager(statistics: StreamStatistics()),
            pipManager: PiPManager()
        )
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
