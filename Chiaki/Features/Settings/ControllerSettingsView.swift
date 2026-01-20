import SwiftUI

struct ControllerSettingsView: View {
    @Environment(SettingsStore.self) var store

    var body: some View {
        @Bindable var store = store
        Form {
            // Connected Controllers Section
            Section {
                let controllers = ControllerManager.shared.connectedControllers
                if controllers.isEmpty {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.secondary)
                        Text("No controllers connected")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(controllers) { controller in
                        HStack {
                            Image(systemName: controllerIcon(for: controller))
                                .foregroundColor(controller.isActive ? Color.chiakiPurple : .secondary)
                            VStack(alignment: .leading) {
                                Text(controller.name)
                                    .fontWeight(controller.isActive ? .semibold : .regular)
                                Text(controller.productCategory)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if controller.isActive {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.chiakiPurple)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            } header: {
                Text("Connected Controllers")
            }

            // Feedback Section
            Section {
                Toggle("Haptic Feedback", isOn: $store.streamSettings.hapticFeedbackEnabled)
                Toggle("Motion Controls", isOn: $store.streamSettings.motionControlsEnabled)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Motion controls require a DualSense or compatible controller with gyroscope.")
            }

            // Input Settings Section
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Stick Deadzone")
                        Spacer()
                        Text(String(format: "%.0f%%", store.streamSettings.stickDeadzone * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $store.streamSettings.stickDeadzone,
                        in: 0...0.3,
                        step: 0.01
                    )
                    .tint(Color.chiakiPurple)
                }

                Toggle("Swap ✕/○ Buttons", isOn: $store.streamSettings.swapCrossCircle)
            } header: {
                Text("Input")
            } footer: {
                Text("Enable button swap for Japanese-style controls where ○ is confirm.")
            }

            #if os(iOS)
            // Touch Controller Section (iOS only)
            Section {
                Toggle("Touch Controller", isOn: $store.streamSettings.isTouchControllerEnabled)

                if store.streamSettings.isTouchControllerEnabled {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text(String(format: "%.0f%%", store.streamSettings.touchControllerOpacity * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $store.streamSettings.touchControllerOpacity,
                            in: 0.3...1.0,
                            step: 0.1
                        )
                        .tint(Color.chiakiPurple)
                    }
                }
            } header: {
                Text("Touch Controller")
            } footer: {
                Text("Show virtual controller buttons on screen when no physical controller is connected.")
            }
            #endif
        }
        .navigationTitle("Controller")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func controllerIcon(for controller: ControllerInfo) -> String {
        if controller.isDualSense || controller.isDualShock {
            return "playstation.logo"
        } else if controller.productCategory.lowercased().contains("xbox") {
            return "xbox.logo"
        }
        return "gamecontroller.fill"
    }
}

#Preview {
    NavigationStack {
        ControllerSettingsView()
            .environment(SettingsStore())
            .environment(NavigationManager())
    }
}
