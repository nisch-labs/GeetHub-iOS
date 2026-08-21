// App-target file (SwiftUI). Add to the Xcode app target — not compiled by the
// GeetHubKit Swift Package. The login *logic* it drives (Session, Keychain,
// ping-validate) lives in GeetHubKit and is unit-tested.
import SwiftUI
import GeetHubKit

/// The server login screen — enter URL + Navidrome username + password, same as
/// Amperfy. Point it at the proxy (e.g. http://100.75.88.86:4544) or Navidrome.
struct LoginView: View {
    @Environment(Session.self) private var session

    @State private var urlString = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.house.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Geet-Hub")
                .font(.largeTitle.bold())
            Text("Sign in to your music server")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("Server URL — e.g. https://musicv2.nixsocket.com", text: $urlString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)

            if case .failed(let message) = session.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: connect) {
                if isConnecting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Log in").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConnecting || urlString.isEmpty || username.isEmpty)

            Spacer()
        }
        .padding(24)
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
    LoginView()
        .environment(Session(store: InMemoryCredentialStore()))
}
