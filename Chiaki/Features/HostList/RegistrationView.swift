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
    
    init(hostStore: HostStore, initialAddress: String = "") {
        let vm = RegistrationViewModel(hostStore: hostStore)
        vm.hostAddress = initialAddress
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Console Information") {
                    Picker("Console Type", selection: $viewModel.isPS5) {
                        Text("PlayStation 5").tag(true)
                        Text("PlayStation 4").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("IP Address", text: $viewModel.hostAddress)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                Section("Credentials") {
                    TextField("PIN (8 digits)", text: $viewModel.pin)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: viewModel.pin) { _, newValue in
                            if newValue.count > 8 {
                                viewModel.pin = String(newValue.prefix(8))
                            }
                        }
                    
                    TextField("PSN Account ID (Optional)", text: $viewModel.psnAccountId)
                        .autocorrectionDisabled()
                        #if os(iOS) || os(tvOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
                
                Section {
                    Button(action: viewModel.startRegistration) {
                        HStack {
                            Text("Register")
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
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if case .success = viewModel.state {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Registration Successful!")
                        }
                    }
                }
            }
            .navigationTitle("Register Console")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelRegistration()
                        dismiss()
                    }
                }
                
                if case .success = viewModel.state {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RegistrationView(hostStore: HostStore())
        .environment(SettingsStore())
        .environment(NavigationManager())
}
