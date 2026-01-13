import SwiftUI

struct AddHostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HostListViewModel
    
    @State private var nickname = ""
    @State private var address = ""
    @State private var isPS5 = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Host Details") {
                    TextField("Nickname", text: $nickname)
                    TextField("IP Address", text: $address)
                        .keyboardType(.numbersAndPunctuation)
                    Picker("Console Type", selection: $isPS5) {
                        Text("PS5").tag(true)
                        Text("PS4").tag(false)
                    }
                }
            }
            .navigationTitle("Add Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let host = ConsoleHost(
                            nickname: nickname.isEmpty ? "PlayStation" : nickname,
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
