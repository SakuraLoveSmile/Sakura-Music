import SwiftUI
import SubsonicKit

public struct PlaylistsView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService

    @State private var playlists: [Playlist] = []
    @State private var isLoading: Bool = false
    @State private var selectedPlaylist: Playlist? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 20)
    ]

    public init(serverStore: ServerStore, playerService: AudioPlayerService) {
        self.serverStore = serverStore
        self.playerService = playerService
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("播放列表")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                if isLoading && playlists.isEmpty {
                    ProgressView("载入歌单中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("暂无歌单")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(playlists) { playlist in
                            PlaylistCardView(playlist: playlist, client: serverStore.activeClient)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPlaylist = playlist
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 80)
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailSheet(playlist: playlist, serverStore: serverStore, playerService: playerService)
        }
        .task {
            await loadPlaylists()
        }
    }

    private func loadPlaylists() async {
        guard let client = serverStore.activeClient else { return }
        isLoading = true
        if let list = try? await client.getPlaylists() {
            self.playlists = list
        }
        self.isLoading = false
    }
}

public struct PlaylistDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let playlist: Playlist
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService

    @State private var fullPlaylist: Playlist?
    @State private var isLoading: Bool = true

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        Group {
                            if let coverArt = playlist.coverArt, let client = serverStore.activeClient, let url = client.coverArtUrl(id: coverArt, size: 280) {
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
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("播放列表")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text(playlist.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            if let count = fullPlaylist?.entry?.count ?? playlist.songCount {
                                Text("\(count) 首曲目")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let songs = fullPlaylist?.entry, let first = songs.first, let client = serverStore.activeClient {
                                Button(action: {
                                    playerService.play(song: first, in: songs, client: client)
                                }) {
                                    Label("播放全部", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider()

                    if isLoading {
                        ProgressView("载入曲目...")
                            .frame(maxWidth: .infinity)
                    } else if let songs = fullPlaylist?.entry, !songs.isEmpty {
                        ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                            SongRowView(
                                song: song,
                                index: index + 1,
                                isCurrent: playerService.currentSong?.id == song.id,
                                isPlaying: playerService.isPlaying && playerService.currentSong?.id == song.id,
                                onPlay: {
                                    if let client = serverStore.activeClient {
                                        playerService.play(song: song, in: songs, client: client)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                    } else {
                        Text("此歌单无曲目")
                            .foregroundStyle(.secondary)
                            .padding(20)
                    }
                }
            }
            .navigationTitle(playlist.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 520)
        .task {
            guard let client = serverStore.activeClient else { return }
            if let detail = try? await client.getPlaylist(id: playlist.id) {
                self.fullPlaylist = detail
            }
            self.isLoading = false
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
