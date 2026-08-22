import SwiftUI
import SubsonicKit

public struct AlbumsView: View {
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService
    public var onSelectAlbum: (Album) -> Void

    @State private var albums: [Album] = []
    @State private var sortType: String = "newest"
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var offset: Int = 0

    private let sortOptions = [
        ("newest", "最新加入"),
        ("frequent", "最常播放"),
        ("recent", "最近播放"),
        ("alphabeticalByName", "按名称"),
        ("alphabeticalByArtist", "按歌手")
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
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

    public var filteredAlbums: [Album] {
        if searchText.isEmpty { return albums }
        return albums.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            ($0.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Filter Picker
                HStack {
                    Text("所有专辑")
                        .font(.system(size: 28, weight: .bold))

                    Spacer()

                    Picker("排序", selection: $sortType) {
                        ForEach(sortOptions, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Grid
                if isLoading && albums.isEmpty {
                    ProgressView("载入专辑库中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if filteredAlbums.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "暂无专辑" : "未找到相符专辑")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(filteredAlbums) { album in
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

                Spacer(minLength: 80)
            }
        }
        .searchable(text: $searchText, prompt: "搜尋專輯或歌手")
        .task(id: sortType) {
            await loadAlbums()
        }
    }

    private func loadAlbums() async {
        guard let client = serverStore.activeClient else { return }
        isLoading = true
        if let list = try? await client.getAlbumList(type: sortType, size: 100, offset: 0) {
            self.albums = list
        }
        self.isLoading = false
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
