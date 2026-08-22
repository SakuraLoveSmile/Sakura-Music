import SwiftUI
import SubsonicKit

public struct SearchView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService
    public var onSelectAlbum: (Album) -> Void

    @State private var query: String = ""
    @State private var searchResult: SearchResult3?
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false

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
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("全库搜索")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                if isSearching {
                    ProgressView("搜索中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let result = searchResult, hasSearched {
                    let songs = result.song ?? []
                    let albums = result.album ?? []
                    let artists = result.artist ?? []

                    if songs.isEmpty && albums.isEmpty && artists.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("找不到相符的歌曲、專輯或歌手")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Songs
                        if !songs.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("歌曲 (\(songs.count))")
                                    .font(.headline)
                                    .padding(.horizontal, 24)

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
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Albums
                        if !albums.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("專輯 (\(albums.count))")
                                    .font(.headline)
                                    .padding(.horizontal, 24)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(albums) { album in
                                            AlbumCardView(
                                                album: album,
                                                client: serverStore.activeClient,
                                                onTap: { onSelectAlbum(album) },
                                                onPlay: { onSelectAlbum(album) }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }

                        // Artists
                        if !artists.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("歌手 (\(artists.count))")
                                    .font(.headline)
                                    .padding(.horizontal, 24)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(artists) { artist in
                                            ArtistCircleView(artist: artist, client: serverStore.activeClient)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("輸入歌名、專輯或歌手進行搜尋")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                }

                Spacer(minLength: 80)
            }
        }
        .searchable(text: $query, prompt: "搜尋音樂庫...")
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: query) { _, newQuery in
            if newQuery.isEmpty {
                searchResult = nil
                hasSearched = false
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              let client = serverStore.activeClient else { return }
        isSearching = true
        hasSearched = true

        Task {
            if let result = try? await client.search3(query: query) {
                await MainActor.run {
                    self.searchResult = result
                    self.isSearching = false
                }
            } else {
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
}
