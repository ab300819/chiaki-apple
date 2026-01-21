// SPDX-License-Identifier: AGPL-3.0-only
//
// KeyboardMappingView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Keyboard to controller button mapping editor (macOS only)

#if os(macOS)
import SwiftUI
import Carbon.HIToolbox

struct KeyboardMappingView: View {
    @Environment(SettingsStore.self) var store
    @State private var editingButton: MappableButton?
    @State private var isListening = false

    var body: some View {
        @Bindable var store = store
        Form {
            // Enable/Disable Toggle
            Section {
                Toggle(L10n.Settings.Keyboard.enableKeyboardInput, isOn: $store.keyboardInputEnabled)
            } footer: {
                Text(L10n.Settings.Keyboard.enableDescription)
            }

            if store.keyboardInputEnabled {
                // Button mappings by category
                ForEach(MappableButton.ButtonCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(category.buttons) { button in
                            KeyboardMappingRow(
                                button: button,
                                mapping: store.keyboardMappings.mapping(for: button),
                                isEditing: editingButton == button,
                                onTap: {
                                    editingButton = button
                                    isListening = true
                                },
                                onClear: {
                                    store.keyboardMappings.setMapping(for: button, keyCode: nil, keyName: nil)
                                }
                            )
                        }
                    }
                }

                // Reset to Defaults
                Section {
                    Button(L10n.Settings.Keyboard.resetToDefaults) {
                        store.keyboardMappings = KeyboardMappings.defaultMappings
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.Settings.Keyboard.title)
        .overlay {
            if isListening, let button = editingButton {
                KeyCaptureOverlay(
                    button: button,
                    onKeyPressed: { keyCode, keyName in
                        store.keyboardMappings.setMapping(for: button, keyCode: keyCode, keyName: keyName)
                        isListening = false
                        editingButton = nil
                    },
                    onCancel: {
                        isListening = false
                        editingButton = nil
                    }
                )
            }
        }
    }
}

// MARK: - Mapping Row

private struct KeyboardMappingRow: View {
    let button: MappableButton
    let mapping: KeyboardMapping
    let isEditing: Bool
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text(button.displayName)
                .frame(minWidth: 120, alignment: .leading)

            Spacer()

            Button(action: onTap) {
                HStack {
                    if let keyName = mapping.keyName {
                        Text(keyName)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text(L10n.Settings.Keyboard.notAssigned)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(minWidth: 80)
            }
            .buttonStyle(.plain)

            if mapping.hasMapping {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.Settings.Keyboard.clearMapping)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Key Capture Overlay

private struct KeyCaptureOverlay: View {
    let button: MappableButton
    let onKeyPressed: (UInt16, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 16) {
                Text(L10n.Settings.Keyboard.pressKey)
                    .font(.headline)

                Text(button.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(L10n.Settings.Keyboard.pressKeyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(L10n.Common.cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .shadow(radius: 20)
        }
        .focusable()
        .onKeyPress { press in
            let keyCode = UInt16(press.key.character.asciiValue ?? 0)
            // Use the actual keyCode from NSEvent if available
            if let event = NSApp.currentEvent, event.type == .keyDown {
                let actualKeyCode = UInt16(event.keyCode)
                let keyName = keyNameFromCode(actualKeyCode)
                onKeyPressed(actualKeyCode, keyName)
                return .handled
            }
            return .ignored
        }
    }

    private func keyNameFromCode(_ keyCode: UInt16) -> String {
        // Map common key codes to readable names
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key \(keyCode)"
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardMappingView()
            .environment(SettingsStore())
    }
    .frame(width: 500, height: 600)
}
#endif
