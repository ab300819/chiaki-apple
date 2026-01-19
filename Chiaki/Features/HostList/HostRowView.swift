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
                .foregroundStyle(.blue)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(host.nickname)
                    .font(.headline)
                Text(host.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status
            Group {
                if !host.isRegistered {
                    Text("Register Needed")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    switch host.state {
                    case .online:
                        Text("Online")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    case .standby:
                        Button(action: onWakeUp) {
                            Text("Wake Up")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    case .offline:
                        Text("Offline")
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
}
