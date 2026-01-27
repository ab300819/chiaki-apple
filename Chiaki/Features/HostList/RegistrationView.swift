// SPDX-License-Identifier: AGPL-3.0-only
//
// RegistrationView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// UI for the host registration (pairing) process

import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: RegistrationViewModel

    init(hostManager: HostManager, initialAddress: String = "") {
        let vm = RegistrationViewModel(hostManager: hostManager)
        vm.hostAddress = initialAddress
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "addHost.consoleType"), selection: $viewModel.isPS5) {
                        Text(String(localized: "addHost.playstation5")).tag(true)
                        Text(String(localized: "addHost.playstation4")).tag(false)
                    }
                    .pickerStyle(.segmented)

                    TextField(String(localized: "addHost.address"), text: $viewModel.hostAddress)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Section {
                    TextField(String(localized: "registration.pinPlaceholder"), text: $viewModel.pin)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: viewModel.pin) { _, newValue in
                            if newValue.count > 8 {
                                viewModel.pin = String(newValue.prefix(8))
                            }
                        }

                    TextField(String(localized: "psnLogin.accountIdPlaceholder"), text: $viewModel.psnAccountId)
                        .autocorrectionDisabled()
                        #if os(iOS) || os(tvOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section {
                    Button(action: viewModel.startRegistration) {
                        HStack {
                            Text(String(localized: "registration.register"))
                            if viewModel.state == .registering {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.state == .registering || viewModel.hostAddress.isEmpty || viewModel.pin.count < 8)
                }

                if case .error(let message) = viewModel.state {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if case .success = viewModel.state {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(String(localized: "registration.success"))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "registration.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        viewModel.cancelRegistration()
                        dismiss()
                    }
                }

                if case .success = viewModel.state {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.done) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RegistrationView(hostManager: HostManager())
        .environment(SettingsStore())
        .environment(NavigationManager())
}
