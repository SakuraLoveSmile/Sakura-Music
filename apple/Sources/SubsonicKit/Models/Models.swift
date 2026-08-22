import Foundation

public struct ServerConfig: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var baseUrl: String
    public var username: String
    public var protocolType: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        baseUrl: String,
        username: String,
        protocolType: String = "Navidrome",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.username = username
        self.protocolType = protocolType
        self.createdAt = createdAt
    }
}

public struct Song: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let album: String?
    public let albumId: String?
    public let artist: String?
    public let artistId: String?
    public let duration: Int?
    public let bitRate: Int?
    public let coverArt: String?
    public let track: Int?
    public let discNumber: Int?
    public let year: Int?
    public let genre: String?
    public let suffix: String?
    public let size: Int?
    public let contentType: String?
    public let path: String?

    public init(
        id: String,
        title: String,
        album: String? = nil,
        albumId: String? = nil,
        artist: String? = nil,
        artistId: String? = nil,
        duration: Int? = nil,
        bitRate: Int? = nil,
        coverArt: String? = nil,
        track: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        suffix: String? = nil,
        size: Int? = nil,
        contentType: String? = nil,
        path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.album = album
        self.albumId = albumId
        self.artist = artist
        self.artistId = artistId
        self.duration = duration
        self.bitRate = bitRate
        self.coverArt = coverArt
        self.track = track
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.suffix = suffix
        self.size = size
        self.contentType = contentType
        self.path = path
    }
    
    public var formattedDuration: String {
        guard let duration, duration > 0 else { return "--:--" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var formattedBitRate: String {
        guard let bitRate, bitRate > 0 else { return "Lossless" }
        return "\(bitRate) kbps"
    }
}

public struct Album: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let name: String?
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let songCount: Int?
    public let duration: Int?
    public let year: Int?
    public let genre: String?
    public let song: [Song]?

    public var displayTitle: String {
        if !title.isEmpty { return title }
        return name ?? "Unknown Album"
    }

    public init(
        id: String,
        title: String,
        name: String? = nil,
        artist: String? = nil,
        artistId: String? = nil,
        coverArt: String? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        song: [Song]? = nil
    ) {
        self.id = id
        self.title = title
        self.name = name
        self.artist = artist
        self.artistId = artistId
        self.coverArt = coverArt
        self.songCount = songCount
        self.duration = duration
        self.year = year
        self.genre = genre
        self.song = song
    }
}

public struct Artist: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let albumCount: Int?
    public let coverArt: String?
    public let artistImageUrl: String?
    public let album: [Album]?

    public init(
        id: String,
        name: String,
        albumCount: Int? = nil,
        coverArt: String? = nil,
        artistImageUrl: String? = nil,
        album: [Album]? = nil
    ) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.coverArt = coverArt
        self.artistImageUrl = artistImageUrl
        self.album = album
    }
}

public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let comment: String?
    public let owner: String?
    public let isPublic: Bool?
    public let songCount: Int?
    public let duration: Int?
    public let coverArt: String?
    public let entry: [Song]?

    public init(
        id: String,
        name: String,
        comment: String? = nil,
        owner: String? = nil,
        isPublic: Bool? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        coverArt: String? = nil,
        entry: [Song]? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.owner = owner
        self.isPublic = isPublic
        self.songCount = songCount
        self.duration = duration
        self.coverArt = coverArt
        self.entry = entry
    }
}

public struct Lyrics: Codable, Hashable, Sendable {
    public let artist: String?
    public let title: String?
    public let content: String?

    public init(artist: String? = nil, title: String? = nil, content: String? = nil) {
        self.artist = artist
        self.title = title
        self.content = content
    }
}

public struct LyricLine: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Double
    public let text: String

    public init(id: UUID = UUID(), timestamp: Double, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

public struct SearchResult3: Codable, Sendable {
    public let song: [Song]?
    public let album: [Album]?
    public let artist: [Artist]?

    public init(song: [Song]? = nil, album: [Album]? = nil, artist: [Artist]? = nil) {
        self.song = song
        self.album = album
        self.artist = artist
    }
}

public struct Genre: Identifiable, Codable, Hashable, Sendable {
    public var id: String { value }
    public let value: String
    public let songCount: Int?
    public let albumCount: Int?

    public init(value: String, songCount: Int? = nil, albumCount: Int? = nil) {
        self.value = value
        self.songCount = songCount
        self.albumCount = albumCount
    }
}

public struct SubsonicResponseWrapper<T: Codable & Sendable>: Codable, Sendable {
    public let subsonicResponse: SubsonicResponse<T>

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

public struct SubsonicResponse<T: Codable & Sendable>: Codable, Sendable {
    public let status: String
    public let version: String
    public let error: SubsonicErrorPayload?
    public let data: T?

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        let statusKey = DynamicCodingKeys(stringValue: "status")!
        let versionKey = DynamicCodingKeys(stringValue: "version")!
        let errorKey = DynamicCodingKeys(stringValue: "error")!
        
        self.status = try container.decodeIfPresent(String.self, forKey: statusKey) ?? "ok"
        self.version = try container.decodeIfPresent(String.self, forKey: versionKey) ?? "1.16.1"
        self.error = try container.decodeIfPresent(SubsonicErrorPayload.self, forKey: errorKey)

        if let decoded = try? T(from: decoder) {
            self.data = decoded
        } else {
            self.data = nil
        }
    }
}

public struct SubsonicErrorPayload: Codable, Sendable {
    public let code: Int
    public let message: String
}
