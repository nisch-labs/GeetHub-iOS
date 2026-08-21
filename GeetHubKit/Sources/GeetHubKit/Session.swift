import Foundation
import Observation

/// The app's connection/login state — drives the login screen vs the library.
/// Validates a server the way Amperfy does: enter URL + username + password,
/// we ping the server to confirm, then remember it (Keychain) for next launch.
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

    private let store: CredentialStore

    public init(store: CredentialStore = KeychainCredentialStore()) {
        self.store = store
    }

    public var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    /// Load a previously-saved server on launch (no network — trusts the saved
    /// credentials; a failed request later can bounce back to the login screen).
    public func restore() {
        if let creds = try? store.load() {
            client = SubsonicClient(credentials: creds)
            state = .connected
        }
    }

    /// Validate + remember a server. `baseURL` accepts what the user typed
    /// (e.g. "http://100.75.88.86:4544"). Returns true on success.
    @discardableResult
    public func connect(urlString: String, username: String, password: String,
                        clientName: String = "GeetHub") async -> Bool {
        guard let url = Self.normalizeURL(urlString) else {
            state = .failed("That doesn't look like a valid server URL.")
            return false
        }
        state = .connecting
        let creds = SubsonicCredentials(baseURL: url, username: username,
                                        password: password, clientName: clientName)
        let client = SubsonicClient(credentials: creds)
        do {
            try await client.ping()             // wrong creds / unreachable throws
            try? store.save(creds)
            self.client = client
            state = .connected
            return true
        } catch {
            state = .failed(Self.describe(error))
            return false
        }
    }

    public func signOut() {
        try? store.clear()
        client = nil
        state = .signedOut
    }

    // MARK: - Helpers

    nonisolated static func normalizeURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }        // default scheme
        while s.hasSuffix("/") { s.removeLast() }           // trim trailing slash
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
