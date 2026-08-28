import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../core/artwork_palette.dart';
import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';
import 'audio_stream_inspector_sheet.dart';
import 'discovery/track_discovery_sheet.dart';
import 'equalizer_panel.dart';
import 'lyrics/lyrics_view.dart';
import 'lyrics/oled_lyrics_stage.dart';
import 'queue_panel.dart';
import 'quick_add_to_playlist_sheet.dart';
import 'smooth_position_builder.dart';
import 'vinyl/vinyl_turntable_stage.dart';

typedef _PlayerControlsState = ({
  PlayableItem? item,
  Duration? duration,
  bool playing,
  AppLoopMode loopMode,
  bool shuffle,
  double volume,
  double speed,
  int queueLength,
  int? currentIndex,
});

enum _MobileStageMode { cover, vinyl, lyrics, oled }

class _PlaybackLyrics extends StatelessWidget {
  const _PlaybackLyrics({
    required this.service,
    required this.item,
    this.textAlign = TextAlign.center,
  });

  final AudioPlayerService service;
  final PlayableItem item;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return SmoothPositionBuilder(
      service: service,
      builder: (context, position, controls) => LyricsView(
        item: item,
        position: position,
        onSeek: service.seek,
        textAlign: textAlign,
      ),
    );
  }
}

class _AmbientPlayerBackground extends StatefulWidget {
  const _AmbientPlayerBackground({
    required this.item,
    required this.palette,
    this.playing = false,
  });

  final PlayableItem item;
  final ArtworkPalette? palette;
  final bool playing;

  @override
  State<_AmbientPlayerBackground> createState() => _AmbientPlayerBackgroundState();
}

