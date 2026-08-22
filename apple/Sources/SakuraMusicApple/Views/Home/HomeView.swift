import SwiftUI
import SubsonicKit

public struct HomeView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService
    public var onSelectAlbum: (Album) -> Void

    @State private var recentAlbums: [Album] = []
    @State private var frequentAlbums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    public init(
        serverStore: ServerStore,
        playerService: AudioPlayerService,
        onSelectAlbum: @escaping (Album) -> Void
    ) {
        self.serverStore = serverStore
        self.playerService = playerService
        self.onSelectAlbum = onSelectAlbum
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header Banner
                headerBanner

                if isLoading && recentAlbums.isEmpty {
                    ProgressView("载入音乐库中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorMessage {
                    errorStateView(errorMessage)
                } else {
                    // Recently Added Section
                    if !recentAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(title: "最新专辑", icon: "sparkles", count: recentAlbums.count)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(recentAlbums) { album in
                                        AlbumCardView(
                                            album: album,
                                            client: serverStore.activeClient,
                                            onTap: { onSelectAlbum(album) },
                                            onPlay: { playAlbum(album) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Recommended / Frequent Section
                    if !frequentAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(title: "随机推荐", icon: "dice.fill", count: frequentAlbums.count)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(frequentAlbums) { album in
                                        AlbumCardView(
                                            album: album,
                                            client: serverStore.activeClient,
                                            onTap: { onSelectAlbum(album) },
                                            onPlay: { playAlbum(album) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Artists Section
                    if !artists.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(title: "热门歌手", icon: "music.mic", count: artists.count)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 18) {
                                    ForEach(artists.prefix(12)) { artist in
                                        ArtistCircleView(artist: artist, client: serverStore.activeClient)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Playlists Section
                    if !playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader(title: "精选歌单", icon: "music.note.list", count: playlists.count)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(playlists) { playlist in
                                        PlaylistCardView(playlist: playlist, client: serverStore.activeClient)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.top, 16)
        }
        .task(id: serverStore.activeServerId) {
            await loadHomeData()
        }
        .refreshable {
            await loadHomeData()
        }
    }

    @ViewBuilder
    private var headerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(serverStore.activeServer?.name ?? "音乐库")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(serverStore.activeServer?.protocolType ?? "Subsonic") 服务器已连接")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { Task { await loadHomeData() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func sectionHeader(title: String, icon: String, count: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.system(size: 15, weight: .semibold))

            Text(title)
                .font(.system(size: 18, weight: .bold))

            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
            Text("无法载入首页内容")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: { Task { await loadHomeData() } })
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func loadHomeData() async {
        guard let client = serverStore.activeClient else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let newestAlbums = client.getAlbumList(type: "newest", size: 16)
            async let randomAlbums = client.getAlbumList(type: "random", size: 16)
            async let allArtists = client.getArtists()
            async let allPlaylists = client.getPlaylists()

            let (newest, random, artistsList, playlistsList) = try await (newestAlbums, randomAlbums, allArtists, allPlaylists)

            self.recentAlbums = newest
            self.frequentAlbums = random
            self.artists = artistsList
            self.playlists = playlistsList
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func playAlbum(_ album: Album) {
        guard let client = serverStore.activeClient else { return }
        Task {
            if let fullAlbum = try? await client.getAlbum(id: album.id), let songs = fullAlbum.song, let first = songs.first {
                await MainActor.run {
                    playerService.play(song: first, in: songs, client: client)
                }
            }
        }
    }
}

public struct AlbumCardView: View {
    public let album: Album
    public let client: SubsonicClient?
    public let onTap: () -> Void
    public let onPlay: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let coverArt = album.coverArt, let client, let url = client.coverArtUrl(id: coverArt, size: 280) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .empty:
                                ProgressView()
                            case .failure:
                                placeholder
                            @unknown default:
                                placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)

                // Hover Play button
                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.blue, .white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(album.artist ?? "未知歌手")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.2))
            Image(systemName: "music.note")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
        }
    }
}

public struct ArtistCircleView: View {
    public let artist: Artist
    public let client: SubsonicClient?

    public var body: some View {
        VStack(spacing: 8) {
            Group {
                if let coverArt = artist.coverArt, let client, let url = client.coverArtUrl(id: coverArt, size: 200) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            Text(artist.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 90)
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.gray.opacity(0.2))
            Image(systemName: "person.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }
}

public struct PlaylistCardView: View {
    public let playlist: Playlist
    public let client: SubsonicClient?

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let coverArt = playlist.coverArt, let client, let url = client.coverArtUrl(id: coverArt, size: 280) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let count = playlist.songCount {
                    Text("\(count) 首曲目")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
