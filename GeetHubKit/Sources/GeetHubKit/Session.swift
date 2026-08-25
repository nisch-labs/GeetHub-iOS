import Foundation
import Observation

/// The app's connection/login state — drives the login screen vs the library.
///
/// Multi-server aware: at any time the user can be signed into one of many
/// saved servers. The active server's credentials back ``client``; the full
/// list lives in ``servers``. Add / switch / edit / remove all go through the
/// backing ``CredentialStore``.
@MainActor
@Observable
public final class Session {
    public enum State: Equatable, Sendable {
        case signedOut
        case connecting
        case connected
        case failed(String)
    }

    public private(set) var state: State = .signedOut
    public private(set) var client: SubsonicClient?
    public private(set) var servers: [SavedServer] = []
    public private(set) var activeId: String?

    private let store: CredentialStore

    public init(store: CredentialStore = KeychainCredentialStore()) {
        self.store = store
    }

    public var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    public var activeServer: SavedServer? {
        activeId.flatMap { id in servers.first { $0.id == id } }
    }

    // MARK: Lifecycle

    /// Load previously-saved servers on launch (no network — trusts the saved
    /// credentials; a failed request later can bounce back to the login screen).
    public func restore() {
        let env = (try? store.loadServers()) ?? SavedServers()
        servers = env.servers
        activeId = env.activeId
        if let active = env.active {
            client = SubsonicClient(credentials: active.credentials)
            state = .connected
        }
    }

    // MARK: Add / connect

    /// Validate + save a new server, and switch to it. Returns true on success.
    @discardableResult
    public func connect(urlString: String, username: String, password: String,
                        clientName: String = "GeetHub", label: String? = nil) async -> Bool {
        guard let url = Self.normalizeURL(urlString) else {
            state = .failed("That doesn't look like a valid server URL.")
            return false
        }
        state = .connecting
        let creds = SubsonicCredentials(baseURL: url, username: username,
                                        password: password, clientName: clientName)
        let client = SubsonicClient(credentials: creds)
        do {
            try await client.ping()
            let server = SavedServer(label: label ?? url.host ?? "Server", credentials: creds)
            var env = (try? store.loadServers()) ?? SavedServers()
            env.servers.append(server)
            env.activeId = server.id
            try? store.saveServers(env)
            servers = env.servers
            activeId = env.activeId
            self.client = client
            state = .connected
            return true
        } catch {
            state = .failed(Self.describe(error))
            return false
        }
    }

    // MARK: Switch

    /// Activate an already-saved server. No network — trusts saved credentials.
    public func switchServer(id: String) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        client = SubsonicClient(credentials: server.credentials)
        activeId = id
        state = .connected
        persist()
    }

    // MARK: Edit

    /// Update a saved server's label / URL / credentials. Pings to validate.
    /// If the edited server is currently active, the live client is swapped.
    @discardableResult
    public func updateServer(id: String, label: String, urlString: String,
                             username: String, password: String,
                             clientName: String = "GeetHub") async -> Bool {
        guard let url = Self.normalizeURL(urlString) else { return false }
        let creds = SubsonicCredentials(baseURL: url, username: username,
                                        password: password, clientName: clientName)
        let newClient = SubsonicClient(credentials: creds)
        do {
            try await newClient.ping()
            guard let idx = servers.firstIndex(where: { $0.id == id }) else { return false }
            servers[idx].label = label.isEmpty ? (url.host ?? "Server") : label
            servers[idx].credentials = creds
            if activeId == id { client = newClient }
            persist()
            return true
        } catch {
            return false
        }
    }

    // MARK: Remove

    /// Remove a saved server. If it was active, either switch to the first
    /// remaining server or sign out entirely if none are left.
    public func removeServer(id: String) {
        servers.removeAll { $0.id == id }
        if activeId == id {
            activeId = servers.first?.id
            if let next = servers.first {
                client = SubsonicClient(credentials: next.credentials)
                state = .connected
            } else {
                client = nil
                state = .signedOut
            }
        }
        persist()
    }

    /// Full sign-out — clears every saved server and drops the active client.
    public func signOut() {
        try? store.clear()
        servers = []
        activeId = nil
        client = nil
        state = .signedOut
    }

    // MARK: - Helpers

    private func persist() {
        try? store.saveServers(SavedServers(activeId: activeId, servers: servers))
    }

    nonisolated static func normalizeURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s), url.host != nil else { return nil }
        return url
    }

    nonisolated static func describe(_ error: Error) -> String {
        if let apiError = error as? SubsonicAPIError {
            return apiError.message ?? "Server rejected the login (code \(apiError.code))."
        }
        if error is SubsonicClientError { return "Couldn't reach the server." }
        return (error as NSError).localizedDescription
    }
}
