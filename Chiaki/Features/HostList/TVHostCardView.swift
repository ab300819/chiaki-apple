import SwiftUI

#if os(tvOS)
/**
 * Host card view for tvOS with quick action bar support
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-065 - 主机快速操作栏
 */
struct TVHostCardView: View {
    let host: ConsoleHost
    var onWakeUp: () -> Void
    var onConnect: (() -> Void)?
    var onPin: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.isFocused) var isFocused

    /// Whether the quick action bar is visible
    /// @satisfies AC-065 - 主机卡片聚焦时显示操作栏，失焦时隐藏
    @State private var showQuickActionBar = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Card
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(radius: isFocused ? 20 : 5)
                
                VStack(spacing: 16) {
                    // Icon
                    Image(systemName: host.isPS5 ? "gamecontroller" : "gamecontroller.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(isFocused ? .white : Color.accentColor)
                        .shadow(radius: isFocused ? 10 : 0)
                    
                    VStack(spacing: 4) {
                        Text(host.nickname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(isFocused ? .white : .primary)

                        /**
                         * Running app info (when online)
                         * @requirement F-036
                         * @satisfies AC-131 - 使用语义色替代硬编码颜色
                         */
                        if let runningApp = host.runningApp, host.state == .online {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text(runningApp)
                            }
                            .font(.caption2)
                            .foregroundStyle(isFocused ? .white : Color.accentColor)
                            .lineLimit(1)
                        }

                        Text(host.address)
                            .font(.caption)
                            .foregroundStyle(isFocused ? .white.opacity(0.8) : .secondary)

                        // Additional info (shown on focus)
                        if isFocused {
                            VStack(spacing: 2) {
                                if let titleId = host.runningAppId, host.state == .online {
                                    Text(String(localized: "hostRow.titleId \(titleId)"))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                if let version = host.systemVersion {
                                    Text(String(localized: "hostRow.firmwareVersion \(version)"))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                if let lastConnected = host.lastConnectedAt {
                                    Text(L10n.HostList.lastSeen(lastConnected.formatted(date: .abbreviated, time: .omitted)))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    
                        /**
                         * Status Badge with VoiceOver support
                         * @requirement F-036
                         * @satisfies AC-132 - tvOS 状态徽章添加 accessibilityLabel
                         */
                    Group {
                        if !host.isRegistered {
                            Text(L10n.HostList.registerNeeded)
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .accessibilityLabel(String(localized: "accessibility.hostStatus.needsRegistration"))
                        } else {
                            switch host.state {
                            case .online:
                                Text(L10n.Common.online)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .accessibilityLabel(String(localized: "accessibility.hostStatus.online"))
                            case .standby:
                                Text(L10n.Common.standby)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .accessibilityLabel(String(localized: "accessibility.hostStatus.standby"))
                            case .offline:
                                Text(L10n.Common.offline)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.gray)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .accessibilityLabel(String(localized: "accessibility.hostStatus.offline"))
                            case .unknown:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(20)
            }
            .aspectRatio(1.2, contentMode: .fit) // Card aspect ratio
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor : Color.clear,
                        lineWidth: isFocused ? 4 : 0
                    )
            )
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .brightness(isFocused ? 0.1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .overlay(alignment: .bottom) {
            // Quick action bar appears below card when focused
            // @satisfies AC-065 - 主机卡片聚焦时显示操作栏，失焦时隐藏
            if isFocused && hasQuickActions {
                HostQuickActionBar(
                    host: host,
                    onWake: onWakeUp,
                    onConnect: { onConnect?() },
                    onPin: { onPin?() },
                    onDelete: { onDelete?() },
                    isVisible: .constant(true)
                )
                .offset(y: 80) // Position below the card
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: isFocused) { _, newValue in
            // Show/hide action bar based on focus
            showQuickActionBar = newValue
        }
    }

    /// Whether this card should show quick actions
    private var hasQuickActions: Bool {
        // Only show for registered hosts or when actions are provided
        host.isRegistered || onConnect != nil
    }
}

#Preview("Online Host") {
    TVHostCardView(
        host: ConsoleHost.mockOnline,
        onWakeUp: {},
        onConnect: {},
        onPin: {},
        onDelete: {}
    )
    .environment(SettingsStore())
    .environment(NavigationManager())
    .padding()
    .background(Color.gray)
}

#Preview("Standby Host") {
    TVHostCardView(
        host: ConsoleHost.mockStandby,
        onWakeUp: {},
        onConnect: {},
        onPin: {},
        onDelete: {}
    )
    .environment(SettingsStore())
    .environment(NavigationManager())
    .padding()
    .background(Color.gray)
}
#endif
