import SwiftUI
import SubsonicKit

public struct ServerSidebarView: View {
    public var serverStore: ServerStore
    public var selectedTab: String
    public var onSelectTab: (String) -> Void
    public var onAddServer: () -> Void
    public var onSelectServer: (ServerConfig) -> Void

    @State private var searchText: String = ""
    @State private var serverToEdit: ServerConfig? = nil
    @State private var serverToDelete: ServerConfig? = nil

    public init(
        serverStore: ServerStore,
        selectedTab: String = "welcome",
        onSelectTab: @escaping (String) -> Void = { _ in },
        onAddServer: @escaping () -> Void,
        onSelectServer: @escaping (ServerConfig) -> Void
    ) {
        self.serverStore = serverStore
        self.selectedTab = selectedTab
        self.onSelectTab = onSelectTab
        self.onAddServer = onAddServer
        self.onSelectServer = onSelectServer
    }

    public var filteredServers: [ServerConfig] {
        if searchText.isEmpty { return serverStore.servers }
        return serverStore.servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.baseUrl.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar (Matching Screenshot)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextField("搜索", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Primary Navigation Items (e.g. 🎉 欢迎)
            VStack(spacing: 2) {
                Button(action: { onSelectTab("welcome") }) {
                    HStack(spacing: 10) {
                        Text("🎉")
                            .font(.system(size: 15))

                        Text("欢迎")
                            .font(.system(size: 13, weight: selectedTab == "welcome" ? .semibold : .regular))
                            .foregroundStyle(selectedTab == "welcome" ? .white : .primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTab == "welcome" ? Color.white.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onAddServer) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)

                        Text("添加服务器")
                            .font(.system(size: 13, weight: selectedTab == "add_server" ? .semibold : .regular))
                            .foregroundStyle(selectedTab == "add_server" ? .white : .primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTab == "add_server" ? Color.white.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Servers Section Header
            HStack {
                Text("已连接服务器")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button(action: onAddServer) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("添加服务器")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Server List
            if serverStore.servers.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "server.rack")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("尚未配置服务器")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("立即添加", action: onAddServer)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredServers) { server in
                        ServerRowView(
                            server: server,
                            isActive: serverStore.activeServerId == server.id,
                            onConnect: {
                                serverStore.selectServer(id: server.id)
                                onSelectServer(server)
                            },
                            onEdit: {
                                serverToEdit = server
                            },
                            onDelete: {
                                serverToDelete = server
                            }
                        )
                        .tag(server.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Footer info
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Keychain 硬件加密保护")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("v1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 220, idealWidth: 250)
        .sheet(item: $serverToEdit) { server in
            AddServerSheet(serverStore: serverStore, editingServer: server)
        }
        .confirmationDialog(
            "确定要删除此服务器吗？",
            isPresented: Binding(
                get: { serverToDelete != nil },
                set: { if !$0 { serverToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let serverToDelete {
                    serverStore.deleteServer(id: serverToDelete.id)
                }
                serverToDelete = nil
            }
            Button("取消", role: .cancel) {
                serverToDelete = nil
            }
        } message: {
            Text("删除后，该服务器的连接信息及安全密钥将从本机永久移除。")
        }
    }
}

public struct ServerRowView: View {
    public let server: ServerConfig
    public let isActive: Bool
    public let onConnect: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Color.blue : Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)

                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(server.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(server.baseUrl.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(server.protocolType)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onConnect()
        }
        .contextMenu {
            Button("进入服务器", action: onConnect)
            Button("编辑配置", action: onEdit)
            Divider()
            Button("删除服务器", role: .destructive, action: onDelete)
        }
    }
}

