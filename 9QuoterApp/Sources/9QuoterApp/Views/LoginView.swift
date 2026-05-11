import SwiftUI

struct LoginView: View {
    @ObservedObject var service: RouterService
    @ObservedObject var settings: SettingsStore

    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMsg: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("9Quoter")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            VStack(spacing: 14) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("Connect to 9router")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("http://localhost:20128", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { focused = true }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit { Task { await doLogin() } }
                }

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await doLogin() }
                } label: {
                    if isLoggingIn {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || isLoggingIn)
            }
            .padding(16)
        }
        .frame(width: 280)
        .onAppear { focused = true }
    }

    private func doLogin() async {
        isLoggingIn = true
        errorMsg = nil
        service.baseURL = settings.baseURL
        do {
            try await service.login(password: password)
            settings.authToken = service.authToken
            service.startAutoRefresh(interval: settings.refreshInterval)
            password = ""
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoggingIn = false
    }
}
