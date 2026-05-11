import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var service: RouterService
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                if service.isAuthenticated {
                    Text("Signed in")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("9router URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                TextField("http://localhost:20128", text: $settings.baseURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                SecureField("Login password", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { Task { await loginAndRefresh() } }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh interval: \(Int(settings.refreshInterval))s")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Slider(value: $settings.refreshInterval, in: 15...300, step: 15)
            }

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(message.hasPrefix("Error") ? .red.opacity(0.9) : .green.opacity(0.9))
            }

            HStack(spacing: 10) {
                Button("Logout") {
                    service.logout()
                    settings.clearToken()
                    message = "Logged out"
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.red.opacity(0.85))

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                Button {
                    Task { await loginAndRefresh() }
                } label: {
                    if isLoggingIn {
                        ProgressView().controlSize(.mini).tint(.white.opacity(0.8))
                    } else {
                        Text(password.isEmpty ? "Save" : "Login & Refresh")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.purple.opacity(0.9))
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(Color(red: 0.10, green: 0.09, blue: 0.14))
    }

    private func loginAndRefresh() async {
        isLoggingIn = true
        message = nil
        service.baseURL = settings.baseURL
        do {
            if !password.isEmpty {
                try await service.login(password: password)
                settings.authToken = service.authToken
                password = ""
            }
            service.startAutoRefresh(interval: settings.refreshInterval)
            await service.refresh()
            message = "Saved"
            dismiss()
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
        isLoggingIn = false
    }
}
