import SwiftUI
import SubsonicKit

public struct MiniPlayerView: View {
    public var playerService: AudioPlayerService
    public var client: SubsonicClient?

    public init(playerService: AudioPlayerService, client: SubsonicClient?) {
        self.playerService = playerService
        self.client = client
    }

    public var body: some View {
        if let song = playerService.currentSong {
            VStack(spacing: 0) {
                // Progress Bar at the top edge of the mini player
                GeometryReader { geo in
                    let progress = playerService.duration > 0 ? (playerService.currentTime / playerService.duration) : 0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 2)

                        Rectangle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 2)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 14) {
                    // Cover Art
                    Group {
                        if let coverArt = song.coverArt, let client, let coverUrl = client.coverArtUrl(id: coverArt, size: 120) {
                            AsyncImage(url: coverUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .empty:
                                    ProgressView()
                                        .controlSize(.mini)
                                case .failure:
                                    coverPlaceholder
                                @unknown default:
                                    coverPlaceholder
                                }
                            }
                        } else {
                            coverPlaceholder
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                    // Song Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(song.artist ?? "未知歌手")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if let suffix = song.suffix?.uppercased() {
                                Text(suffix)
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 16) {
                        Button(action: { playerService.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.togglePlayPause() }) {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)

                        Button(action: { playerService.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        #if os(macOS)
                        // Volume Slider on macOS
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.1.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Slider(
                                value: Binding(
                                    get: { playerService.volume },
                                    set: { playerService.volume = $0 }
                                ),
                                in: 0...1
                            )
                            .frame(width: 70)
                            .controlSize(.mini)
                        }
                        .padding(.leading, 8)
                        #endif

                        Button(action: { playerService.showFullPlayer = true }) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("展開播放器")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                playerService.showFullPlayer = true
            }
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
        }
    }
}
