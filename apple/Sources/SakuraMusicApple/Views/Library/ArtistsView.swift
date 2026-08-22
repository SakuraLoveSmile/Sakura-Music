import SwiftUI
import SubsonicKit

public struct ArtistsView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService
    public var onSelectAlbum: (Album) -> Void

    @State private var artists: [Artist] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedArtist: Artist? = nil
    @State private var artistAlbums: [Album] = []
    @State private var isLoadingAlbums: Bool = false

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20)
    ]

    public init(
        serverStore: ServerStore,
        playerService: AudioPlayerService,
        onSelectAlbum: @escaping (Album) -> Void
    ) {
        self.serverStore = serverStore
        self.playerService = playerService
        self.onSelectAlbum = onSelectAlbum
    }

    public var filteredArtists: [Artist] {
        if searchText.isEmpty { return artists }
        return artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("所有歌手")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                if isLoading && artists.isEmpty {
                    ProgressView("载入歌手中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if filteredArtists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "暂无歌手" : "未找到相符歌手")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(filteredArtists) { artist in
                            VStack(spacing: 8) {
                                Group {
                                    if let coverArt = artist.coverArt, let client = serverStore.activeClient, let url = client.coverArtUrl(id: coverArt, size: 240) {
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
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                                VStack(spacing: 2) {
                                    Text(artist.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)

                                    if let count = artist.albumCount {
                                        Text("\(count) 张专辑")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedArtist = artist
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 80)
            }
        }
        .searchable(text: $searchText, prompt: "搜索歌手")
        .sheet(item: $selectedArtist) { artist in
            ArtistDetailSheet(
                artist: artist,
                serverStore: serverStore,
                onSelectAlbum: { album in
                    selectedArtist = nil
                    onSelectAlbum(album)
                }
            )
        }
        .task {
            await loadArtists()
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.gray.opacity(0.2))
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    private func loadArtists() async {
        guard let client = serverStore.activeClient else { return }
        isLoading = true
        if let list = try? await client.getArtists() {
            self.artists = list
        }
        self.isLoading = false
    }
}

public struct ArtistDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let artist: Artist
    public var serverStore: ServerStore
    public var onSelectAlbum: (Album) -> Void

    @State private var albums: [Album] = []
    @State private var isLoading: Bool = true

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("载入中...")
                            .padding(.top, 40)
                    } else if albums.isEmpty {
                        Text("暂无此歌手的专辑")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)], spacing: 20) {
                            ForEach(albums) { album in
                                AlbumCardView(
                                    album: album,
                                    client: serverStore.activeClient,
                                    onTap: { onSelectAlbum(album) },
                                    onPlay: { onSelectAlbum(album) }
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle(artist.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
        .task {
            guard let client = serverStore.activeClient else { return }
            if let fullArtist = try? await client.getArtist(id: artist.id), let artistAlbums = fullArtist.album {
                self.albums = artistAlbums
            }
            self.isLoading = false
        }
    }
}
