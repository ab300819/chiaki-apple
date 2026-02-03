// SPDX-License-Identifier: AGPL-3.0-only
//
// HostQuickActionBar.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Quick action bar for host cards with focus management
// @requirement F-022 - 手柄操控 UI/UX 优化
// @satisfies AC-065 - 主机快速操作栏

import SwiftUI

/// Quick actions available for a host
/// @satisfies AC-065 - 创建 HostQuickAction 枚举
enum HostQuickAction: String, CaseIterable, Hashable {
    /// Wake up a standby host
    case wake
    /// Connect to the host for streaming
    case connect
    /// Set or change PIN code
    case pin
    /// Delete the host from the list
    case delete

    /// SF Symbol icon name for this action
    var iconName: String {
        switch self {
        case .wake: return "power"
        case .connect: return "play.fill"
        case .pin: return "lock"
        case .delete: return "trash"
        }
    }

    /// Color for this action
    var color: Color {
        switch self {
        case .wake: return .orange
        case .connect: return .green
        case .pin: return .blue
        case .delete: return .red
        }
    }

    /// Localized title for this action
    var localizedTitle: String {
        switch self {
        case .wake: return String(localized: "HostQuickAction.wake", defaultValue: "Wake")
        case .connect: return String(localized: "HostQuickAction.connect", defaultValue: "Connect")
        case .pin: return String(localized: "HostQuickAction.pin", defaultValue: "PIN")
        case .delete: return String(localized: "HostQuickAction.delete", defaultValue: "Delete")
        }
    }

    /// Default focused action based on host state
    /// @satisfies AC-065 - 待机主机显示"唤醒"，就绪主机显示"连接"
    static func defaultFocus(for host: ConsoleHost) -> HostQuickAction {
        switch host.state {
        case .standby:
            return .wake
        case .online, .offline, .unknown:
            return .connect
        }
    }

    /// Visible actions based on host state
    /// @satisfies AC-065 - 待机主机显示"唤醒"，就绪主机显示"连接"
    static func visibleActions(for host: ConsoleHost) -> [HostQuickAction] {
        switch host.state {
        case .standby:
            // Standby: show wake, hide connect
            return [.wake, .pin, .delete]
        case .online, .offline, .unknown:
            // Ready/Online/Offline: show connect, hide wake
            return [.connect, .pin, .delete]
        }
    }
}

#if os(tvOS)
/// Quick action bar displayed below focused host cards on tvOS
/// @requirement F-022 - 手柄操控 UI/UX 优化
/// @satisfies AC-065 - 创建 HostQuickActionBar 组件
struct HostQuickActionBar: View {
    let host: ConsoleHost
    let onWake: () -> Void
    let onConnect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    /// Focus state for action bar navigation
    /// @satisfies AC-065 - 操作栏内使用方向键导航
    @FocusState private var focusedAction: HostQuickAction?

    /// Whether the action bar is visible
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 16) {
            ForEach(HostQuickAction.visibleActions(for: host), id: \.self) { action in
                QuickActionButton(
                    action: action,
                    isDestructive: action == .delete,
                    onTap: { performAction(action) }
                )
                .focused($focusedAction, equals: action)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .animation(.snappy(duration: 0.2), value: isVisible)
        .onAppear {
            // Set default focus when bar appears
            focusedAction = HostQuickAction.defaultFocus(for: host)
        }
    }

    private func performAction(_ action: HostQuickAction) {
        HapticFeedback.button()
        switch action {
        case .wake:
            onWake()
        case .connect:
            onConnect()
        case .pin:
            onPin()
        case .delete:
            onDelete()
        }
    }
}

/// Individual action button in the quick action bar
private struct QuickActionButton: View {
    let action: HostQuickAction
    let isDestructive: Bool
    let onTap: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: action.iconName)
                    .font(.title3)
                    .foregroundStyle(isFocused ? .white : action.color)

                Text(action.localizedTitle)
                    .font(.caption)
                    .foregroundStyle(isFocused ? .white : .primary)
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isFocused ? action.color : Color.clear)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

// MARK: - Preview

#Preview("Online Host") {
    VStack {
        Spacer()
        HostQuickActionBar(
            host: .mockOnline,
            onWake: {},
            onConnect: {},
            onPin: {},
            onDelete: {},
            isVisible: .constant(true)
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

#Preview("Standby Host") {
    VStack {
        Spacer()
        HostQuickActionBar(
            host: .mockStandby,
            onWake: {},
            onConnect: {},
            onPin: {},
            onDelete: {},
            isVisible: .constant(true)
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
#endif
