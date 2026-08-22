import Foundation
import Observation
import SubsonicKit

@Observable
public final class ServerStore: @unchecked Sendable {
    public var servers: [ServerConfig] = []
    public var activeServerId: UUID? {
        didSet {
            UserDefaults.standard.set(activeServerId?.uuidString, forKey: "activeServerId")
            updateActiveClient()
        }
    }
    public private(set) var activeClient: SubsonicClient?

    public var activeServer: ServerConfig? {
        if let id = activeServerId {
            return servers.first(where: { $0.id == id })
        }
        return servers.first
    }

    private let storageKey = "com.sakuramusic.apple.saved_servers"

    public init() {
        loadServers()
        if let savedIdString = UserDefaults.standard.string(forKey: "activeServerId"),
           let uuid = UUID(uuidString: savedIdString) {
            self.activeServerId = uuid
        } else {
            self.activeServerId = servers.first?.id
        }
        updateActiveClient()
    }

    public func addServer(
        name: String,
        baseUrl: String,
        username: String,
        password: String,
        protocolType: String = "Navidrome"
    ) -> ServerConfig {
        let server = ServerConfig(
            name: name,
            baseUrl: baseUrl,
            username: username,
            protocolType: protocolType
        )
        KeychainHelper.shared.save(password: password, for: server.id.uuidString)
        servers.append(server)
        saveServers()
        activeServerId = server.id
        return server
    }

    public func updateServer(
        id: UUID,
        name: String,
        baseUrl: String,
        username: String,
        password: String?,
        protocolType: String = "Navidrome"
    ) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        var server = servers[index]
        server.name = name
        server.baseUrl = baseUrl
        server.username = username
        server.protocolType = protocolType
        servers[index] = server

        if let password, !password.isEmpty {
            KeychainHelper.shared.save(password: password, for: id.uuidString)
        }
        saveServers()
        if activeServerId == id {
            updateActiveClient()
        }
    }

    public func deleteServer(id: UUID) {
        servers.removeAll(where: { $0.id == id })
        KeychainHelper.shared.delete(for: id.uuidString)
        saveServers()
        if activeServerId == id {
            activeServerId = servers.first?.id
        }
    }

    public func selectServer(id: UUID?) {
        activeServerId = id
    }

    public func getPassword(for serverId: UUID) -> String {
        KeychainHelper.shared.getPassword(for: serverId.uuidString) ?? ""
    }

    private func updateActiveClient() {
        guard let current = activeServer else {
            activeClient = nil
            return
        }
        let password = getPassword(for: current.id)
        activeClient = SubsonicClient(
            baseUrl: current.baseUrl,
            username: current.username,
            password: password
        )
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) else {
            return
        }
        self.servers = decoded
    }
}
