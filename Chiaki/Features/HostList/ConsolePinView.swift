import SwiftUI

/**
 * View for setting a 4-digit PIN code for console access
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 输入数字键盘优化
 */
struct ConsolePinView: View {
    @Environment(\.dismiss) private var dismiss

    let host: ConsoleHost
    let onSave: (String?) -> Void

    @State private var pin = ""
    @State private var showPin = false
    @State private var showClearConfirmation = false
    @FocusState private var isPinFieldFocused: Bool

    private var isValidPin: Bool {
        pin.count == 4 && pin.allSatisfy { $0.isNumber }
    }

    private var hasExistingPin: Bool {
        ConsolePinManager.shared.hasPin(for: host)
    }

    var body: some View {
        NavigationStack {
            Form {
                #if os(macOS)
                Text(String(localized: "consolePin.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                #endif

                Section {
                    HStack {
                        if showPin {
                            TextField(String(localized: "consolePin.placeholder"), text: $pin)
                                .focused($isPinFieldFocused)
                        } else {
                            SecureField(String(localized: "consolePin.placeholder"), text: $pin)
                                .focused($isPinFieldFocused)
                        }

                        Button(action: { showPin.toggle() }) {
                            Image(systemName: showPin ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: pin) { _, newValue in
                        // Only allow digits and limit to 4 characters
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count <= 4 {
                            pin = filtered
                        } else {
                            pin = String(filtered.prefix(4))
                        }
                    }
                } header: {
                    Text(String(localized: "consolePin.pinDescription"))
                } footer: {
                    Text(String(localized: "consolePin.pinRequiredDescription \(host.nickname)"))
                }

                if hasExistingPin {
                    Section {
                        Button(String(localized: "consolePin.clearPin"), role: .destructive) {
                            showClearConfirmation = true
                        }
                    } footer: {
                        Text(String(localized: "consolePin.clearPinDescription"))
                    }
                }
            }
            /// @requirement F-037
            /// @satisfies AC-141 - macOS 表单分组样式
            #if os(macOS)
            .formStyle(.grouped)
            .navigationTitle("")
            #else
            .navigationTitle(String(localized: "consolePin.title"))
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        onSave(pin)
                        dismiss()
                    }
                    .disabled(!isValidPin)
                }
            }
            .confirmationDialog(
                String(localized: "consolePin.clearPinTitle"),
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "consolePin.clearPin"), role: .destructive) {
                    onSave(nil)
                    dismiss()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(String(localized: "consolePin.clearPinConfirm \(host.nickname)"))
            }
            .onAppear {
                isPinFieldFocused = true
            }
        }
    }
}

/**
 * View for entering PIN before connecting to a protected console
 * @requirement F-022 - 手柄操控 UI/UX 优化
 * @satisfies AC-067 - PIN 输入数字键盘优化
 */
struct ConsolePinEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let host: ConsoleHost
    let onVerified: () -> Void
    var onCancel: (() -> Void)?

    @State private var pin = ""
    @State private var showPin = false
    @State private var showError = false
    @State private var attempts = 0
    @State private var useNumPad = false
    @FocusState private var isPinFieldFocused: Bool

    private let maxAttempts = 5

    private var isValidFormat: Bool {
        pin.count == 4 && pin.allSatisfy { $0.isNumber }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text(String(localized: "consolePin.enterPin \(host.nickname)"))
                    .font(.headline)

                #if os(tvOS)
                // tvOS: Always use gamepad-friendly numpad
                numPadInputSection
                #else
                // iOS/macOS: Allow switching between keyboard and numpad
                if useNumPad {
                    numPadInputSection
                } else {
                    textFieldInputSection
                }
                #endif

                if showError {
                    Text(String(localized: "consolePin.incorrectPin \(maxAttempts - attempts)"))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                }

                #if !os(tvOS)
                // Show input method toggle on non-tvOS platforms
                Button(action: { useNumPad.toggle() }) {
                    Label(
                        useNumPad
                            ? String(localized: "consolePin.useKeyboard")
                            : String(localized: "consolePin.useNumPad"),
                        systemImage: useNumPad ? "keyboard" : "number.square"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                #endif

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "consolePin.pinRequired"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        onCancel?()
                        dismiss()
                    }
                }
            }
            .onAppear {
                #if os(tvOS)
                useNumPad = true
                #else
                isPinFieldFocused = true
                #endif
            }
            .onChange(of: pin) { _, _ in
                showError = false
            }
        }
    }

    // MARK: - Input Sections

    @ViewBuilder
    private var numPadInputSection: some View {
        VStack(spacing: 20) {
            // PIN display with show/hide toggle
            HStack {
                PINDisplay(value: pin, maxLength: 4, showValue: showPin)

                Button(action: { showPin.toggle() }) {
                    Image(systemName: showPin ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Gamepad numpad
            GamepadNumPad(value: $pin, maxLength: 4) { _ in
                verifyPin()
            }
        }
    }

    @ViewBuilder
    private var textFieldInputSection: some View {
        VStack(spacing: 8) {
            HStack {
                if showPin {
                    TextField(String(localized: "consolePin.placeholder"), text: $pin)
                        .focused($isPinFieldFocused)
                } else {
                    SecureField(String(localized: "consolePin.placeholder"), text: $pin)
                        .focused($isPinFieldFocused)
                }

                Button(action: { showPin.toggle() }) {
                    Image(systemName: showPin ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(.title2.monospaced())
            .multilineTextAlignment(.center)
            .padding()
            #if os(iOS)
            .background(Color(.secondarySystemBackground))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .clipShape(.rect(cornerRadius: 12))
            .frame(maxWidth: 200)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onChange(of: pin) { _, newValue in
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count <= 4 {
                    pin = filtered
                } else {
                    pin = String(filtered.prefix(4))
                }
            }
            .onSubmit {
                if isValidFormat {
                    verifyPin()
                }
            }

            Button(action: verifyPin) {
                Text(String(localized: "consolePin.connect"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidFormat ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(!isValidFormat)
            .frame(maxWidth: 200)
        }
    }

    // MARK: - Actions

    private func verifyPin() {
        if ConsolePinManager.shared.verifyPin(pin, for: host) {
            onVerified()
            dismiss()
        } else {
            attempts += 1
            showError = true
            pin = ""

            if attempts >= maxAttempts {
                onCancel?()
                dismiss()
            }
        }
    }
}

#Preview("Set PIN") {
    ConsolePinView(host: ConsoleHost(nickname: "PS5", address: "192.168.1.100")) { _ in }
}

#Preview("Enter PIN") {
    ConsolePinEntryView(host: ConsoleHost(nickname: "PS5", address: "192.168.1.100")) {}
}
