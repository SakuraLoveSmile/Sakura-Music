import SwiftUI
import SubsonicKit

public struct AlbumDetailView: View {
    public let album: Album
    public var serverStore: ServerStore
    public var playerService: AudioPlayerService

    @State private var fullAlbum: Album?
    @State private var isLoading: Bool = true

    public init(album: Album, serverStore: ServerStore, playerService: AudioPlayerService) {
        self.album = album
        self.serverStore = serverStore
        self.playerService = playerService
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .bottom, spacing: 24) {
                    Group {
                        if let coverArt = album.coverArt, let client = serverStore.activeClient, let url = client.coverArtUrl(id: coverArt, size: 400) {
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
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("專輯")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(album.displayTitle)
                            .font(.system(size: 28, weight: .bold))
                            .lineLimit(2)

                        Text(album.artist ?? "未知歌手")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)

                        HStack(spacing: 8) {
                            if let year = album.year {
                                Text(String(year))
                            }
                            if let songCount = fullAlbum?.song?.count ?? album.songCount {
                                Text("• \(songCount) 首曲目")
                            }
                            if let duration = fullAlbum?.duration ?? album.duration, duration > 0 {
                                Text("• \(formatDuration(duration))")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: playAll) {
                                Label("播放全部", systemImage: "play.fill")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button(action: shuffleAll) {
                                Label("隨機播放", systemImage: "shuffle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Songs Table / List
                if isLoading {
                    ProgressView("载入曲目列表中...")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let songs = fullAlbum?.song, !songs.isEmpty {
                    VStack(spacing: 0) {
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
                    }
                    .padding(.horizontal, 16)
                } else {
                    Text("暂无曲目数据")
                        .foregroundStyle(.secondary)
                        .padding(24)
                }

                Spacer(minLength: 80)
            }
        }
        .task(id: album.id) {
            await loadAlbumDetails()
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.2))
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
        }
    }

    private func loadAlbumDetails() async {
        guard let client = serverStore.activeClient else { return }
        isLoading = true
        if let detail = try? await client.getAlbum(id: album.id) {
            self.fullAlbum = detail
        }
        self.isLoading = false
    }

    private func playAll() {
        guard let client = serverStore.activeClient, let songs = fullAlbum?.song, let first = songs.first else { return }
        playerService.play(song: first, in: songs, client: client)
    }

    private func shuffleAll() {
        guard let client = serverStore.activeClient, let songs = fullAlbum?.song, !songs.isEmpty else { return }
        let shuffled = songs.shuffled()
        playerService.play(song: shuffled[0], in: shuffled, client: client)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let hours = mins / 60
        if hours > 0 {
            return "\(hours) 小时 \(mins % 60) 分钟"
        }
        return "\(mins) 分钟"
    }
}

public struct SongRowView: View {
    public let song: Song
    public let index: Int
    public let isCurrent: Bool
    public let isPlaying: Bool
    public let onPlay: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.blue)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.primary)
                } else {
                    Text("\(song.track ?? index)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isCurrent ? .blue : .secondary)
                }
            }
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: isCurrent ? .bold : .regular))
                    .foregroundStyle(isCurrent ? .blue : .primary)
                    .lineLimit(1)

                if let artist = song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let bitRate = song.bitRate, bitRate > 320 {
                Text("Hi-Res")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .foregroundStyle(.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Text(song.formattedDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
    }
}
