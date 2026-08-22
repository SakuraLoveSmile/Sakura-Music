import Foundation
import CryptoKit

public struct SubsonicAuth: Sendable {
    public let username: String
    public let token: String
    public let salt: String
    public let clientName: String
    public let apiVersion: String

    public init(
        username: String,
        password: String,
        clientName: String = "SakuraMusic",
        apiVersion: String = "1.16.1"
    ) {
        self.username = username
        self.clientName = clientName
        self.apiVersion = apiVersion
        
        let generatedSalt = SubsonicAuth.generateSalt()
        self.salt = generatedSalt
        self.token = SubsonicAuth.calculateToken(password: password, salt: generatedSalt)
    }

    public static func generateSalt(length: Int = 12) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    public static func calculateToken(password: String, salt: String) -> String {
        let input = password + salt
        let digest = Insecure.MD5.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    public func queryItems() -> [URLQueryItem] {
        return [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "c", value: clientName),
            URLQueryItem(name: "f", value: "json")
        ]
    }
}
