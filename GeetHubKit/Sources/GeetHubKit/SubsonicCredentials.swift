import Foundation
import CryptoKit

/// Connection details + Subsonic token auth (salted MD5 — the standard
/// `u`/`t`/`s` scheme, same as Amperfy). The password is never sent in the
/// clear; each request uses a fresh salt.
public struct SubsonicCredentials: Sendable, Equatable, Codable {
    public let baseURL: URL
    public let username: String
    public let password: String
    public let clientName: String
    public let apiVersion: String

    public init(
        baseURL: URL,
        username: String,
        password: String,
        clientName: String = "GeetHub",
        apiVersion: String = "1.16.1"
    ) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.clientName = clientName
        self.apiVersion = apiVersion
    }

    /// The common auth/query items every Subsonic request carries.
    /// A random salt is generated per call.
    func authQueryItems(salt: String? = nil) -> [URLQueryItem] {
        let s = salt ?? Self.randomSalt()
        return [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: Self.token(password: password, salt: s)),
            URLQueryItem(name: "s", value: s),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "c", value: clientName),
            URLQueryItem(name: "f", value: "json"),
        ]
    }

    /// token = md5(password + salt), lowercase hex.
    static func token(password: String, salt: String) -> String {
        let digest = Insecure.MD5.hash(data: Data((password + salt).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func randomSalt(length: Int = 12) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var salt = ""
        for _ in 0..<length {
            salt.append(chars.randomElement()!)
        }
        return salt
    }
}
