import Foundation
import AVFoundation
import MediaPlayer
import Observation
import SubsonicKit

public enum PlaybackMode: String, CaseIterable, Sendable {
    case sequence = "顺序播放"
    case repeatOne = "单曲循环"
    case repeatAll = "列表循环"
    case shuffle = "随机播放"
    
    public var iconName: String {
        switch self {
        case .sequence: return "repeat"
        case .repeatOne: return "repeat.1"
        case .repeatAll: return "repeat"
        case .shuffle: return "shuffle"
        }
    }
}

@Observable
public final class AudioPlayerService: @unchecked Sendable {
    public static let shared = AudioPlayerService()

    public var currentSong: Song?
    public var isPlaying: Bool = false
    public var currentTime: Double = 0
    public var duration: Double = 0
    public var queue: [Song] = []
    public var currentIndex: Int = 0
    public var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    public var playbackMode: PlaybackMode = .repeatAll
    public var showFullPlayer: Bool = false
    public var showQueueSheet: Bool = false

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var nowPlayingManager: NowPlayingManager?
    private var activeClient: SubsonicClient?

    public init() {
        self.nowPlayingManager = NowPlayingManager(playerService: self)
    }

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }

    public func play(song: Song, in queue: [Song] = [], client: SubsonicClient) {
        self.activeClient = client
        self.currentSong = song
        if !queue.isEmpty {
            self.queue = queue
        } else if self.queue.isEmpty {
            self.queue = [song]
        }
        
        if let index = self.queue.firstIndex(where: { $0.id == song.id }) {
            self.currentIndex = index
        }

        guard let streamUrl = client.streamUrl(songId: song.id) else { return }

        let item = AVPlayerItem(url: streamUrl)
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.volume = volume
            setupTimeObserver()
            setupEndObserver()
        } else {
            player?.replaceCurrentItem(with: item)
        }

        player?.play()
        isPlaying = true
        nowPlayingManager?.updateNowPlaying(song: song, client: client)
    }

    public func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        if let currentSong, let activeClient {
            nowPlayingManager?.updateNowPlaying(song: currentSong, client: activeClient)
        }
    }

    public func next() {
        guard let client = activeClient, !queue.isEmpty else { return }
        switch playbackMode {
        case .repeatOne:
            if let current = currentSong {
                seek(to: 0)
                play(song: current, in: queue, client: client)
            }
        case .shuffle:
            let randomIndex = Int.random(in: 0..<queue.count)
            currentIndex = randomIndex
            play(song: queue[randomIndex], in: queue, client: client)
        case .sequence:
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                play(song: queue[currentIndex], in: queue, client: client)
            } else {
                player?.pause()
                isPlaying = false
            }
        case .repeatAll:
            let nextIndex = (currentIndex + 1) % queue.count
            currentIndex = nextIndex
            play(song: queue[nextIndex], in: queue, client: client)
        }
    }

    public func previous() {
        guard let client = activeClient, !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        let prevIndex = (currentIndex - 1 + queue.count) % queue.count
        currentIndex = prevIndex
        play(song: queue[prevIndex], in: queue, client: client)
    }

    public func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        self.currentTime = seconds
    }

    public func togglePlaybackMode() {
        let all = PlaybackMode.allCases
        if let index = all.firstIndex(of: playbackMode) {
            let nextIndex = (index + 1) % all.count
            playbackMode = all[nextIndex]
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let currentItem = self.player?.currentItem {
                let durationSec = currentItem.duration.seconds
                if durationSec.isFinite && durationSec > 0 {
                    self.duration = durationSec
                } else if let songDuration = self.currentSong?.duration, songDuration > 0 {
                    self.duration = Double(songDuration)
                }
            }
        }
    }

    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.next()
        }
    }
}

