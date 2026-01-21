import SwiftUI

#if os(tvOS)
struct TVHostCardView: View {
    let host: ConsoleHost
    var onWakeUp: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
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
                        .foregroundStyle(isFocused ? .white : Color.chiakiPurple)
                        .shadow(radius: isFocused ? 10 : 0)
                    
                    VStack(spacing: 4) {
                        Text(host.nickname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(isFocused ? .white : .primary)

                        // Running app info (when online)
                        if let runningApp = host.runningApp, host.state == .online {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text(runningApp)
                            }
                            .font(.caption2)
                            .foregroundStyle(isFocused ? .white : .blue)
                            .lineLimit(1)
                        }

                        Text(host.address)
                            .font(.caption)
                            .foregroundStyle(isFocused ? .white.opacity(0.8) : .secondary)

                        // Additional info (shown on focus)
                        if isFocused {
                            VStack(spacing: 2) {
                                if let titleId = host.runningAppId, host.state == .online {
                                    Text("Title: \(titleId)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                if let version = host.systemVersion {
                                    Text("FW \(version)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                if let lastConnected = host.lastConnectedAt {
                                    Text("Last: \(lastConnected.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    
                    // Status Badge
                    Group {
                        if !host.isRegistered {
                            Text("Register Needed")
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        } else {
                            switch host.state {
                            case .online:
                                Text("Online")
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            case .standby:
                                Text("Standby") // Wake Up handled by action, but badge shows state
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            case .offline:
                                Text("Offline")
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.gray)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
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
                        isFocused ? Color.chiakiPurple : Color.clear,
                        lineWidth: isFocused ? 4 : 0
                    )
            )
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .brightness(isFocused ? 0.1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

#Preview {
    TVHostCardView(host: ConsoleHost.mockOnline, onWakeUp: {})
        .environment(SettingsStore())
        .environment(NavigationManager())
        .padding()
        .background(Color.gray)
}
#endif
