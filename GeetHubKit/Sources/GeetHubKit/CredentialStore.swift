import Foundation
import Security

/// Where the server login (URL + username + password) is persisted between
/// launches — like Amperfy remembering your server.
public protocol CredentialStore: Sendable {
    func save(_ credentials: SubsonicCredentials) throws
    func load() throws -> SubsonicCredentials?
    func clear() throws
}

public enum CredentialStoreError: Error, Sendable {
    case keychain(OSStatus)
    case decodeFailed
}

/// Secure, on-device credential storage in the iOS/macOS Keychain.
public struct KeychainCredentialStore: CredentialStore {
    let service: String
    let account: String

    public init(service: String = "com.nixsocket.geethub",
                account: String = "subsonic-credentials") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func save(_ credentials: SubsonicCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        SecItemDelete(baseQuery as CFDictionary)   // replace any existing
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialStoreError.keychain(status) }
    }

    public func load() throws -> SubsonicCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.keychain(status) }
        guard let data = item as? Data else { throw CredentialStoreError.decodeFailed }
        return try JSONDecoder().decode(SubsonicCredentials.self, from: data)
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }
}

/// In-memory store for tests and SwiftUI previews (no Keychain entitlement).
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SubsonicCredentials?

    public init(_ initial: SubsonicCredentials? = nil) { stored = initial }

    public func save(_ credentials: SubsonicCredentials) throws {
        lock.lock(); defer { lock.unlock() }; stored = credentials
    }
    public func load() throws -> SubsonicCredentials? {
        lock.lock(); defer { lock.unlock() }; return stored
    }
    public func clear() throws {
        lock.lock(); defer { lock.unlock() }; stored = nil
    }
}
