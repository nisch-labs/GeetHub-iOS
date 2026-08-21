// App-target file. Server login — retro liner-note styling.
import SwiftUI
import GeetHubKit

struct LoginView: View {
    @Environment(Session.self) private var session

    @State private var urlString = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "opticaldisc")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 4) {
                Text("Geet-Hub").retro(40, .bold, tracking: 2)
                Text("Your records, anywhere")
                    .retro(11, .light, color: Theme.graphite, tracking: 3)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                field("Server", text: $urlString, secure: false, keyboard: .URL)
                line
                field("User", text: $username, secure: false, keyboard: .default)
                line
                field("Password", text: $password, secure: true, keyboard: .default)
            }
            .background(Theme.surface)
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))

            if case .failed(let message) = session.state {
                Text(message).retro(11, .regular, color: Theme.accent, tracking: 1)
                    .multilineTextAlignment(.center)
            }

            Button(action: connect) {
                Group {
                    if isConnecting { ProgressView().tint(.white) }
                    else { Text("Log in").retro(15, .semibold, color: .white, tracking: 3) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(canSubmit ? Theme.accent : Theme.graphite)
            }
            .disabled(!canSubmit || isConnecting)

            Spacer()
        }
        .padding(28)
        .paperBackground()
    }

    private var canSubmit: Bool { !urlString.isEmpty && !username.isEmpty }
    private var line: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }

    private func field(_ label: String, text: Binding<String>, secure: Bool,
                       keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Text(label).retro(11, .medium, color: Theme.graphite, tracking: 1.5)
                .frame(width: 78, alignment: .leading)
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }

    private func connect() {
        Task {
            isConnecting = true
            await session.connect(urlString: urlString, username: username, password: password)
            isConnecting = false
        }
    }
}

#Preview {
    LoginView().environment(Session(store: InMemoryCredentialStore()))
}
