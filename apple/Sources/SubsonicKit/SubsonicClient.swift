import Foundation

public enum SubsonicError: Error, LocalizedError, Sendable {
    case invalidURL
    case serverError(code: Int, message: String)
    case networkError(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址格式无效"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .invalidResponse:
            return "无法解析服务器响应"
        }
    }
}

public final class SubsonicClient: @unchecked Sendable {
    public let baseUrl: String
    public let username: String
    private let passwordProvider: @Sendable () -> String
    private let session: URLSession

    public init(
        baseUrl: String,
        username: String,
        password: String,
        session: URLSession = .shared
    ) {
        var cleanUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.hasPrefix("http://") && !cleanUrl.hasPrefix("https://") {
            cleanUrl = "https://" + cleanUrl
        }
        if cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }
        self.baseUrl = cleanUrl
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.passwordProvider = { password }
        self.session = session
    }

    public func makeURL(endpoint: String, additionalParams: [URLQueryItem] = []) throws -> URL {
        guard let url = URL(string: "\(baseUrl)/rest/\(endpoint)") else {
            throw SubsonicError.invalidURL
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let auth = SubsonicAuth(username: username, password: passwordProvider())
        var queryItems = auth.queryItems()
        queryItems.append(contentsOf: additionalParams)
        components?.queryItems = queryItems
        guard let finalURL = components?.url else {
            throw SubsonicError.invalidURL
        }
        return finalURL
    }

    public func ping() async throws -> Bool {
        let url = try makeURL(endpoint: "ping.view")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw SubsonicError.invalidResponse
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let subsonic = json["subsonic-response"] as? [String: Any] {
            if let status = subsonic["status"] as? String, status == "ok" {
                return true
            }
            if let errorObj = subsonic["error"] as? [String: Any],
               let message = errorObj["message"] as? String,
               let code = errorObj["code"] as? Int {
                throw SubsonicError.serverError(code: code, message: message)
            }
        }
        return true
    }

    public func coverArtUrl(id: String?, size: Int = 400) -> URL? {
        guard let id, !id.isEmpty else { return nil }
        return try? makeURL(
            endpoint: "getCoverArt.view",
            additionalParams: [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    public func streamUrl(songId: String, maxBitRate: Int? = nil) -> URL? {
        var params = [URLQueryItem(name: "id", value: songId)]
        if let maxBitRate {
            params.append(URLQueryItem(name: "maxBitRate", value: String(maxBitRate)))
        }
        return try? makeURL(endpoint: "stream.view", additionalParams: params)
    }

    public func getAlbumList(type: String = "newest", size: Int = 30, offset: Int = 0) async throws -> [Album] {
        let url = try makeURL(
            endpoint: "getAlbumList2.view",
            additionalParams: [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: String(size)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        if let errorObj = subsonic["error"] as? [String: Any] {
            let msg = errorObj["message"] as? String ?? "未知錯誤"
            let code = errorObj["code"] as? Int ?? 0
            throw SubsonicError.serverError(code: code, message: msg)
        }

        if let albumList = subsonic["albumList2"] as? [String: Any],
           let albumsJson = albumList["album"] as? [[String: Any]] {
            let albumsData = try JSONSerialization.data(withJSONObject: albumsJson)
            return try JSONDecoder().decode([Album].self, from: albumsData)
        } else if let albumList = subsonic["albumList"] as? [String: Any],
                  let albumsJson = albumList["album"] as? [[String: Any]] {
            let albumsData = try JSONSerialization.data(withJSONObject: albumsJson)
            return try JSONDecoder().decode([Album].self, from: albumsData)
        }

        return []
    }

    public func getAlbum(id: String) async throws -> Album {
        let url = try makeURL(endpoint: "getAlbum.view", additionalParams: [URLQueryItem(name: "id", value: id)])
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        if let errorObj = subsonic["error"] as? [String: Any] {
            let msg = errorObj["message"] as? String ?? "未知錯誤"
            let code = errorObj["code"] as? Int ?? 0
            throw SubsonicError.serverError(code: code, message: msg)
        }

        guard let albumJson = subsonic["album"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        let albumData = try JSONSerialization.data(withJSONObject: albumJson)
        return try JSONDecoder().decode(Album.self, from: albumData)
    }

    public func getArtists() async throws -> [Artist] {
        let url = try makeURL(endpoint: "getArtists.view")
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        if let errorObj = subsonic["error"] as? [String: Any] {
            let msg = errorObj["message"] as? String ?? "未知錯誤"
            let code = errorObj["code"] as? Int ?? 0
            throw SubsonicError.serverError(code: code, message: msg)
        }

        var result: [Artist] = []
        if let artistsObj = subsonic["artists"] as? [String: Any],
           let indexArray = artistsObj["index"] as? [[String: Any]] {
            for index in indexArray {
                if let artistArray = index["artist"] as? [[String: Any]] {
                    let artistData = try JSONSerialization.data(withJSONObject: artistArray)
                    let decoded = try JSONDecoder().decode([Artist].self, from: artistData)
                    result.append(contentsOf: decoded)
                }
            }
        }
        return result
    }

    public func getArtist(id: String) async throws -> Artist {
        let url = try makeURL(endpoint: "getArtist.view", additionalParams: [URLQueryItem(name: "id", value: id)])
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        guard let artistJson = subsonic["artist"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        let artistData = try JSONSerialization.data(withJSONObject: artistJson)
        return try JSONDecoder().decode(Artist.self, from: artistData)
    }

    public func getPlaylists() async throws -> [Playlist] {
        let url = try makeURL(endpoint: "getPlaylists.view")
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        guard let playlistsObj = subsonic["playlists"] as? [String: Any],
              let playlistArray = playlistsObj["playlist"] as? [[String: Any]] else {
            return []
        }

        let dataArray = try JSONSerialization.data(withJSONObject: playlistArray)
        return try JSONDecoder().decode([Playlist].self, from: dataArray)
    }

    public func getPlaylist(id: String) async throws -> Playlist {
        let url = try makeURL(endpoint: "getPlaylist.view", additionalParams: [URLQueryItem(name: "id", value: id)])
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        guard let playlistJson = subsonic["playlist"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        let playlistData = try JSONSerialization.data(withJSONObject: playlistJson)
        return try JSONDecoder().decode(Playlist.self, from: playlistData)
    }

    public func search3(query: String) async throws -> SearchResult3 {
        let url = try makeURL(
            endpoint: "search3.view",
            additionalParams: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "songCount", value: "30"),
                URLQueryItem(name: "albumCount", value: "20"),
                URLQueryItem(name: "artistCount", value: "10")
            ]
        )
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            throw SubsonicError.invalidResponse
        }

        guard let searchResultJson = subsonic["searchResult3"] as? [String: Any] else {
            return SearchResult3()
        }

        let searchData = try JSONSerialization.data(withJSONObject: searchResultJson)
        return try JSONDecoder().decode(SearchResult3.self, from: searchData)
    }

    public func getLyrics(artist: String, title: String) async throws -> Lyrics? {
        let url = try makeURL(
            endpoint: "getLyrics.view",
            additionalParams: [
                URLQueryItem(name: "artist", value: artist),
                URLQueryItem(name: "title", value: title)
            ]
        )
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonic = json["subsonic-response"] as? [String: Any] else {
            return nil
        }

        if let lyricsJson = subsonic["lyrics"] as? [String: Any] {
            let artist = lyricsJson["artist"] as? String
            let title = lyricsJson["title"] as? String
            let content = lyricsJson["content"] as? String
            return Lyrics(artist: artist, title: title, content: content)
        }
        return nil
    }

    public static func parseLRC(_ content: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = content.components(separatedBy: .newlines)
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?\\](.*)")

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let regex = regex {
                let nsString = trimmed as NSString
                let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if match.numberOfRanges >= 3 {
                        let minStr = nsString.substring(with: match.range(at: 1))
                        let secStr = nsString.substring(with: match.range(at: 2))
                        var msStr = "0"
                        if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                            msStr = nsString.substring(with: match.range(at: 3))
                        }
                        let text = match.numberOfRanges >= 5 && match.range(at: 4).location != NSNotFound
                            ? nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                            : ""

                        let minutes = Double(minStr) ?? 0
                        let seconds = Double(secStr) ?? 0
                        let ms = (Double(msStr) ?? 0) / (msStr.count == 2 ? 100.0 : 1000.0)
                        let timestamp = minutes * 60.0 + seconds + ms
                        if !text.isEmpty {
                            lines.append(LyricLine(timestamp: timestamp, text: text))
                        }
                    }
                }
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}

