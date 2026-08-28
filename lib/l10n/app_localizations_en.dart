// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SakuraMusic';

  @override
  String get viewSwitch => 'Switch view';

  @override
  String get settings => 'Settings';

  @override
  String get welcomeTagline => 'Connect to your music';

  @override
  String get privacyPrefix => 'By continuing you agree to the ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get addedTapCardHint => 'Added. Tap the card to enter';

  @override
  String get featureMultiSource => 'Multi-source';

  @override
  String get featureMultiSourceDesc =>
      'Supports Navidrome, Emby and more server protocols';

  @override
  String get featureLossless => 'Lossless playback';

  @override
  String get featureLosslessDesc => 'Hi-Res audio';

  @override
  String get featureNative => 'Native experience';

  @override
  String get featureNativeDesc => 'Built with native UI';

  @override
  String get featureCrossPlatform => 'All platforms';

  @override
  String get featureCrossPlatformDesc => 'iOS, macOS, tvOS and beyond';

  @override
  String get search => 'Search';

  @override
  String get welcomeNav => 'Welcome';

  @override
  String get serversSection => 'Servers';

  @override
  String loadFailed(Object message) {
    return 'Failed to load: $message';
  }

  @override
  String get noServers => 'No servers yet';

  @override
  String get noSearchResults => 'No matches';

  @override
  String get addServer => 'Add server';

  @override
  String get more => 'More';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get chooseLibrary => 'Choose a library';

  @override
  String serverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get currentBadge => 'Current';

  @override
  String get emptyPickerTitle => 'No servers yet';

  @override
  String get emptyPickerDesc =>
      'Add your first server to connect to your music';

  @override
  String get addFirstServer => 'Add your first server';

  @override
  String get editServer => 'Edit server';

  @override
  String get close => 'Close';

  @override
  String get serverType => 'Server type';

  @override
  String get serverName => 'Server name';

  @override
  String get serverNameHint => 'e.g. My Navidrome';

  @override
  String get pleaseInputServerName => 'Please enter a server name';

  @override
  String get serverAddress => 'Server address';

  @override
  String get hostLabel => 'Host';

  @override
  String get pleaseInputServerAddress => 'Please enter a server address';

  @override
  String get hostNoScheme => 'No protocol needed; host name only';

  @override
  String get portInRightField => 'Please enter the port in the port field';

  @override
  String get portLabel => 'Port';

  @override
  String get portRange => '1–65535';

  @override
  String get username => 'Username';

  @override
  String get pleaseInputUsername => 'Please enter a username';

  @override
  String get password => 'Password';

  @override
  String get pleaseInputPassword => 'Please enter a password';

  @override
  String get connectSuccess => 'Connected! The server is responding.';

  @override
  String connectFailed(Object message) {
    return 'Connection failed: $message';
  }

  @override
  String saveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get loadError => 'Failed to load';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveAndConnect => 'Save and connect';

  @override
  String get deleteServerTitle => 'Delete server?';

  @override
  String deleteServerConfirm(Object name) {
    return 'Delete \"$name\"? Only the locally stored connection will be removed.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';

  @override
  String get exitConfirmTitle => 'Exit app?';

  @override
  String get exitConfirmMessage => 'Are you sure you want to exit SakuraMusic?';

  @override
  String get exitApp => 'Exit';

  @override
  String get switchLibrary => 'Switch library';

  @override
  String get membership => 'Membership';

  @override
  String get membershipActivated => 'Activated';

  @override
  String get activateMembership => 'Activate Membership';

  @override
  String get activateMembershipSubtitle =>
      'Activate full member benefits via activation code or starring our GitHub repository';

  @override
  String get membershipActiveBannerTitle => 'Membership Active';

  @override
  String get activationCodeTitle => 'Activation Code';

  @override
  String get activationCodeHint => 'Enter activation code';

  @override
  String get activateButton => 'Activate';

  @override
  String get activationSuccess =>
      'Activated successfully! Member features enabled.';

  @override
  String get activationCodeInvalid =>
      'Invalid activation code. Please check and try again.';

  @override
  String get starActivationTitle => 'Star on GitHub';

  @override
  String get starActivationDesc =>
      'If you have starred this project on GitHub, turn on this switch to activate membership. No check is performed; this operates on the honor system.';

  @override
  String get goToStar => 'Go to Star';

  @override
  String get activatedViaCode => 'Activated via: Activation Code';

  @override
  String get activatedViaStar => 'Activated via: GitHub Star (Honor System)';

  @override
  String get deactivateMembership => 'Deactivate';

  @override
  String get deactivatedSuccess => 'Membership deactivated';

  @override
  String get notActivated => 'Not activated';

  @override
  String get sectionPlayback => 'Playback';

  @override
  String get autoPlayOnLaunch => 'Auto-play on launch';

  @override
  String get fadeTransition => 'Fade in / out';

  @override
  String get musicRoaming => 'Music roaming';

  @override
  String get streamingQuality => 'Streaming quality';

  @override
  String get equalizerSettings => 'Equalizer';

  @override
  String get lyricsOverlay => 'Floating lyrics';

  @override
  String get lyricsOverlayPermissionNeeded =>
      'Overlay permission is required. Grant it in system settings and try again.';

  @override
  String get statusBarLyrics => 'Status-bar lyrics (Lyricon)';

  @override
  String get statusBarLyricsDesc =>
      'Sync the current song and its lyrics to the status bar (requires LSPosed and Lyricon on the device). Silently ignored when not installed.';

  @override
  String get sectionNetwork => 'Network';

  @override
  String get backgroundDownload => 'Background downloads';

  @override
  String get downloadWifiOnly => 'Wi-Fi only';

  @override
  String get downloadAnyNetwork => 'Any network';

  @override
  String get downloadOff => 'Off';

  @override
  String get networkProxy => 'Network proxy';

  @override
  String get sectionStorage => 'Storage & servers';

  @override
  String get serverManagement => 'Manage servers';

  @override
  String get notConnected => 'Not connected';

  @override
  String get addNewServer => 'Add a new server';

  @override
  String get clearCache => 'Clear song cache';

  @override
  String get cacheCleared => 'Local temporary cache cleared';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get sectionAbout => 'About';

  @override
  String get currentVersion => 'Version';

  @override
  String get loading => 'Loading…';

  @override
  String get unknown => 'Unknown';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get installing => 'Installing';

  @override
  String get retry => 'Retry';

  @override
  String get upToDate => 'Up to date';

  @override
  String get updateCheckFailed => 'Failed to check for updates';

  @override
  String get qualityLosslessAuto => 'Lossless / Auto';

  @override
  String get qualityFlacWav => 'FLAC / WAV ultra high';

  @override
  String get quality320 => '320 kbps MP3 high';

  @override
  String get quality192 => '192 kbps MP3 standard';

  @override
  String get quality128 => '128 kbps MP3 data saver';

  @override
  String get proxyDialogTitle => 'Network proxy';

  @override
  String get proxyAddressLabel => 'HTTP / SOCKS5 proxy address';

  @override
  String get proxySaved => 'Proxy settings saved';

  @override
  String get save => 'Save';

  @override
  String get followSystem => 'Follow system';

  @override
  String get aboutSection => 'About';

  @override
  String get addLibraryFirst =>
      'Add a music library on the servers page first.';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String addedToDownloads(Object title) {
    return 'Added \"$title\" to downloads';
  }

  @override
  String addedToPlayNext(Object title) {
    return '\"$title\" will play next';
  }

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get albumEmptyTracks => 'This album has no playable tracks.';

  @override
  String albumLoadFailed(Object error) {
    return 'Failed to load album: $error';
  }

  @override
  String albumsLoadFailed(Object error) {
    return 'Failed to load albums: $error';
  }

  @override
  String get allAlbumsLoaded => 'All albums loaded';

  @override
  String artistAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String artistsLoadFailed(Object error) {
    return 'Failed to load artists: $error';
  }

  @override
  String assetInfo(Object name, Object size) {
    return 'Package: $name · $size';
  }

  @override
  String get browse => 'Browse';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get cast => 'Cast';

  @override
  String get clear => 'Clear';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get collapsePlayer => 'Collapse';

  @override
  String get connectedLibraries => 'Connected libraries';

  @override
  String get dailyMixSubtitle => 'Smart picks based on your listening';

  @override
  String get dailyMixTitle => 'Today\'s personal mix';

  @override
  String get dailyRecommend => 'Daily picks';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get download => 'Download';

  @override
  String get downloadSong => 'Download song';

  @override
  String downloadsLoadFailed(Object error) {
    return 'Failed to load downloads: $error';
  }

  @override
  String get emptyAlbums => 'No albums on the server yet.';

  @override
  String get emptyArtists => 'No artists on the server yet.';

  @override
  String get emptyDownloads => 'No downloaded songs yet.';

  @override
  String get emptyGenres => 'No genres in the library yet';

  @override
  String get emptyLibrarySongs => 'No songs in the library yet';

  @override
  String get emptyPlayerDesc =>
      'Pick a song from your library to start playing.';

  @override
  String get emptyPlayerTitle => 'Nothing is playing';

  @override
  String get emptyPlaylists => 'No playlists yet.';

  @override
  String get emptyQueue => 'The queue is empty.';

  @override
  String get emptySearchHistory =>
      'No search history yet. Type a keyword and press enter.';

  @override
  String get enableEqualizer => 'Enable equalizer';

  @override
  String equalizerLoadFailed(Object error) {
    return 'Failed to load equalizer settings: $error';
  }

  @override
  String get equalizerTitle => 'Equalizer';

  @override
  String get failedStatus => 'Failed';

  @override
  String get favorite => 'Favorite';

  @override
  String favoritesLoadFailed(Object error) {
    return 'Failed to load favorites: $error';
  }

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get featureAll => 'All features';

  @override
  String get featureLifetime => 'Lifetime';

  @override
  String get featureMultiDevice => 'Multi-device';

  @override
  String get featureUpdates => 'Updates';

  @override
  String get frequentlyPlayed => 'Frequently played';

  @override
  String get fullscreenPlayer => 'Fullscreen player';

  @override
  String genreAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get genreEmpty => 'No songs in this genre';

  @override
  String genreSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String genresLoadFailed(Object error) {
    return 'Failed to load genres: $error';
  }

  @override
  String get goAddServer => 'Add a server';

  @override
  String get goDiscover => 'Discover music';

  @override
  String get goToServerPicker => 'Go to servers';

  @override
  String get gotIt => 'Got it';

  @override
  String get install => 'Install';

  @override
  String get installLater => 'Install later';

  @override
  String get internetRadio => 'Internet radio';

  @override
  String get iosNotSupported => 'Not supported on iOS yet';

  @override
  String get later => 'Later';

  @override
  String get librarySection => 'Library';

  @override
  String loadedSongsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs loaded',
      one: '1 song loaded',
    );
    return '$_temp0';
  }

  @override
  String get localOutputOnly => 'Playing via local high-quality output';

  @override
  String get logout => 'Log out';

  @override
  String get loopAll => 'Repeat mode: all';

  @override
  String get loopAllShort => 'Repeat all';

  @override
  String get loopOff => 'Repeat mode: off';

  @override
  String get loopOffShort => 'No repeat';

  @override
  String get loopOne => 'Repeat mode: one';

  @override
  String get loopOneShort => 'Repeat one';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get membershipLifetimeNote =>
      'Membership is permanent once purchased.';

  @override
  String get membershipNote =>
      '1. Membership allows up to 7 devices at the same time.';

  @override
  String minutesLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String get mute => 'Mute';

  @override
  String get myMembership => 'Membership';

  @override
  String get myPlaylists => 'My playlists';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navDownloadsShort => 'Downloads';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navGenres => 'Genres';

  @override
  String get navLiked => 'Liked';

  @override
  String get navRadios => 'Radio';

  @override
  String get navSongs => 'Songs';

  @override
  String get nextTrack => 'Next track';

  @override
  String get noContentYet => 'Nothing here yet';

  @override
  String get noData => 'No data';

  @override
  String get noFavoriteAlbums => 'No favorite albums yet.';

  @override
  String get noFavoriteArtists => 'No favorite artists yet.';

  @override
  String get noFavoriteSongs => 'No favorite songs yet.';

  @override
  String get noLyrics => 'No lyrics available for this song';

  @override
  String get noMatchingAsset =>
      'No matching package for this platform. The GitHub release page will open instead.';

  @override
  String get noPlaylists => 'No playlists';

  @override
  String get noSearchMatches => 'No matches found.';

  @override
  String get noServerMessage =>
      'Add or connect a music library on the servers page first.';

  @override
  String get noSongHistory => 'No song history';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get openDownload => 'Get it';

  @override
  String get openDownloadPage => 'Open download page';

  @override
  String get pause => 'Pause';

  @override
  String get personalSection => 'Personal';

  @override
  String get pictureInPicture => 'Picture in picture';

  @override
  String get play => 'Play';

  @override
  String get playAll => 'Play all';

  @override
  String get playInOrder => 'Play in order';

  @override
  String get playNext => 'Play next';

  @override
  String playbackFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get playlistEmpty => 'This playlist has no songs.';

  @override
  String get playlistsLabel => 'Playlists';

  @override
  String playlistsLoadFailed(Object error) {
    return 'Failed to load playlists: $error';
  }

  @override
  String get popularSongs => 'Popular songs';

  @override
  String get preparingInstall => 'Preparing to install…';

  @override
  String get oledSettings => 'OLED lyrics settings';

  @override
  String get keepScreenAwake => 'Keep screen awake';

  @override
  String get lyricsFontSize => 'Lyrics font size';

  @override
  String get lyricsAlignment => 'Lyrics alignment';

  @override
  String get alignCenter => 'Center';

  @override
  String get alignLeft => 'Left';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get showClock => 'Show clock';

  @override
  String get presetClassical => 'Classical';

  @override
  String get presetFlat => 'Flat';

  @override
  String get presetLabel => 'Preset';

  @override
  String get presetPop => 'Pop';

  @override
  String get presetRock => 'Rock';

  @override
  String get presetVocal => 'Vocal';

  @override
  String get previousTrack => 'Previous track';

  @override
  String get privacyBody1 =>
      '1. SakuraMusic is an open-source, independent music client.';

  @override
  String get privacyBody2 =>
      '2. Local storage: your server address, username and password are stored only in a protected database on your device and never uploaded to any third party.';

  @override
  String get privacyBody3 =>
      '3. Networking: the app talks only to the self-hosted servers you configure (e.g. Navidrome, Subsonic).';

  @override
  String get privacyBody4 =>
      '4. Cache & downloads: songs you download stay on your local disk and can be managed or removed at any time.';

  @override
  String get privacyPolicyTitle => 'Privacy Policy & Terms';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get queueTitle => 'Queue';

  @override
  String get randomAlbums => 'Random albums';

  @override
  String get randomSongs => 'Random songs';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get recentlyAddedSongs => 'Recently added songs';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get recentlyPlayedSongs => 'Recently played songs';

  @override
  String get recentlyUpdatedPlaylists => 'Recently updated playlists';

  @override
  String get foldersCount => 'Folders';

  @override
  String get totalSize => 'Total size';

  @override
  String get totalDuration => 'Total duration';

  @override
  String get resolution => 'Resolution';

  @override
  String get customize => 'Customize';

  @override
  String get myFavorites => 'Favorites';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshBatch => 'Shuffle again';

  @override
  String get refreshSongs => 'Refresh songs';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get restartAndInstall => 'Restart & install';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get searchHint => 'Search songs, albums, artists...';

  @override
  String get searchHistory => 'Search history';

  @override
  String searchHistoryLoadFailed(Object error) {
    return 'Failed to load search history: $error';
  }

  @override
  String get sectionCompleted => 'Completed';

  @override
  String get sectionInProgress => 'In progress';

  @override
  String get shuffleOff => 'Turn off shuffle';

  @override
  String get shuffleOn => 'Turn on shuffle';

  @override
  String get shufflePlay => 'Shuffle play';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerAfterCurrent => 'Stop after current song';

  @override
  String sleepTimerSet(int minutes) {
    return 'Playback will stop in $minutes minutes';
  }

  @override
  String sleepTimerSetLabel(Object label) {
    return 'Sleep timer set: $label';
  }

  @override
  String get sleepTimerTitle => 'Sleep timer';

  @override
  String songCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String songCountText(int count) {
    return '$count songs total';
  }

  @override
  String songsLoadFailed(Object error) {
    return 'Failed to load songs: $error';
  }

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortFormat => 'Format';

  @override
  String get sortRecent => 'Recently added';

  @override
  String get sortTitle => 'Title';

  @override
  String starFailed(Object error) {
    return 'Favorite failed: $error';
  }

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get unmute => 'Unmute';

  @override
  String unstarFailed(Object error) {
    return 'Unfavorite failed: $error';
  }

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String updateDownloadingPercent(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get updatingFavorite => 'Updating favorite';

  @override
  String get viewAlbum => 'View Album';

  @override
  String get viewAll => 'View all ->';

  @override
  String get viewArtist => 'View Artist';

  @override
  String get debugDiagnostics => 'Debug & diagnostics';

  @override
  String get debugTitle => 'Debug & diagnostics';

  @override
  String get debugSnapshot => 'Live snapshot';

  @override
  String get debugAudioSession => 'Audio session';

  @override
  String get debugSafeAudioMode => 'Safe audio mode';

  @override
  String get debugSafeAudioHint =>
      'Disables the Android equalizer audio pipeline; restart the app for it to take effect.';

  @override
  String get debugSelfTest => 'Playback self-test';

  @override
  String get debugSelfTestHint =>
      'Plays the current track with a bare AudioPlayer to isolate whether the main pipeline is silent.';

  @override
  String get debugSelfTestStart => 'Start self-test';

  @override
  String get debugSelfTestStop => 'Stop self-test';

  @override
  String get debugSelfTestPlaying => 'Self-test playing…';

  @override
  String get debugSelfTestIdle => 'Self-test idle';

  @override
  String get debugNoTrack =>
      'Nothing is currently playing, so the self-test cannot start.';

  @override
  String get debugLog => 'Event log';

  @override
  String get debugLogEmpty => 'No log yet. Play a song to get started.';

  @override
  String get debugCopyLog => 'Copy log';

  @override
  String get debugCopied => 'Log copied to clipboard';

  @override
  String get debugStatus => 'Status';

  @override
  String get debugPlaying => 'Playing';

  @override
  String get debugPosition => 'Position';

  @override
  String get debugDuration => 'Duration';

  @override
  String get debugVolume => 'Volume';

  @override
  String get debugIndex => 'Index';

  @override
  String get debugQueueLen => 'Queue length';

  @override
  String get debugActive => 'Session active';

  @override
  String get debugOutputDevices => 'Output devices';

  @override
  String get debugSessionUnknown => 'Unknown';

  @override
  String get debugOutputDeviceDefault => 'Follow system default';

  @override
  String debugOutputDeviceApplied(Object name) {
    return 'Output device: $name';
  }

  @override
  String get debugOutputDeviceFailed => 'Failed to switch output device';

  @override
  String get addServerTitle => 'Add server';

  @override
  String get lanDiscovery => 'LAN discovery';

  @override
  String get lanRefresh => 'Refresh LAN search';

  @override
  String get searchingLan => 'Searching the local network for music servers…';

  @override
  String get noServersFound => 'No servers found';

  @override
  String get ensureSameNetwork =>
      'Make sure the device is on the same local network';

  @override
  String get manualAdd => 'Add manually';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String artistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get similarArtists => 'Similar Artists';

  @override
  String get artistBio => 'About Artist';

  @override
  String get viewGrid => 'Grid View';

  @override
  String get viewList => 'List View';

  @override
  String get sortNameAsc => 'Name (A-Z)';

  @override
  String get sortNameDesc => 'Name (Z-A)';

  @override
  String get sortAlbumCount => 'Album Count';

  @override
  String get sortYearDesc => 'Year (Newest)';

  @override
  String get sortYearAsc => 'Year (Oldest)';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get noSimilarArtists => 'No similar artists';

  @override
  String get filterArtistsHint => 'Filter artists...';

  @override
  String get discography => 'Discography';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get speedNormal => 'Normal (1.0x)';

  @override
  String get endOfSong => 'End of Current Track';

  @override
  String get coverView => 'Cover';

  @override
  String get lyricsView => 'Lyrics View';

  @override
  String get oledLyricsView => 'OLED Lyrics';

  @override
  String get songInfo => 'Song Info';

  @override
  String get trackDetails => 'Track Details';

  @override
  String get trackInfoTitle => 'Title';

  @override
  String get trackInfoArtist => 'Artist';

  @override
  String get trackInfoAlbum => 'Album';

  @override
  String get trackInfoDuration => 'Duration';

  @override
  String get trackInfoId => 'Track ID';

  @override
  String get audioQuality => 'Audio Quality';

  @override
  String get cancelSleepTimer => 'Cancel Sleep Timer';

  @override
  String get sleepTimerCancelled => 'Sleep timer cancelled';
}