class _AmbientPlayerBackgroundState extends State<_AmbientPlayerBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.playing) {
      _flowController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AmbientPlayerBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _flowController.repeat();
      } else {
        _flowController.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibrant = widget.palette?.vibrant ?? const Color(0xFF1E7BF6);
    final muted = widget.palette?.muted ?? const Color(0xFF1B1D28);

    return AnimatedBuilder(
      animation: _flowController,
      builder: (context, child) {
        final t = _flowController.value * 2 * math.pi;
        final dx = math.sin(t) * 0.25;
        final dy = math.cos(t) * 0.18 - 0.35;

        return Stack(
          children: <Widget>[
            // Base dark backdrop
            Positioned.fill(child: Container(color: const Color(0xFF0E0F13))),

            // Blurred Artwork Image
            if (widget.item.artworkUrl != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Transform.scale(
                      scale: 1.25,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                        child: CachedNetworkImage(
                          imageUrl: widget.item.artworkUrl!,
                          fit: BoxFit.cover,
                          color: Colors.black.withValues(alpha: 0.75),
                          colorBlendMode: BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Dynamic fluid multi-stop radial glow from palette
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(dx, dy),
                      radius: 1.15 + (math.sin(t * 2) * 0.1),
                      colors: <Color>[
                        vibrant.withValues(alpha: 0.34),
                        muted.withValues(alpha: 0.24),
                        const Color(0xFF0E0F13).withValues(alpha: 0.96),
                      ],
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Secondary complementary floating aurora orb
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-dx * 1.2, -dy * 0.8),
                      radius: 0.9,
                      colors: <Color>[
                        muted.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Linear vertical gradient for crisp readability
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                        const Color(0xFF0E0F13).withValues(alpha: 0.98),
                      ],
                      stops: const <double>[0.0, 0.3, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  _MobileStageMode _mobileMode = _MobileStageMode.cover;
  double _swipeDragDx = 0.0;
  String? _seekFeedbackToast;
  Timer? _seekFeedbackTimer;

  bool get _isMobilePlatform {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    super.dispose();
  }

  void _showSeekFeedback(String text) {
    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedbackToast = text);
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _seekFeedbackToast = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(audioPlayerProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final current = service.currentSnapshot;

    return StreamBuilder<_PlayerControlsState>(
      stream: service.snapshot
          .map(
            (state) => (
              item: state.currentItem,
              duration: state.duration,
              playing: state.playing,
              loopMode: state.loopMode,
              shuffle: state.shuffle,
              volume: state.volume,
              speed: state.speed,
              queueLength: state.queue.length,
              currentIndex: state.currentIndex,
            ),
          )
          .distinct(),
      initialData: (
        item: current?.currentItem,
        duration: current?.duration,
        playing: current?.playing ?? false,
        loopMode: current?.loopMode ?? AppLoopMode.off,
        shuffle: current?.shuffle ?? false,
        volume: current?.volume ?? 1.0,
        speed: current?.speed ?? 1.0,
        queueLength: current?.queue.length ?? 0,
        currentIndex: current?.currentIndex,
      ),
      builder: (context, snapshot) {
        final state =
            snapshot.data ??
            (
              item: null,
              duration: null,
              playing: false,
              loopMode: AppLoopMode.off,
              shuffle: false,
              volume: 1.0,
              speed: 1.0,
              queueLength: 0,
              currentIndex: null,
            );
        final item = state.item;
        if (item == null) {
          return _EmptyPlayer(onBrowse: () => context.go('/home'));
        }

        final showOled = _mobileMode == _MobileStageMode.oled;
        if (showOled) {
          return OledLyricsStage(
            service: service,
            item: item,
            playing: state.playing,
            duration: state.duration ?? item.duration ?? Duration.zero,
            onExit: () => setState(() => _mobileMode = _MobileStageMode.cover),
          );
        }

        final palette = item.artworkUrl == null
            ? null
            : ref.watch(artworkPaletteProvider(item.artworkUrl!)).value;
        final starredIds = ref.watch(starredIdsProvider);
        final isStarred = starredIds.songs.contains(item.id);

        return Scaffold(
          backgroundColor: const Color(0xFF0E0F13),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: _AmbientPlayerBackground(
                    item: item,
                    palette: palette,
                    playing: state.playing,
                  ),
                ),
              ),

              // Main Layout Area
              SafeArea(
                child: Column(
                  children: <Widget>[
                    // Top Bar
                    _buildTopBar(
                      context: context,
                      item: item,
                      isWide: isWide,
                      palette: palette,
                      service: service,
                      state: state,
                    ),

                    // Stage Area (Split on Desktop, Interactive Switcher on Mobile)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 40 : 20,
                          vertical: isWide ? 16 : 8,
                        ),
                        child: isWide
                            ? _buildDesktopStage(
                                context: context,
                                service: service,
                                item: item,
                                palette: palette,
                                isStarred: isStarred,
                                playing: state.playing,
                              )
                            : _buildMobileStage(
                                context: context,
                                service: service,
                                item: item,
                                palette: palette,
                                isStarred: isStarred,
                                playing: state.playing,
                              ),
                      ),
                    ),

                    // Bottom Playback Dock
                    _buildBottomDock(
                      context: context,
                      service: service,
                      state: state,
                      item: item,
                      isStarred: isStarred,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar({
    required BuildContext context,
    required PlayableItem item,
    required bool isWide,
    required ArtworkPalette? palette,
    required AudioPlayerService service,
    required _PlayerControlsState state,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: <Widget>[
          // Collapse button
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: context.l10n.collapsePlayer,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 26,
                color: Colors.white,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),

          const Spacer(),

          // Mobile Mode Switcher Pill (Cover / Lyrics / OLED)
          if (!isWide && _isMobilePlatform)
            Container(
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildSegmentButton(
                    title: context.l10n.coverView,
                    icon: Icons.album_rounded,
                    isSelected: _mobileMode == _MobileStageMode.cover,
                    onTap: () {
                      if (_mobileMode != _MobileStageMode.cover) {
                        setState(() => _mobileMode = _MobileStageMode.cover);
                      }
                    },
                  ),
                  _buildSegmentButton(
                    title: context.l10n.vinylView,
                    icon: Icons.radio_rounded,
                    isSelected: _mobileMode == _MobileStageMode.vinyl,
                    onTap: () {
                      if (_mobileMode != _MobileStageMode.vinyl) {
                        setState(() => _mobileMode = _MobileStageMode.vinyl);
                      }
                    },
                  ),
                  _buildSegmentButton(
                    title: context.l10n.lyrics,
                    icon: Icons.lyrics_rounded,
                    isSelected: _mobileMode == _MobileStageMode.lyrics,
                    onTap: () {
                      if (_mobileMode != _MobileStageMode.lyrics) {
                        setState(() => _mobileMode = _MobileStageMode.lyrics);
                      }
                    },
                  ),
                  _buildSegmentButton(
                    title: context.l10n.oledLyricsView,
                    icon: Icons.dark_mode_rounded,
                    isSelected: _mobileMode == _MobileStageMode.oled,
                    onTap: () {
                      if (_mobileMode != _MobileStageMode.oled) {
                        setState(() => _mobileMode = _MobileStageMode.oled);
                      }
                    },
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Equalizer button
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: context.l10n.equalizerTitle,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.equalizer_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => showEqualizerPanel(context),
            ),
          ),
          const SizedBox(width: 8),

          // More Options Popup Menu
          PopupMenuButton<String>(
            tooltip: context.l10n.more,
            offset: const Offset(0, 42),
            color: const Color(0xFF22252E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              switch (value) {
                case 'discovery':
                  showTrackDiscoverySheet(context, item: item, service: service);
                case 'playlist':
                  showQuickAddToPlaylistSheet(context, item: item);
                case 'inspector':
                  showAudioStreamInspectorSheet(context, item: item);
                case 'details':
                  _showSongDetailsDialog(context, item);
                case 'speed':
                  _showPlaybackSpeedModal(context, service, state.speed);
                case 'sleep':
                  _showSleepTimerModal(context, service);
                case 'artist':
                  if (item.artistId != null && item.artistId!.isNotEmpty) {
                    context.go(
                      '/artists/${Uri.encodeComponent(item.artistId!)}',
                    );
                  } else if (item.artist != null && item.artist!.isNotEmpty) {
                    context.go(
                      '/search?q=${Uri.encodeComponent(item.artist!)}',
                    );
                  }
                case 'album':
                  if (item.albumId != null && item.albumId!.isNotEmpty) {
                    context.go('/albums/${Uri.encodeComponent(item.albumId!)}');
                  } else if (item.album != null && item.album!.isNotEmpty) {
                    context.go('/search?q=${Uri.encodeComponent(item.album!)}');
                  }
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'discovery',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.explore_rounded,
                      size: 18,
                      color: Color(0xFF5BA4FF),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.discovery,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5BA4FF)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'playlist',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.playlist_add_rounded,
                      size: 18,
                      color: Color(0xFF5BA4FF),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.addToPlaylist,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'inspector',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 18,
                      color: Color(0xFF5BA4FF),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.audioStreamInspector,
                      style: const TextStyle(color: Color(0xFF5BA4FF), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'details',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Text(context.l10n.songInfo),
                  ],
                ),
              ),
              if ((item.artistId != null && item.artistId!.isNotEmpty) ||
                  (item.artist != null && item.artist!.isNotEmpty))
                PopupMenuItem<String>(
                  value: 'artist',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.viewArtist),
                    ],
                  ),
                ),
              if ((item.albumId != null && item.albumId!.isNotEmpty) ||
                  (item.album != null && item.album!.isNotEmpty))
                PopupMenuItem<String>(
                  value: 'album',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.album_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.viewAlbum),
                    ],
                  ),
                ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'speed',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.speed_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Text('${context.l10n.playbackSpeed} (${state.speed}x)'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'sleep',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Text(context.l10n.sleepTimer),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 9 : 7,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E7BF6) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStage({
    required BuildContext context,
    required AudioPlayerService service,
    required PlayableItem item,
    required ArtworkPalette? palette,
    required bool isStarred,
    required bool playing,
  }) {
    final glowColor = (palette?.vibrant ?? const Color(0xFF1E7BF6)).withValues(
      alpha: playing ? 0.38 : 0.12,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Left Column: Artwork + Song Details
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Big Album Artwork with breathing scale and glowing shadow
              AnimatedScale(
                scale: playing ? 1.0 : 0.91,
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 340),
                  constraints: const BoxConstraints(
                    maxWidth: 360,
                    maxHeight: 360,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: glowColor,
                        blurRadius: playing ? 32 : 12,
                        spreadRadius: playing ? -2 : -6,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: playing ? 0.55 : 0.3),
                        blurRadius: playing ? 20 : 10,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: item.artworkUrl == null
                          ? Container(
                              color: const Color(0xFF22242D),
                              child: const Icon(
                                Icons.album_rounded,
                                size: 100,
                                color: Colors.white24,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.artworkUrl!,
                              cacheKey: item.artworkCacheKey,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              memCacheHeight: 600,
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF22242D),
                                child: const Icon(
                                  Icons.album_rounded,
                                  size: 100,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 6),

              // Artist & Album
              Text(
                [
                      item.artist,
                      item.album,
                    ].whereType<String>().join(' · ').isEmpty
                    ? context.l10n.nowPlaying
                    : [item.artist, item.album].whereType<String>().join(' · '),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              // Audio Quality Capsule Badge
              AudioStreamQualityBadge(item: item),
            ],
          ),
        ),

        const SizedBox(width: 48),

        // Right Column: Lyrics
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PlaybackLyrics(
              service: service,
              item: item,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStage({
    required BuildContext context,
    required AudioPlayerService service,
    required PlayableItem item,
    required ArtworkPalette? palette,
    required bool isStarred,
    required bool playing,
  }) {
    if (_mobileMode == _MobileStageMode.lyrics) {
      return Column(
        children: <Widget>[
          // Mini Track Header in lyrics mode (tap to return to cover mode)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _mobileMode = _MobileStageMode.cover),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 36,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.artworkUrl == null
                          ? Container(
                              color: const Color(0xFF22242D),
                              child: const Icon(
                                Icons.album_rounded,
                                size: 20,
                                color: Colors.white24,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.artworkUrl!,
                              cacheKey: item.artworkCacheKey,
                              fit: BoxFit.cover,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.artist ?? context.l10n.unknownArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.photo_outlined,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Full-screen Lyrics
          Expanded(
            child: _PlaybackLyrics(
              service: service,
              item: item,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    // Vinyl Turntable Mode
    if (_mobileMode == _MobileStageMode.vinyl) {
      return VinylTurntableStage(
        item: item,
        service: service,
        playing: playing,
        palette: palette,
        isStarred: isStarred,
        onTap: () => setState(() => _mobileMode = _MobileStageMode.lyrics),
      );
    }

    // Cover Mode
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0;
        final coverDimension = math.min(
          320.0,
          math.max(140.0, availableHeight * 0.44),
        );
        final glowColor = (palette?.vibrant ?? const Color(0xFF1E7BF6))
            .withValues(alpha: playing ? 0.36 : 0.08);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Album Artwork with Horizontal Swipe, Double-Tap Seek, and Tap to Lyrics
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _mobileMode = _MobileStageMode.lyrics),
              onDoubleTapDown: (details) async {
                final localX = details.localPosition.dx;
                final pos = service.currentSnapshot?.position ?? Duration.zero;
                final dur = service.currentSnapshot?.duration ?? item.duration ?? Duration.zero;

                if (localX < coverDimension / 2) {
                  // Rewind 10s
                  final target = pos - const Duration(seconds: 10);
                  await service.seek(target < Duration.zero ? Duration.zero : target);
                  HapticFeedback.lightImpact();
                  _showSeekFeedback('-10s');
                } else {
                  // Forward 10s
                  final target = pos + const Duration(seconds: 10);
                  await service.seek(target > dur ? dur : target);
                  HapticFeedback.lightImpact();
                  _showSeekFeedback('+10s');
                }
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _swipeDragDx += details.primaryDelta ?? 0;
                });
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_swipeDragDx < -45 || velocity < -250) {
                  HapticFeedback.mediumImpact();
                  service.next();
                } else if (_swipeDragDx > 45 || velocity > 250) {
                  HapticFeedback.mediumImpact();
                  service.previous();
                }
                setState(() => _swipeDragDx = 0.0);
              },
              onHorizontalDragCancel: () {
                setState(() => _swipeDragDx = 0.0);
              },
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Transform.translate(
                    offset: Offset(_swipeDragDx * 0.4, 0),
                    child: Transform.rotate(
                      angle: _swipeDragDx * 0.00025,
                      child: AnimatedScale(
                        scale: playing ? 1.0 : 0.91,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          width: coverDimension,
                          height: coverDimension,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: glowColor,
                                blurRadius: playing ? 28 : 10,
                                spreadRadius: playing ? -2 : -6,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: playing ? 0.45 : 0.25,
                                ),
                                blurRadius: playing ? 16 : 8,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: item.artworkUrl == null
                                ? Container(
                                    color: const Color(0xFF22242D),
                                    child: const Icon(
                                      Icons.album_rounded,
                                      size: 80,
                                      color: Colors.white24,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: item.artworkUrl!,
                                    cacheKey: item.artworkCacheKey,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    memCacheHeight: 400,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Seek Feedback Toast Pill
                  if (_seekFeedbackToast != null)
                    AnimatedOpacity(
                      opacity: _seekFeedbackToast != null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _seekFeedbackToast == '-10s'
                                  ? Icons.replay_10_rounded
                                  : Icons.forward_10_rounded,
                              size: 20,
                              color: const Color(0xFF5BA4FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _seekFeedbackToast == '-10s'
                                  ? context.l10n.rewind10s
                                  : context.l10n.forward10s,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Track Title & Star Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                                item.artist,
                                item.album,
                              ].whereType<String>().join(' · ').isEmpty
                              ? context.l10n.nowPlaying
                              : [
                                  item.artist,
                                  item.album,
                                ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Audio Quality Badge
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AudioStreamQualityBadge(item: item),
                        ),
                      ],
                    ),
                  ),
                  StarButton(
                    isStarred: isStarred,
                    size: 22,
                    onPressed: () async {
                      try {
                        await ref
                            .read(starredProvider.notifier)
                            .toggleSong(
                              Song(
                                id: item.id,
                                title: item.title,
                                artist: item.artist,
                                album: item.album,
                              ),
                            );
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.starFailed(err.toString()),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Compact Lyrics Preview Card
            Expanded(
              child: Center(
                child: SmoothPositionBuilder(
                  service: service,
                  builder: (context, position, controls) =>
                      CompactLyricsPreview(
                        item: item,
                        position: position,
                        onTap: () => setState(
                          () => _mobileMode = _MobileStageMode.lyrics,
                        ),
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomDock({
    required BuildContext context,
    required AudioPlayerService service,
    required _PlayerControlsState state,
    required PlayableItem item,
    required bool isStarred,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final duration = state.duration ?? item.duration ?? Duration.zero;

    if (!isWide) {
      return _buildNarrowBottomDock(
        context: context,
        service: service,
        state: state,
        item: item,
        isStarred: isStarred,
        duration: duration,
      );
    }

    return SmoothPositionBuilder(
      service: service,
      duration: duration,
      builder: (context, position, controls) {
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final posMs = position.inMilliseconds
            .clamp(0, maxMs.toInt())
            .toDouble();

        return Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF14151B).withValues(alpha: 0.95),
            border: const Border(
              top: BorderSide(color: Color(0xFF22242D), width: 1.0),
            ),
          ),
          child: Row(
            children: <Widget>[
              // Left Playback Controls: Prev, Big Blue Play/Pause, Next
              IconButton(
                tooltip: context.l10n.previousTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: service.previous,
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(23),
                  onTap: () async {
                    if (state.playing) {
                      await service.pause();
                    } else {
                      await service.play();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E7BF6),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF1E7BF6,
                          ).withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: context.l10n.nextTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: service.next,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),

              // Thumbnail Cover
              SizedBox.square(
                dimension: 42,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.artworkUrl == null
                      ? Container(
                          color: const Color(0xFF22242D),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF1E7BF6),
                            size: 20,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.artworkUrl!,
                          cacheKey: item.artworkCacheKey,
                          memCacheWidth: 84,
                          memCacheHeight: 84,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Title & Artist
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                            item.artist,
                            item.album,
                          ].whereType<String>().join(' · ').isEmpty
                          ? context.l10n.nowPlaying
                          : [
                              item.artist,
                              item.album,
                            ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Horizontal Progress Slider across center
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 9.0,
                          ),
                          activeTrackColor: const Color(0xFF1E7BF6),
                          inactiveTrackColor: const Color(0xFF2A2C37),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: posMs,
                          max: maxMs,
                          onChanged: duration == Duration.zero
                              ? null
                              : (val) => controls.seek(
                                  Duration(milliseconds: val.round()),
                                ),
                          onChangeEnd: duration == Duration.zero
                              ? null
                              : (_) => controls.seekEnd(),
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Tools
              StarButton(
                isStarred: isStarred,
                size: 18,
                onPressed: () async {
                  try {
                    await ref
                        .read(starredProvider.notifier)
                        .toggleSong(
                          Song(
                            id: item.id,
                            title: item.title,
                            artist: item.artist,
                            album: item.album,
                          ),
                        );
                  } catch (err) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.starFailed(err.toString()),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 4),

              // Playback Speed pill button
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () =>
                    _showPlaybackSpeedModal(context, service, state.speed),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${state.speed}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Loop mode
              IconButton(
                tooltip: _loopModeLabel(context, state.loopMode),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () {
                  final next = switch (state.loopMode) {
                    AppLoopMode.off => AppLoopMode.all,
                    AppLoopMode.all => AppLoopMode.one,
                    AppLoopMode.one => AppLoopMode.off,
                  };
                  service.setLoopMode(next);
                },
                icon: Icon(
                  _loopModeIcon(state.loopMode),
                  size: 18,
                  color: state.loopMode != AppLoopMode.off
                      ? const Color(0xFF1E7BF6)
                      : Colors.white60,
                ),
              ),

              // Shuffle mode
              IconButton(
                tooltip: state.shuffle
                    ? context.l10n.shuffleOff
                    : context.l10n.shuffleOn,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => service.setShuffle(!state.shuffle),
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 18,
                  color: state.shuffle
                      ? const Color(0xFF1E7BF6)
                      : Colors.white60,
                ),
              ),

              // Queue Button with track index
              IconButton(
                tooltip: context.l10n.queueTitle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => showQueuePanel(context, service),
                icon: Badge(
                  isLabelVisible: state.queueLength > 0,
                  label: Text(
                    state.currentIndex != null
                        ? '${state.currentIndex! + 1}'
                        : '${state.queueLength}',
                    style: const TextStyle(fontSize: 9),
                  ),
                  backgroundColor: const Color(0xFF1E7BF6),
                  child: const Icon(
                    Icons.queue_music_rounded,
                    size: 19,
                    color: Colors.white70,
                  ),
                ),
              ),

              // Add to playlist
              IconButton(
                tooltip: context.l10n.addToPlaylist,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => showQuickAddToPlaylistSheet(context, item: item),
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  size: 19,
                  color: Colors.white60,
                ),
              ),

              // Discovery & Similar
              IconButton(
                tooltip: context.l10n.discovery,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => showTrackDiscoverySheet(context, item: item, service: service),
                icon: const Icon(
                  Icons.explore_outlined,
                  size: 19,
                  color: Colors.white60,
                ),
              ),

              // Sleep timer
              IconButton(
                tooltip: context.l10n.sleepTimer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => _showSleepTimerModal(context, service),
                icon: const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Colors.white60,
                ),
              ),

              // Volume Slider
              const SizedBox(width: 4),
              IconButton(
                tooltip: state.volume == 0
                    ? context.l10n.unmute
                    : context.l10n.mute,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: () {
                  service.setVolume(state.volume == 0 ? 1.0 : 0.0);
                },
                icon: Icon(
                  state.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 17,
                  color: Colors.white70,
                ),
              ),
              SizedBox(
                width: 76,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8.0,
                    ),
                    activeTrackColor: const Color(0xFF1E7BF6),
                    inactiveTrackColor: const Color(0xFF2C2E38),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: state.volume.clamp(0.0, 1.0),
                    onChanged: (val) => service.setVolume(val),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNarrowBottomDock({
    required BuildContext context,
    required AudioPlayerService service,
    required _PlayerControlsState state,
    required PlayableItem item,
    required bool isStarred,
    required Duration duration,
  }) {
    return SmoothPositionBuilder(
      service: service,
      duration: duration,
      builder: (context, position, controls) {
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final posMs = position.inMilliseconds
            .clamp(0, maxMs.toInt())
            .toDouble();
        final sliderTheme = SliderTheme.of(context).copyWith(
          trackHeight: 3.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 9.0),
          activeTrackColor: const Color(0xFF1E7BF6),
          inactiveTrackColor: const Color(0xFF2A2C37),
          thumbColor: Colors.white,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14151B).withValues(alpha: 0.96),
            border: const Border(
              top: BorderSide(color: Color(0xFF22242D), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Progress Slider & Timestamps
              SizedBox(
                height: 28,
                child: Row(
                  children: <Widget>[
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: sliderTheme,
                        child: Slider(
                          value: posMs,
                          max: maxMs,
                          onChanged: duration == Duration.zero
                              ? null
                              : (value) => controls.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                          onChangeEnd: duration == Duration.zero
                              ? null
                              : (_) => controls.seekEnd(),
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Main Hero Playback Controls: Loop, Prev, Play/Pause, Next, Queue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    tooltip: _loopModeLabel(context, state.loopMode),
                    onPressed: () {
                      final next = switch (state.loopMode) {
                        AppLoopMode.off => AppLoopMode.all,
                        AppLoopMode.all => AppLoopMode.one,
                        AppLoopMode.one => AppLoopMode.off,
                      };
                      service.setLoopMode(next);
                    },
                    icon: Icon(
                      _loopModeIcon(state.loopMode),
                      size: 22,
                      color: state.loopMode == AppLoopMode.off
                          ? Colors.white60
                          : const Color(0xFF1E7BF6),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.previousTrack,
                    onPressed: service.previous,
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () async {
                        if (state.playing) {
                          await service.pause();
                        } else {
                          await service.play();
                        }
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E7BF6),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(
                                0xFF1E7BF6,
                              ).withValues(alpha: 0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          state.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.nextTrack,
                    onPressed: service.next,
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.queueTitle,
                    onPressed: () => showQueuePanel(context, service),
                    icon: Badge(
                      isLabelVisible: state.queueLength > 0,
                      label: Text(
                        state.currentIndex != null
                            ? '${state.currentIndex! + 1}'
                            : '${state.queueLength}',
                        style: const TextStyle(fontSize: 9),
                      ),
                      backgroundColor: const Color(0xFF1E7BF6),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        size: 22,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Secondary Quick Action Row: Shuffle, Speed, Add to Playlist, Discovery, Sleep Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  IconButton(
                    tooltip: state.shuffle
                        ? context.l10n.shuffleOff
                        : context.l10n.shuffleOn,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 32,
                    ),
                    onPressed: () => service.setShuffle(!state.shuffle),
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 20,
                      color: state.shuffle
                          ? const Color(0xFF1E7BF6)
                          : Colors.white60,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        _showPlaybackSpeedModal(context, service, state.speed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.speed_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${state.speed}x',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.addToPlaylist,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 32,
                    ),
                    onPressed: () => showQuickAddToPlaylistSheet(context, item: item),
                    icon: const Icon(
                      Icons.playlist_add_rounded,
                      size: 20,
                      color: Colors.white60,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.discovery,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 32,
                    ),
                    onPressed: () => showTrackDiscoverySheet(context, item: item, service: service),
                    icon: const Icon(
                      Icons.explore_outlined,
                      size: 20,
                      color: Colors.white60,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.sleepTimer,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 32,
                    ),
                    onPressed: () => _showSleepTimerModal(context, service),
                    icon: const Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Timer? _activeSleepTimer;
  static Timer? _sleepFadeTimer;
  static int? _activeSleepMinutes;

  void _setSleepTimer(BuildContext context, AudioPlayerService service, int minutes) {
    _activeSleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    _activeSleepMinutes = minutes;

    final totalDuration = Duration(minutes: minutes);
    final fadeStartDelay = totalDuration > const Duration(seconds: 25)
        ? totalDuration - const Duration(seconds: 20)
        : Duration.zero;

    _sleepFadeTimer = Timer(fadeStartDelay, () async {
      final initialVol = service.currentSnapshot?.volume ?? 1.0;
      const fadeSteps = 8;
      for (int i = 1; i <= fadeSteps; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (_activeSleepTimer == null) break;
        final vol = initialVol * (1.0 - (i / fadeSteps));
        await service.setVolume(vol.clamp(0.0, 1.0));
      }
    });

    _activeSleepTimer = Timer(totalDuration, () async {
      await service.pause();
      await service.setVolume(1.0);
      _activeSleepTimer = null;
      _sleepFadeTimer = null;
      _activeSleepMinutes = null;
    });
  }

  void _cancelSleepTimer() {
    _activeSleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    _activeSleepTimer = null;
    _sleepFadeTimer = null;
    _activeSleepMinutes = null;
  }

  void _showSleepTimerModal(BuildContext context, AudioPlayerService service) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1D26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.timer_outlined,
                    color: Color(0xFF1E7BF6),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sheetContext.l10n.sleepTimerTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_activeSleepMinutes != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E7BF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeSleepMinutes}m',
                        style: const TextStyle(
                          color: Color(0xFF5BA4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <int>[15, 30, 45, 60, 90].map((minutes) {
                  final isActive = _activeSleepMinutes == minutes;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _setSleepTimer(context, service, minutes);
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.sleepTimerSet(minutes)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1E7BF6)
                            : const Color(0xFF242733),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF1E7BF6)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        sheetContext.l10n.minutesLabel(minutes),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.music_off_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  sheetContext.l10n.endOfSong,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.endOfSong)),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.close_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(
                  sheetContext.l10n.cancelSleepTimer,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
                onTap: () {
                  _cancelSleepTimer();
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.sleepTimerCancelled)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaybackSpeedModal(
    BuildContext context,
    AudioPlayerService service,
    double currentSpeed,
  ) {
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1D26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.speed_rounded,
                    color: Color(0xFF1E7BF6),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sheetContext.l10n.playbackSpeed,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: speeds.map((speed) {
                  final isSelected = (speed - currentSpeed).abs() < 0.01;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      service.setSpeed(speed);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E7BF6)
                            : const Color(0xFF242733),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E7BF6)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        speed == 1.0 ? '1.0x (标准)' : '${speed}x',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongDetailsDialog(BuildContext context, PlayableItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF1E7BF6),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              dialogContext.l10n.trackDetails,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _detailRow(dialogContext.l10n.trackInfoTitle, item.title),
            _songDetailRow(
              dialogContext.l10n.trackInfoArtist,
              item.artist ?? dialogContext.l10n.unknownArtist,
              item.artistId != null && item.artistId!.isNotEmpty
                  ? () {
                      Navigator.of(dialogContext).pop();
                      context.go(
                        '/artists/${Uri.encodeComponent(item.artistId!)}',
                      );
                    }
                  : null,
            ),
            _songDetailRow(
              dialogContext.l10n.trackInfoAlbum,
              item.album ?? dialogContext.l10n.noContentYet,
              item.albumId != null && item.albumId!.isNotEmpty
                  ? () {
                      Navigator.of(dialogContext).pop();
                      context.go(
                        '/albums/${Uri.encodeComponent(item.albumId!)}',
                      );
                    }
                  : null,
            ),
            if (item.duration != null)
              _detailRow(
                dialogContext.l10n.trackInfoDuration,
                _formatDuration(item.duration!),
              ),
            _detailRow(dialogContext.l10n.trackInfoId, item.id),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              dialogContext.l10n.gotIt,
              style: const TextStyle(color: Color(0xFF1E7BF6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7BF6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 64,
                color: Color(0xFF1E7BF6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.emptyPlayerTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.emptyPlayerDesc,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E7BF6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.explore_rounded),
              label: Text(context.l10n.goDiscover),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

IconData _loopModeIcon(AppLoopMode mode) {
  return switch (mode) {
    AppLoopMode.off => Icons.repeat_rounded,
    AppLoopMode.all => Icons.repeat_rounded,
    AppLoopMode.one => Icons.repeat_one_rounded,
  };
}

String _loopModeLabel(BuildContext context, AppLoopMode mode) {
  return switch (mode) {
    AppLoopMode.off => context.l10n.loopOff,
    AppLoopMode.all => context.l10n.loopAll,
    AppLoopMode.one => context.l10n.loopOne,
  };
}

/// A song-info dialog row. When [onTap] is provided the value is rendered as a
/// tappable link that navigates to the matching artist/album page.
Widget _songDetailRow(String label, String value, VoidCallback? onTap) {
  final content = Text(
    value,
    style: TextStyle(
      color: onTap != null ? const Color(0xFF1E7BF6) : Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
        Expanded(
          child: onTap != null
              ? InkWell(onTap: onTap, child: content)
              : content,
        ),
      ],
    ),
  );
}
