import SwiftUI
import SubsonicKit

public struct ServerProtocolItem: Identifiable {
    public let id: String
    public let name: String
    public let defaultPort: String
    public let defaultPath: String

    public init(id: String, name: String, defaultPort: String = "4533", defaultPath: String = "") {
        self.id = id
        self.name = name
        self.defaultPort = defaultPort
        self.defaultPath = defaultPath
    }
}

public struct AddServerView: View {
    public var serverStore: ServerStore
    public var onBack: () -> Void
    public var onServerAdded: ((ServerConfig) -> Void)? = nil

    @State private var selectedProtocol: ServerProtocolItem? = nil
    @State private var isSearchingLAN: Bool = false

    private let protocols: [ServerProtocolItem] = [
        ServerProtocolItem(id: "navidrome", name: "Navidrome", defaultPort: "4533"),
        ServerProtocolItem(id: "subsonic", name: "Subsonic", defaultPort: "4040"),
        ServerProtocolItem(id: "plex", name: "Plex", defaultPort: "32400"),
        ServerProtocolItem(id: "jellyfin", name: "Jellyfin", defaultPort: "8096"),
        ServerProtocolItem(id: "emby", name: "Emby", defaultPort: "8096"),
        ServerProtocolItem(id: "audiostation", name: "Audio Station", defaultPort: "5000"),
        ServerProtocolItem(id: "audiobookshelf", name: "Audiobookshelf", defaultPort: "13378")
    ]

    private let gridColumns = [
        GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)
    ]

    public init(
        serverStore: ServerStore,
        onBack: @escaping () -> Void,
        onServerAdded: ((ServerConfig) -> Void)? = nil
    ) {
        self.serverStore = serverStore
        self.onBack = onBack
        self.onServerAdded = onServerAdded
    }

    public var body: some View {
        Group {
            if let proto = selectedProtocol {
                ServerConfigView(
                    serverStore: serverStore,
                    protocolItem: proto,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProtocol = nil
                        }
                    },
                    onSaveSuccess: { config in
                        selectedProtocol = nil
                        onServerAdded?(config)
                    }
                )
            } else {
                serverListView
            }
        }
    }

    private var serverListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Top Custom Navigation Bar (1:1 with user image)
                topNavigationBar

                // Section 1: 局域网探索
                VStack(alignment: .leading, spacing: 12) {
                    Text("局域网探索")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    lanDiscoveryCard
                }

                // Section 2: 手动添加
                VStack(alignment: .leading, spacing: 16) {
                    Text("手动添加")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                        ForEach(protocols) { item in
                            ProtocolCardView(item: item) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedProtocol = item
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(hex: 0x121316).ignoresSafeArea())
    }

    // MARK: - Top Navigation Bar (1:1 with user image)
    @ViewBuilder
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            // Circular Back Button
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .help("返回")

            Text("添加服务器")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            // Right utility buttons
            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: {
                    isSearchingLAN = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isSearchingLAN = false
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .rotationEffect(.degrees(isSearchingLAN ? 360 : 0))
                        .animation(isSearchingLAN ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSearchingLAN)
                }
                .buttonStyle(.plain)
                .help("刷新局域网搜索")
            }
        }
    }

    // MARK: - LAN Discovery Card
    @ViewBuilder
    private var lanDiscoveryCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x1A1B20))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )

            VStack(spacing: 10) {
                if isSearchingLAN {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.bottom, 4)
                    Text("正在搜索局域网中的音乐服务器...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    // Slash WiFi Antenna Icon
                    ZStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.white.opacity(0.35))

                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 2.5, height: 44)
                            .rotationEffect(.degrees(45))
                    }
                    .padding(.bottom, 2)

                    Text("未发现任何服务器")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("请确认设备处于同一局域网")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 38)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}

// MARK: - Protocol Card View
public struct ProtocolCardView: View {
    public let item: ServerProtocolItem
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                // Protocol Brand Icon
                Group {
                    switch item.id {
                    case "navidrome":
                        NavidromeLogoView(size: 58)
                    case "subsonic":
                        SubsonicLogoView(size: 58)
                    case "plex":
                        PlexLogoView(size: 58)
                    case "jellyfin":
                        JellyfinLogoView(size: 58)
                    case "emby":
                        EmbyLogoView(size: 58)
                    case "audiostation":
                        AudioStationLogoView(size: 58)
                    case "audiobookshelf":
                        AudiobookshelfLogoView(size: 58)
                    default:
                        Image(systemName: "server.rack")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 58, height: 58)
                .scaleEffect(isHovered ? 1.06 : 1.0)
                .animation(.spring(response: 0.25), value: isHovered)

                // Name
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.85))
                    .lineLimit(1)
            }
            .frame(width: 120, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0x1A1B20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isHovered ? Color(hex: 0x0A84FF).opacity(0.6) : Color.white.opacity(0.04),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(color: isHovered ? Color.black.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }
}

