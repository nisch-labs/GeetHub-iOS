import Foundation
import Security

/// One saved server. `label` is the user-facing name (defaults to the URL
/// host); `id` is stable so we can identify a server across relaunches even
/// if the label or URL changes.
public struct SavedServer: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var label: String
    public var credentials: SubsonicCredentials

    public init(id: String = UUID().uuidString, label: String, credentials: SubsonicCredentials) {
        self.id = id
        self.label = label
        self.credentials = credentials
    }
    // Hashable/Equatable on id — credentials aren't Hashable and the id is
    // stable and unique per server, so that's the identity that matters.
    public static func == (lhs: SavedServer, rhs: SavedServer) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The list of all saved servers plus which one is currently active. Stored
/// as a single JSON blob in the Keychain under a dedicated account key so
/// the legacy single-server value can be migrated on first launch.
public struct SavedServers: Codable, Sendable {
    public var activeId: String?
    public var servers: [SavedServer]

    public init(activeId: String? = nil, servers: [SavedServer] = []) {
        self.activeId = activeId
        self.servers = servers
    }

    public var active: SavedServer? {
        activeId.flatMap { id in servers.first { $0.id == id } }
    }
}

/// Where the server login (URL + username + password) is persisted between
/// launches. Supports one-or-more servers, with a designated active one; the
/// legacy single-server ``save/load/clear`` methods remain for backward-compat
/// and are the source of the one-time migration into the multi-server envelope.
public protocol CredentialStore: Sendable {
    // Legacy single-server API (kept for compat + migration).
    func save(_ credentials: SubsonicCredentials) throws
    func load() throws -> SubsonicCredentials?
    func clear() throws

    // Multi-server API.
    func loadServers() throws -> SavedServers
    func saveServers(_ servers: SavedServers) throws
}

public enum CredentialStoreError: Error, Sendable {
    case keychain(OSStatus)
    case decodeFailed
}

/// Secure, on-device credential storage in the iOS/macOS Keychain.
public struct KeychainCredentialStore: CredentialStore {
    let service: String
    let account: String          // legacy single-server blob
    let serversAccount: String   // multi-server envelope

    public init(service: String = "com.nixsocket.geethub",
                account: String = "subsonic-credentials",
                serversAccount: String = "subsonic-servers") {
        self.service = service
        self.account = account
        self.serversAccount = serversAccount
    }

    private func query(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    // MARK: Legacy single-server

    public func save(_ credentials: SubsonicCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try storeRaw(data, account: account)
    }

    public func load() throws -> SubsonicCredentials? {
        guard let data = try loadRaw(account: account) else { return nil }
        return try JSONDecoder().decode(SubsonicCredentials.self, from: data)
    }

    public func clear() throws {
        try deleteRaw(account: account)
        try deleteRaw(account: serversAccount)
    }

    // MARK: Multi-server

    public func loadServers() throws -> SavedServers {
        if let data = try loadRaw(account: serversAccount) {
            return try JSONDecoder().decode(SavedServers.self, from: data)
        }
        // One-time migration: if the legacy single-server credential exists
        // but we have no multi-server envelope yet, promote it into one.
        if let legacy = try load() {
            let migrated = SavedServer(label: legacy.baseURL.host ?? "Server",
                                       credentials: legacy)
            let env = SavedServers(activeId: migrated.id, servers: [migrated])
            try saveServers(env)
            return env
        }
        return SavedServers()
    }

    public func saveServers(_ servers: SavedServers) throws {
        let data = try JSONEncoder().encode(servers)
        try storeRaw(data, account: serversAccount)
    }

    // MARK: Keychain helpers

    private func loadRaw(account: String) throws -> Data? {
        var q = query(for: account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.keychain(status) }
        guard let data = item as? Data else { throw CredentialStoreError.decodeFailed }
        return data
    }

    private func storeRaw(_ data: Data, account: String) throws {
        SecItemDelete(query(for: account) as CFDictionary)
        var add = query(for: account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialStoreError.keychain(status) }
    }

    private func deleteRaw(account: String) throws {
        let status = SecItemDelete(query(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }
}

/// In-memory store for tests and SwiftUI previews (no Keychain entitlement).
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SubsonicCredentials?
    private var envelope: SavedServers = SavedServers()

    public init(_ initial: SubsonicCredentials? = nil) { stored = initial }

    public func save(_ credentials: SubsonicCredentials) throws {
        lock.lock(); defer { lock.unlock() }; stored = credentials
    }
    public func load() throws -> SubsonicCredentials? {
        lock.lock(); defer { lock.unlock() }; return stored
    }
    public func clear() throws {
        lock.lock(); defer { lock.unlock() }
        stored = nil
        envelope = SavedServers()
    }
    public func loadServers() throws -> SavedServers {
        lock.lock(); defer { lock.unlock() }
        if !envelope.servers.isEmpty || envelope.activeId != nil { return envelope }
        if let legacy = stored {
            let migrated = SavedServer(label: legacy.baseURL.host ?? "Server", credentials: legacy)
            envelope = SavedServers(activeId: migrated.id, servers: [migrated])
        }
        return envelope
    }
    public func saveServers(_ servers: SavedServers) throws {
        lock.lock(); defer { lock.unlock() }; envelope = servers
    }
}
