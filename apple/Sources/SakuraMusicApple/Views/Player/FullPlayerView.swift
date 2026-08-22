import SwiftUI
import SubsonicKit

public struct FullPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    public var playerService: AudioPlayerService
    public var client: SubsonicClient?

    @State private var showLyrics: Bool = false
    @State private var lyrics: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var sliderValue: Double = 0

    public init(playerService: AudioPlayerService, client: SubsonicClient?) {
        self.playerService = playerService
        self.client = client
    }

    public var body: some View {
        ZStack {
            // Blurred Artwork Background
            backgroundCoverArt

            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    Button(action: { playerService.showFullPlayer = false; dismiss() }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Picker("视图模式", selection: $showLyrics) {
                        Image(systemName: "music.note").tag(false)
                        Image(systemName: "quote.bubble.fill").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    Spacer()

                    Button(action: { playerService.showQueueSheet.toggle() }) {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("播放队列")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Main Content: Artwork or Lyrics
                if showLyrics {
                    lyricsView
                        .transition(.opacity)
                } else {
                    artworkAndMetadataView
                        .transition(.opacity)
                }

                Spacer(minLength: 16)

                // Playback Controls Area
                VStack(spacing: 16) {
                    // Scrubber
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? sliderValue : playerService.currentTime },
                                set: { newValue in
                                    isDraggingSlider = true
                                    sliderValue = newValue
                                }
                            ),
                            in: 0...max(1, playerService.duration),
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    playerService.seek(to: sliderValue)
                                    isDraggingSlider = false
                                }
                            }
                        )
                        .tint(.white)

                        HStack {
                            Text(formatTime(isDraggingSlider ? sliderValue : playerService.currentTime))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))

                            Spacer()

                            Text(formatTime(playerService.duration))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 32)

                    // Control Buttons
                    HStack(spacing: 36) {
                        Button(action: { playerService.togglePlaybackMode() }) {
                            Image(systemName: playerService.playbackMode.iconName)
                                .font(.system(size: 18))
                                .foregroundStyle(playerService.playbackMode == .sequence ? .white.opacity(0.5) : .blue)
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.togglePlayPause() }) {
                            Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.showQueueSheet = true }) {
                            Image(systemName: "text.line.magnify")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(minWidth: 500, minHeight: 650)
        .sheet(isPresented: Binding(
            get: { playerService.showQueueSheet },
            set: { playerService.showQueueSheet = $0 }
        )) {
            QueueListView(playerService: playerService, client: client)
        }
        .task(id: playerService.currentSong?.id) {
            await loadLyrics()
        }
    }

    @ViewBuilder
    private var backgroundCoverArt: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let song = playerService.currentSong,
               let coverArt = song.coverArt,
               let client,
               let coverUrl = client.coverArtUrl(id: coverArt, size: 400) {
                AsyncImage(url: coverUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .opacity(0.4)
                            .scaleEffect(1.2)
                    }
                }
            }

            LinearGradient(
                colors: [.black.opacity(0.4), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var artworkAndMetadataView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large Glowing Cover
            if let song = playerService.currentSong,
               let coverArt = song.coverArt,
               let client,
               let coverUrl = client.coverArtUrl(id: coverArt, size: 600) {
                AsyncImage(url: coverUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView()
                    case .failure:
                        largeCoverPlaceholder
                    @unknown default:
                        largeCoverPlaceholder
                    }
                }
                .frame(maxWidth: 340, maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
            } else {
                largeCoverPlaceholder
                    .frame(maxWidth: 340, maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            // Song Info
            if let song = playerService.currentSong {
                VStack(spacing: 6) {
                    Text(song.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(song.artist ?? "未知歌手")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.75))

                    if let album = song.album {
                        Text(album)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    if isLoadingLyrics {
                        ProgressView("载入歌词中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if lyrics.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("纯音乐或暂无动态歌词")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(lyrics) { line in
                            let isCurrent = isCurrentLine(line)
                            Text(line.text)
                                .font(.system(size: isCurrent ? 24 : 17, weight: isCurrent ? .bold : .medium))
                                .foregroundStyle(isCurrent ? .white : .white.opacity(0.4))
                                .scaleEffect(isCurrent ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3), value: isCurrent)
                                .id(line.id)
                                .onTapGesture {
                                    playerService.seek(to: line.timestamp)
                                }
                        }
                    }
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: playerService.currentTime) { _, newTime in
                if let current = lyrics.last(where: { $0.timestamp <= newTime }) {
                    withAnimation {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
            }
        }
    }

    private var largeCoverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.25))
            Image(systemName: "music.note")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func isCurrentLine(_ line: LyricLine) -> Bool {
        guard let index = lyrics.firstIndex(where: { $0.id == line.id }) else { return false }
        let currentTime = playerService.currentTime
        if index < lyrics.count - 1 {
            return currentTime >= line.timestamp && currentTime < lyrics[index + 1].timestamp
        } else {
            return currentTime >= line.timestamp
        }
    }

    private func loadLyrics() async {
        guard let song = playerService.currentSong, let client else { return }
        isLoadingLyrics = true
        lyrics = []
        if let artist = song.artist, let raw = try? await client.getLyrics(artist: artist, title: song.title), let content = raw.content {
            lyrics = SubsonicClient.parseLRC(content)
        }
        isLoadingLyrics = false
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 && seconds.isFinite else { return "00:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

public struct QueueListView: View {
    @Environment(\.dismiss) private var dismiss
    public var playerService: AudioPlayerService
    public var client: SubsonicClient?

    public init(playerService: AudioPlayerService, client: SubsonicClient?) {
        self.playerService = playerService
        self.client = client
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("当前播放 (\(playerService.queue.count) 首)") {
                    ForEach(Array(playerService.queue.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            if playerService.currentSong?.id == song.id {
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 13))
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 14, weight: playerService.currentSong?.id == song.id ? .semibold : .regular))
                                    .foregroundStyle(playerService.currentSong?.id == song.id ? .blue : .primary)
                                    .lineLimit(1)

                                Text(song.artist ?? "未知歌手")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(song.formattedDuration)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let client {
                                playerService.play(song: song, in: playerService.queue, client: client)
                            }
                        }
                    }
                }
            }
            .navigationTitle("播放队列")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 480)
    }
}
