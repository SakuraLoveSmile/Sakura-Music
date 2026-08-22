# SakuraMusic

SakuraMusic is a focused Flutter client for Subsonic and OpenSubsonic music
servers. It is designed for desktop and mobile, with a lightweight interface
for browsing a library, searching, managing playback, and keeping selected
music available offline.

## Features

- Home discovery sections for recent, frequent, random, and recently played
  music
- Artist, album, playlist, favorites, search, history, settings, and downloads
  screens
- Queue editing, play-next, loop modes, shuffle, seeking, volume, and speed
  control, reorder/remove queue UI, and 300 ms fade envelopes
- Persistent paused playback state and recent-play history
- Synchronized lyrics with structured-lyrics support and LRC fallback
- Optimistic song/album/artist favorites with rollback on failure
- Cover-art colors, blurred player backgrounds, responsive navigation, and
  desktop window sizing
- Stream caching, manual downloads, local-file playback, and cached metadata
- Five-band equalizer with presets on Android/desktop, plus ListenBrainz
  scrobbling with token validation
- Windows system media controls through SMTC
- A reusable `subsonic_api` package with tolerant OpenSubsonic response parsing

## Getting started

Install Flutter and a compatible Dart SDK, then fetch the application and
package dependencies:

```sh
flutter pub get
cd packages/subsonic_api
dart pub get
cd ../..
```

Add a server from the Settings screen. SakuraMusic accepts a Subsonic or
OpenSubsonic-compatible URL, username, and password.

## Run targets

Use `flutter devices` to find a device identifier when running on a physical
phone or simulator.

```sh
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# Android or iOS
flutter run -d <device-id>
```

For a macOS build without launching the app:

```sh
flutter build macos --debug
```

## Development checks

```sh
flutter analyze
flutter test

cd packages/subsonic_api
dart analyze
dart test
```

After changing Drift tables, regenerate the database companion:

```sh
flutter pub run build_runner build
```

## Architecture

```text
                 ┌──────────────────────────────────────┐
                 │ Flutter UI                           │
                 │ go_router + Riverpod feature screens │
                 └───────────────┬──────────────────────┘
                                 │
             ┌───────────────────┴───────────────────┐
             │                                       │
             ▼                                       ▼
┌─────────────────────────┐             ┌─────────────────────────┐
│ Subsonic data layer     │             │ Playback coordinator    │
│ Dio + subsonic_api      │             │ queue/state/scrobbling  │
└────────────┬────────────┘             └────────────┬────────────┘
             │                                       │
             ▼                                       ▼
┌─────────────────────────┐             ┌─────────────────────────┐
│ Subsonic/OpenSubsonic  │             │ AudioPlayerService      │
│ server                  │             │                         │
└─────────────────────────┘             └────────────┬────────────┘
                                                     │
                           ┌─────────────────────────┴────────────────────┐
                           │                                              │
                           ▼                                              ▼
                Android/iOS: audio_service              macOS/Windows: media_kit
                + just_audio                             + Windows SMTC

        Drift database: servers, settings, playback state, history,
        search history, downloads, and cached artist/album metadata.
```

The API client is kept in `packages/subsonic_api` so protocol models and
endpoint behavior can be tested independently of Flutter.

## Routes

| Route | Screen |
| --- | --- |
| `/home` | Discovery home |
| `/artists`, `/artists/:id` | Artist list and details |
| `/albums`, `/albums/:id` | Album list and details |
| `/playlists`, `/playlists/:id` | Playlist list and details |
| `/search` | Server search |
| `/library` | Songs, albums, and artists saved as favorites |
| `/downloads` | Download progress and offline songs |
| `/settings` | Servers, appearance, equalizer, and scrobbling |
| `/player` | Full-screen player and lyrics; opened above the app shell |

With no saved server the startup redirect lands on `/settings`; with an
available server it starts at `/home`. The mobile shell uses a bottom
NavigationBar and the desktop shell uses an extended NavigationRail at wide
widths. Search and Settings remain available from the top-right actions.

## Known limitations

- Windows playback and SMTC integration are compile-tested but have not been
  verified on a physical Windows machine in this iteration.
- iOS does not expose the required parameterized EQ pipeline, so the EQ UI is
  disabled there. Last.fm is intentionally not connected until an application
  API key is available; the settings screen only documents that placeholder.
- Server passwords are currently stored in the local Drift database; secure
  platform storage should replace passwords and ListenBrainz tokens before
  production distribution.
- Older Subsonic servers may not implement structured lyrics or every extended
  endpoint. The client falls back to classic lyrics and tolerant empty states
  where possible.
- A full end-to-end session against a live demo server still requires valid
  server credentials and network access; the automated checks cover analysis,
  tests, and the macOS debug build.
