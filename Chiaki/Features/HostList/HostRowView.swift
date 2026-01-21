import SwiftUI

struct HostRowView: View {
    let host: ConsoleHost
    var onWakeUp: () -> Void
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: host.isPS5 ? "gamecontroller" : "gamecontroller.fill") // Placeholder
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.chiakiPurple)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(host.nickname)
                    .font(.headline)

                // Running app info (when online)
                if let runningApp = host.runningApp, host.state == .online {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text(runningApp)
                        if let titleId = host.runningAppId {
                            Text(String(localized: "hostRow.titleIdParentheses \(titleId)"))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }

                HStack(spacing: 8) {
                    Text(host.address)
                    if let version = host.systemVersion {
                        Text("•")
                        Text(String(localized: "hostRow.firmwareVersion \(version)"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !host.macAddress.isEmpty {
                    Text(host.macAddress)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if let lastConnected = host.lastConnectedAt {
                    Text(L10n.HostList.lastSeen(lastConnected.formatted(date: .abbreviated, time: .shortened)))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Status
            Group {
                if !host.isRegistered {
                    Text(L10n.HostList.registerNeeded)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    switch host.state {
                    case .online:
                        Text(L10n.Common.online)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    case .standby:
                        Button(action: onWakeUp) {
                            Text(L10n.HostList.wakeUp)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    case .offline:
                        Text(L10n.Common.offline)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.gray)
                            .clipShape(Capsule())
                    case .unknown:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        HostRowView(host: ConsoleHost.mockOnline, onWakeUp: {})
        HostRowView(host: ConsoleHost.mockStandby, onWakeUp: {})
        HostRowView(host: ConsoleHost.mockOffline, onWakeUp: {})
    }
    .environment(SettingsStore())
    .environment(NavigationManager())
}
