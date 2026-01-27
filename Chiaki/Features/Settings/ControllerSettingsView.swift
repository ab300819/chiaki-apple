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
                            .foregroundStyle(.secondary)
                        Text(L10n.Settings.Controller.noControllers)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(controllers) { controller in
                        HStack {
                            Image(systemName: controllerIcon(for: controller))
                                .foregroundStyle(controller.isActive ? Color.chiakiPurple : .secondary)
                            VStack(alignment: .leading) {
                                Text(controller.name)
                                    .fontWeight(controller.isActive ? .semibold : .regular)
                                Text(controller.productCategory)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if controller.isActive {
                                Text(String(localized: "settings.controller.active"))
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.chiakiPurple)
                                    .clipShape(.rect(cornerRadius: 4))
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.Settings.Controller.connectedControllers)
            }

            // Feedback Section
            Section {
                Toggle(String(localized: "settings.controller.hapticFeedback"), isOn: $store.streamSettings.hapticFeedbackEnabled)
                Toggle(String(localized: "settings.controller.motionControls"), isOn: $store.streamSettings.motionControlsEnabled)
            } header: {
                Text(L10n.Settings.Controller.feedback)
            } footer: {
                Text(L10n.Settings.Controller.feedbackDescription)
            }

            // Input Settings Section
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(String(localized: "settings.controller.stickDeadzone"))
                        Spacer()
                        Text(String(format: "%.0f%%", store.streamSettings.stickDeadzone * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $store.streamSettings.stickDeadzone,
                        in: 0...0.3,
                        step: 0.01
                    )
                    .tint(Color.chiakiPurple)
                }

                Toggle(String(localized: "settings.controller.swapCrossCircle"), isOn: $store.streamSettings.swapCrossCircle)
            } header: {
                Text(L10n.Settings.Controller.input)
            }

            #if os(iOS)
            // Touch Controller Section (iOS only)
            Section {
                Toggle(String(localized: "settings.controller.touchController"), isOn: $store.streamSettings.isTouchControllerEnabled)

                if store.streamSettings.isTouchControllerEnabled {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(String(localized: "settings.controller.touchControllerOpacity"))
                            Spacer()
                            Text(String(format: "%.0f%%", store.streamSettings.touchControllerOpacity * 100))
                                .foregroundStyle(.secondary)
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
                Text(String(localized: "settings.controller.touchController"))
            }
            #endif

            #if os(macOS)
            // Keyboard Mapping Section (macOS only)
            Section {
                NavigationLink {
                    KeyboardMappingView()
                } label: {
                    HStack {
                        Label(L10n.Settings.Keyboard.title, systemImage: "keyboard")
                        Spacer()
                        if store.keyboardInputEnabled {
                            Text(String(localized: "settings.controller.enabled"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(L10n.Nav.keyboard)
            }
            #endif
        }
        .navigationTitle(L10n.Nav.controller)
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
