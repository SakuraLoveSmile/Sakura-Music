import XCTest
@testable import SubsonicKit

final class SubsonicKitTests: XCTestCase {
    func testSaltAndTokenGeneration() {
        let salt = "mysalt123"
        let token = SubsonicAuth.calculateToken(password: "secret", salt: salt)
        XCTAssertFalse(token.isEmpty)
        XCTAssertEqual(token.count, 32) // MD5 hex length

        let auth = SubsonicAuth(username: "admin", password: "password123")
        let items = auth.queryItems()
        XCTAssertTrue(items.contains { $0.name == "u" && $0.value == "admin" })
        XCTAssertTrue(items.contains { $0.name == "f" && $0.value == "json" })
        XCTAssertTrue(items.contains { $0.name == "t" })
        XCTAssertTrue(items.contains { $0.name == "s" })
        XCTAssertTrue(items.contains { $0.name == "v" && $0.value == "1.16.1" })
    }

    func testServerConfig() {
        let config = ServerConfig(
            name: "My Navidrome",
            baseUrl: "https://music.example.com///",
            username: "sakura",
            protocolType: "Navidrome"
        )
        XCTAssertEqual(config.name, "My Navidrome")
        XCTAssertEqual(config.baseUrl, "https://music.example.com")
        XCTAssertEqual(config.username, "sakura")
        XCTAssertEqual(config.protocolType, "Navidrome")
    }

    func testClientUrlConstruction() {
        let client = SubsonicClient(
            baseUrl: "https://demo.navidrome.org",
            username: "demo",
            password: "password"
        )
        let streamUrl = client.streamUrl(songId: "12345", maxBitRate: 320)
        XCTAssertNotNil(streamUrl)
        XCTAssertTrue(streamUrl!.absoluteString.contains("demo.navidrome.org/rest/stream.view"))
        XCTAssertTrue(streamUrl!.absoluteString.contains("id=12345"))
        XCTAssertTrue(streamUrl!.absoluteString.contains("maxBitRate=320"))

        let coverUrl = client.coverArtUrl(id: "art-99", size: 600)
        XCTAssertNotNil(coverUrl)
        XCTAssertTrue(coverUrl!.absoluteString.contains("getCoverArt.view"))
        XCTAssertTrue(coverUrl!.absoluteString.contains("id=art-99"))
        XCTAssertTrue(coverUrl!.absoluteString.contains("size=600"))
    }

    func testLRCParser() {
        let lrcContent = """
        [ti:Test Song]
        [ar:Test Artist]
        [00:05.50]First line of lyrics
        [00:12.30]Second line of lyrics
        [01:03.456]Third line in next minute
        """
        let lines = SubsonicClient.parseLRC(lrcContent)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].text, "First line of lyrics")
        XCTAssertEqual(lines[0].timestamp, 5.5, accuracy: 0.01)
        XCTAssertEqual(lines[1].text, "Second line of lyrics")
        XCTAssertEqual(lines[1].timestamp, 12.3, accuracy: 0.01)
        XCTAssertEqual(lines[2].text, "Third line in next minute")
        XCTAssertEqual(lines[2].timestamp, 63.456, accuracy: 0.01)
    }

    func testSongAndAlbumModelDecoding() throws {
        let jsonString = """
        {
            "id": "song-1",
            "title": "Sakura Melody",
            "artist": "Sakura Artist",
            "album": "Spring Album",
            "duration": 215,
            "bitRate": 1411,
            "track": 1,
            "suffix": "flac"
        }
        """
        let data = Data(jsonString.utf8)
        let song = try JSONDecoder().decode(Song.self, from: data)
        XCTAssertEqual(song.id, "song-1")
        XCTAssertEqual(song.title, "Sakura Melody")
        XCTAssertEqual(song.formattedDuration, "03:35")
        XCTAssertEqual(song.formattedBitRate, "1411 kbps")
    }

    func testSubsonicErrorParsing() throws {
        let errorJson = """
        {
            "subsonic-response": {
                "status": "failed",
                "version": "1.16.1",
                "error": {
                    "code": 40,
                    "message": "Wrong username or password"
                }
            }
        }
        """
        let data = Data(errorJson.utf8)
        let wrapper = try JSONDecoder().decode(SubsonicResponseWrapper<[Song]>.self, from: data)
        XCTAssertEqual(wrapper.subsonicResponse.status, "failed")
        XCTAssertEqual(wrapper.subsonicResponse.error?.code, 40)
        XCTAssertEqual(wrapper.subsonicResponse.error?.message, "Wrong username or password")
    }

    func testAlbumDisplayTitle() {
        let albumWithTitle = Album(id: "a1", title: "My Album")
        XCTAssertEqual(albumWithTitle.displayTitle, "My Album")

        let albumWithNameOnly = Album(id: "a2", title: "", name: "Fallback Name")
        XCTAssertEqual(albumWithNameOnly.displayTitle, "Fallback Name")
    }
}

