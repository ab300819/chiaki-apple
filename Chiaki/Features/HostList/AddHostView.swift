import SwiftUI

struct AddHostView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HostListViewModel

    @State private var nickname = ""
    @State private var address = ""
    @State private var isPS5 = true

    var body: some View {
        NavigationStack {
            Form {
                /// macOS sheet 自定义标题视图
                /// @requirement F-037
                /// @satisfies AC-138 - macOS sheet 标题居中突出显示
                #if os(macOS)
                Text(String(localized: "addHost.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                #endif

                Section {
                    TextField(String(localized: "addHost.nickname"), text: $nickname)
                    TextField(String(localized: "addHost.address"), text: $address)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                    Picker(String(localized: "addHost.consoleType"), selection: $isPS5) {
                        Text(String(localized: "addHost.ps5")).tag(true)
                        Text(String(localized: "addHost.ps4")).tag(false)
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .navigationTitle("")
            #else
            .navigationTitle(String(localized: "addHost.title"))
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
                        let host = ConsoleHost(
                            nickname: nickname.isEmpty ? String(localized: "common.playstation") : nickname,
                            address: address,
                            isPS5: isPS5
                        )
                        viewModel.addHost(host)
                        dismiss()
                    }
                    .disabled(address.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddHostView(viewModel: HostListViewModel())
        .environment(SettingsStore())
        .environment(NavigationManager())
}
