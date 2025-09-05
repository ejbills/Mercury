import SwiftUI
import Defaults

struct ProxySettingsView: View {
    @Default(.proxyEnabled) private var proxyEnabled
    @Default(.proxyType) private var proxyType
    @Default(.proxyHost) private var proxyHost
    @Default(.proxyPort) private var proxyPort
    @Default(.proxyUsername) private var proxyUsername
    @Default(.proxyPassword) private var proxyPassword

    @State private var tempHost: String = ""
    @State private var tempPort: String = ""
    @State private var testResult: (success: Bool, message: String, ipAddress: String?)? = nil
    @State private var isTestingConnection = false

    var body: some View {
        Form {
            Section("Proxy") {
                Toggle("Enable Proxy", isOn: $proxyEnabled)
                
                Picker("Type", selection: $proxyType) {
                    ForEach(ProxyType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .disabled(!proxyEnabled)

                TextField("Host", text: Binding(
                    get: { tempHost.isEmpty ? (proxyHost ?? "") : tempHost },
                    set: { tempHost = $0 }
                ))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .disabled(!proxyEnabled)

                TextField("Port", text: Binding(
                    get: { tempPort.isEmpty ? (proxyPort.flatMap { String($0) } ?? "") : tempPort },
                    set: { tempPort = $0.filter { $0.isNumber } }
                ))
                .keyboardType(.numberPad)
                .disabled(!proxyEnabled)

                TextField("Username (optional)", text: Binding(
                    get: { proxyUsername ?? "" },
                    set: { proxyUsername = $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .disabled(!proxyEnabled)

                SecureField("Password (optional)", text: Binding(
                    get: { proxyPassword ?? "" },
                    set: { proxyPassword = $0 }
                ))
                .disabled(!proxyEnabled)
            }

            Section("Connection Test") {
                Button(action: testConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(isTestingConnection)
                
                if let result = testResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                            Text(result.message)
                                .font(.subheadline)
                        }
                        
                        if let ip = result.ipAddress {
                            Text("External IP: \(ip)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("Notes") {
                Text("All app network traffic, including Reddit API and media downloads, routes through the proxy when enabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Network & Proxy")
        .onAppear {
            tempHost = proxyHost ?? ""
            tempPort = proxyPort.flatMap { String($0) } ?? ""
        }
        .onChange(of: proxyEnabled) { apply() }
        .onChange(of: proxyType) { apply() }
        .onChange(of: proxyUsername) { apply() }
        .onChange(of: proxyPassword) { apply() }
        .onChange(of: tempHost) { apply() }
        .onChange(of: tempPort) { apply() }
    }

    private func apply() {
        proxyHost = tempHost.isEmpty ? nil : tempHost
        proxyPort = Int(tempPort)
        NetworkManager.shared.applyCurrentSettings()
        // Clear test result when settings change
        testResult = nil
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            let result = await NetworkManager.shared.testConnection()
            await MainActor.run {
                testResult = result
                isTestingConnection = false
            }
        }
    }
}

