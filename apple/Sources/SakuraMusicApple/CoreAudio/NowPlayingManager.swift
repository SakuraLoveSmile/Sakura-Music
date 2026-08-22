import Foundation
import MediaPlayer
import SubsonicKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public final class NowPlayingManager: @unchecked Sendable {
    private weak var playerService: AudioPlayerService?
    private var artworkTask: Task<Void, Never>?

    public init(playerService: AudioPlayerService) {
        self.playerService = playerService
        setupRemoteCommands()
    }

    public func updateNowPlaying(song: Song, client: SubsonicClient) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        if let artist = song.artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = song.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let duration = song.duration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(duration)
        } else if let playerDuration = playerService?.duration, playerDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = playerDuration
        }
        
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerService?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = (playerService?.isPlaying == true) ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        artworkTask?.cancel()
        if let coverArtId = song.coverArt, let coverUrl = client.coverArtUrl(id: coverArtId, size: 600) {
            artworkTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let (data, _) = try await URLSession.shared.data(from: coverUrl)
                    #if canImport(AppKit)
                    if let nsImage = NSImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                    #elseif canImport(UIKit)
                    if let uiImage = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                    #endif
                } catch {
                    // Ignore artwork download failure
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self, let service = self.playerService else { return .commandFailed }
            if !service.isPlaying {
                service.togglePlayPause()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, let service = self.playerService else { return .commandFailed }
            if service.isPlaying {
                service.togglePlayPause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let service = self.playerService else { return .commandFailed }
            service.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self, let service = self.playerService else { return .commandFailed }
            service.next()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self, let service = self.playerService else { return .commandFailed }
            service.previous()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let service = self.playerService,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            service.seek(to: positionEvent.positionTime)
            return .success
        }
    }
}
