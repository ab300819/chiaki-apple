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
                        
                        Text(host.address)
                            .font(.caption)
                            .foregroundStyle(isFocused ? .white.opacity(0.8) : .secondary)
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
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
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
