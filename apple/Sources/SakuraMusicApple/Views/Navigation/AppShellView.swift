import SwiftUI
import SubsonicKit

public enum NavigationItem: String, CaseIterable, Identifiable {
    case home = "首页"
    case albums = "专辑"
    case artists = "歌手"
    case playlists = "歌单"
    case search = "搜索"
    case settings = "设置"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .albums: return "square.stack.fill"
        case .artists: return "music.mic"
        case .playlists: return "music.note.list"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct AppShellView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService
    public var onSwitchToWelcome: () -> Void

    @State private var selectedItem: NavigationItem = .home
    @State private var selectedAlbum: Album? = nil
    @State private var navigationPath = NavigationPath()

    public init(
        serverStore: ServerStore,
        playerService: AudioPlayerService,
        onSwitchToWelcome: @escaping () -> Void
    ) {
        self.serverStore = serverStore
        self.playerService = playerService
        self.onSwitchToWelcome = onSwitchToWelcome
    }

    public var body: some View {
        #if os(macOS)
        macOSSplitView
            .sheet(isPresented: Binding(
                get: { playerService.showFullPlayer },
                set: { playerService.showFullPlayer = $0 }
            )) {
                FullPlayerView(playerService: playerService, client: serverStore.activeClient)
            }
        #else
        iOSTabView
            .sheet(isPresented: Binding(
                get: { playerService.showFullPlayer },
                set: { playerService.showFullPlayer = $0 }
            )) {
                FullPlayerView(playerService: playerService, client: serverStore.activeClient)
            }
        #endif
    }

    // MARK: - macOS Navigation Split View
    #if os(macOS)
    @ViewBuilder
    private var macOSSplitView: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Server quick header badge
                if let active = serverStore.activeServer {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14, weight: .semibold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(active.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Text(active.protocolType)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: onSwitchToWelcome) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("切換伺服器")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                }

                Divider()

                // Sidebar Navigation Items
                List(selection: $selectedItem) {
                    Section("音乐资料库") {
                        ForEach([NavigationItem.home, .albums, .artists, .playlists], id: \.self) { item in
                            Label(item.rawValue, systemImage: item.iconName)
                                .tag(item)
                        }
                    }

                    Section("探索与工具") {
                        ForEach([NavigationItem.search, .settings], id: \.self) { item in
                            Label(item.rawValue, systemImage: item.iconName)
                                .tag(item)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    detailContentView(for: selectedItem)
                        .navigationDestination(for: Album.self) { album in
                            AlbumDetailView(album: album, serverStore: serverStore, playerService: playerService)
                        }
                }

                // Mini Player overlay
                MiniPlayerView(playerService: playerService, client: serverStore.activeClient)
            }
        }
    }
    #endif

    // MARK: - iOS Tab View
    @ViewBuilder
    private var iOSTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedItem) {
                NavigationStack {
                    HomeView(
                        serverStore: serverStore,
                        playerService: playerService,
                        onSelectAlbum: { album in selectedAlbum = album }
                    )
                    .navigationDestination(item: $selectedAlbum) { album in
                        AlbumDetailView(album: album, serverStore: serverStore, playerService: playerService)
                    }
                }
                .tabItem {
                    Label(NavigationItem.home.rawValue, systemImage: NavigationItem.home.iconName)
                }
                .tag(NavigationItem.home)

                NavigationStack {
                    AlbumsView(
                        serverStore: serverStore,
                        playerService: playerService,
                        onSelectAlbum: { album in selectedAlbum = album }
                    )
                    .navigationDestination(item: $selectedAlbum) { album in
                        AlbumDetailView(album: album, serverStore: serverStore, playerService: playerService)
                    }
                }
                .tabItem {
                    Label(NavigationItem.albums.rawValue, systemImage: NavigationItem.albums.iconName)
                }
                .tag(NavigationItem.albums)

                NavigationStack {
                    ArtistsView(
                        serverStore: serverStore,
                        playerService: playerService,
                        onSelectAlbum: { album in selectedAlbum = album }
                    )
                    .navigationDestination(item: $selectedAlbum) { album in
                        AlbumDetailView(album: album, serverStore: serverStore, playerService: playerService)
                    }
                }
                .tabItem {
                    Label(NavigationItem.artists.rawValue, systemImage: NavigationItem.artists.iconName)
                }
                .tag(NavigationItem.artists)

                NavigationStack {
                    PlaylistsView(serverStore: serverStore, playerService: playerService)
                }
                .tabItem {
                    Label(NavigationItem.playlists.rawValue, systemImage: NavigationItem.playlists.iconName)
                }
                .tag(NavigationItem.playlists)

                NavigationStack {
                    SearchView(
                        serverStore: serverStore,
                        playerService: playerService,
                        onSelectAlbum: { album in selectedAlbum = album }
                    )
                    .navigationDestination(item: $selectedAlbum) { album in
                        AlbumDetailView(album: album, serverStore: serverStore, playerService: playerService)
                    }
                }
                .tabItem {
                    Label(NavigationItem.search.rawValue, systemImage: NavigationItem.search.iconName)
                }
                .tag(NavigationItem.search)

                NavigationStack {
                    SettingsView(serverStore: serverStore, onSwitchToWelcome: onSwitchToWelcome)
                }
                .tabItem {
                    Label(NavigationItem.settings.rawValue, systemImage: NavigationItem.settings.iconName)
                }
                .tag(NavigationItem.settings)
            }

            MiniPlayerView(playerService: playerService, client: serverStore.activeClient)
                .padding(.bottom, 48)
        }
    }

    @ViewBuilder
    private func detailContentView(for item: NavigationItem) -> some View {
        switch item {
        case .home:
            HomeView(
                serverStore: serverStore,
                playerService: playerService,
                onSelectAlbum: { album in navigationPath.append(album) }
            )
        case .albums:
            AlbumsView(
                serverStore: serverStore,
                playerService: playerService,
                onSelectAlbum: { album in navigationPath.append(album) }
            )
        case .artists:
            ArtistsView(
                serverStore: serverStore,
                playerService: playerService,
                onSelectAlbum: { album in navigationPath.append(album) }
            )
        case .playlists:
            PlaylistsView(serverStore: serverStore, playerService: playerService)
        case .search:
            SearchView(
                serverStore: serverStore,
                playerService: playerService,
                onSelectAlbum: { album in navigationPath.append(album) }
            )
        case .settings:
            SettingsView(serverStore: serverStore, onSwitchToWelcome: onSwitchToWelcome)
        }
    }
}
