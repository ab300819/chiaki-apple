// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerBatteryIndicator.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Displays controller battery level and charging status
// @requirement F-021 - GameController 深度集成
// @satisfies AC-064 - 控制器电池电量显示

import SwiftUI

/// Battery indicator view for connected game controllers
struct ControllerBatteryIndicator: View {
    /// Battery information to display
    let batteryInfo: ControllerManager.BatteryInfo?

    /// Whether to show the percentage text
    var showPercentage: Bool = true

    /// Compact mode for smaller displays
    var compact: Bool = false

    var body: some View {
        if let battery = batteryInfo {
            HStack(spacing: compact ? 2 : 4) {
                Image(systemName: battery.iconName)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(battery.color)

                if showPercentage {
                    Text(battery.percentageString)
                        .font(compact ? .caption2 : .caption)
                        .fontWeight(battery.isLow ? .semibold : .regular)
                        .foregroundStyle(battery.color)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: battery))
        }
    }

    /// Generate accessibility label for the battery info
    private func accessibilityLabel(for battery: ControllerManager.BatteryInfo) -> String {
        let percentage = Int(battery.level * 100)
        let stateDescription: String

        switch battery.state {
        case .charging:
            stateDescription = String(localized: "Battery.State.charging", defaultValue: "charging")
        case .full:
            stateDescription = String(localized: "Battery.State.full", defaultValue: "fully charged")
        case .discharging:
            if battery.isLow {
                stateDescription = String(localized: "Battery.State.low", defaultValue: "low battery")
            } else {
                stateDescription = String(localized: "Battery.State.discharging", defaultValue: "discharging")
            }
        case .unknown:
            stateDescription = String(localized: "Battery.State.unknown", defaultValue: "unknown")
        }

        return String(
            localized: "Battery.AccessibilityLabel",
            defaultValue: "Controller battery \(percentage) percent, \(stateDescription)"
        )
    }
}

// MARK: - Preview

#Preview("Normal Battery") {
    VStack(spacing: 20) {
        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.75, state: .discharging)
        )

        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.5, state: .discharging)
        )

        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.15, state: .discharging)
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("Charging") {
    VStack(spacing: 20) {
        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.5, state: .charging)
        )

        ControllerBatteryIndicator(
            batteryInfo: .init(level: 1.0, state: .full)
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("Compact Mode") {
    HStack(spacing: 20) {
        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.75, state: .discharging),
            compact: true
        )

        ControllerBatteryIndicator(
            batteryInfo: .init(level: 0.5, state: .charging),
            compact: true
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("No Controller") {
    ControllerBatteryIndicator(batteryInfo: nil)
        .padding()
        .background(Color.black)
}
