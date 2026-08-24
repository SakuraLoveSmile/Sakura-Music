import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../core/artwork_palette.dart';
import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';
import 'equalizer_panel.dart';
import 'lyrics/lyrics_view.dart';
import 'queue_panel.dart';
import 'smooth_position_builder.dart';

typedef _PlayerControlsState = ({
  PlayableItem? item,
  Duration? duration,
  bool playing,
  AppLoopMode loopMode,
  bool shuffle,
  double volume,
});

class _PlaybackLyrics extends StatelessWidget {
  const _PlaybackLyrics({required this.service, required this.item});

  final AudioPlayerService service;
  final PlayableItem item;

  @override
  Widget build(BuildContext context) {
    return SmoothPositionBuilder(
      service: service,
      builder: (context, position, controls) =>
          LyricsView(item: item, position: position, onSeek: service.seek),
    );
  }
}

class _AmbientPlayerBackground extends StatelessWidget {
  const _AmbientPlayerBackground({required this.item, required this.palette});

  final PlayableItem item;
  final ArtworkPalette? palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (item.artworkUrl != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Transform.scale(
                  scale: 1.15,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: CachedNetworkImage(
                      imageUrl: item.artworkUrl!,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.82),
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    (palette?.vibrant ?? const Color(0xFF1C1D24)).withValues(
                      alpha: 0.15,
                    ),
                    const Color(0xFF141416).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
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
            );
        final item = state.item;
        if (item == null) {
          return _EmptyPlayer(onBrowse: () => context.go('/home'));
        }

        final palette = item.artworkUrl == null
            ? null
            : ref.watch(artworkPaletteProvider(item.artworkUrl!)).value;
        final starredIds = ref.watch(starredIdsProvider);
        final isStarred = starredIds.songs.contains(item.id);

        return Scaffold(
          backgroundColor: const Color(0xFF141416),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: _AmbientPlayerBackground(item: item, palette: palette),
                ),
              ),

              // Main Layout Area
              SafeArea(
                child: Column(
                  children: <Widget>[
                    // Top Bar: Traffic lights / back & action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: context.l10n.collapsePlayer,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: context.l10n.equalizerTitle,
                            icon: const Icon(
                              Icons.equalizer_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () => showEqualizerPanel(context),
                          ),
                        ],
                      ),
                    ),

                    // Stage Area (Side by side on desktop, stacked on mobile)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 16,
                        ),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  // Left: Big Album Artwork
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 380,
                                          maxHeight: 380,
                                        ),
                                        child: AspectRatio(
                                          aspectRatio: 1.0,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: item.artworkUrl == null
                                                ? Container(
                                                    color: const Color(
                                                      0xFF22242D,
                                                    ),
                                                    child: const Icon(
                                                      Icons.album_rounded,
                                                      size: 96,
                                                      color: Colors.white24,
                                                    ),
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: item.artworkUrl!,
                                                    cacheKey:
                                                        item.artworkCacheKey,
                                                    fit: BoxFit.cover,
                                                    memCacheWidth: 600,
                                                    memCacheHeight: 600,
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          color: const Color(
                                                            0xFF22242D,
                                                          ),
                                                          child: const Icon(
                                                            Icons.album_rounded,
                                                            size: 96,
                                                            color:
                                                                Colors.white24,
                                                          ),
                                                        ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),

                                  // Right: Lyrics Display
                                  Expanded(
                                    flex: 6,
                                    child: _PlaybackLyrics(
                                      service: service,
                                      item: item,
                                    ),
                                  ),
                                ],
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableHeight =
                                      constraints.maxHeight.isFinite
                                      ? constraints.maxHeight
                                      : 620.0;
                                  final dimension = math.min(
                                    280.0,
                                    math.max(1.0, availableHeight * 0.42),
                                  );
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      SizedBox.square(
                                        dimension: dimension,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: item.artworkUrl == null
                                              ? Container(
                                                  color: const Color(
                                                    0xFF22242D,
                                                  ),
                                                  child: const Icon(
                                                    Icons.album_rounded,
                                                    size: 80,
                                                    color: Colors.white24,
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: item.artworkUrl!,
                                                  cacheKey:
                                                      item.artworkCacheKey,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 280,
                                                  memCacheHeight: 280,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Expanded(
                                        child: _PlaybackLyrics(
                                          service: service,
                                          item: item,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ),

                    // Bottom Playback Bar matching Screenshot 3
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
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: Color(0xFF16171D),
            border: Border(
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
                  width: 34,
                  height: 34,
                ),
                onPressed: service.previous,
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    if (state.playing) {
                      await service.pause();
                    } else {
                      await service.play();
                    }
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E7BF6),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF1E7BF6,
                          ).withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: context.l10n.nextTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                onPressed: service.next,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),

              // Thumbnail Cover
              SizedBox.square(
                dimension: 42,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
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
                constraints: const BoxConstraints(maxWidth: 150),
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
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Expanded(
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
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right Tools: Heart, Loop, Shuffle, Queue, Sleep, Cast, Pip, Volume
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.starFailed(err.toString())),
                        ),
                      );
                    }
                  }
                },
              ),
              if (isWide) ...[
                IconButton(
                  tooltip: _loopModeLabel(context, state.loopMode),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
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
                    size: 17,
                    color: state.loopMode != AppLoopMode.off
                        ? const Color(0xFF1E7BF6)
                        : Colors.white60,
                  ),
                ),
                IconButton(
                  tooltip: state.shuffle
                      ? context.l10n.shuffleOff
                      : context.l10n.shuffleOn,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => service.setShuffle(!state.shuffle),
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 17,
                    color: state.shuffle
                        ? const Color(0xFF1E7BF6)
                        : Colors.white60,
                  ),
                ),
              ],
              IconButton(
                tooltip: context.l10n.queueTitle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: () => showQueuePanel(context, service),
                icon: const Icon(
                  Icons.queue_music_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
              if (isWide) ...[
                IconButton(
                  tooltip: context.l10n.sleepTimer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => _showSleepTimer(context),
                  icon: const Icon(
                    Icons.timer_outlined,
                    size: 17,
                    color: Colors.white60,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.cast,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () {},
                  icon: const Icon(
                    Icons.cast_rounded,
                    size: 17,
                    color: Colors.white60,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.pictureInPicture,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () {},
                  icon: const Icon(
                    Icons.picture_in_picture_alt_rounded,
                    size: 17,
                    color: Colors.white60,
                  ),
                ),
              ],

              // Volume Slider
              if (isWide) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: state.volume == 0
                      ? context.l10n.unmute
                      : context.l10n.mute,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  onPressed: () {
                    service.setVolume(state.volume == 0 ? 1.0 : 0.0);
                  },
                  icon: Icon(
                    state.volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 7.0,
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
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
          activeTrackColor: const Color(0xFF1E7BF6),
          inactiveTrackColor: const Color(0xFF2A2C37),
          thumbColor: Colors.white,
        );

        return Container(
          height: 136,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          decoration: const BoxDecoration(
            color: Color(0xFF16171D),
            border: Border(top: BorderSide(color: Color(0xFF22242D), width: 1)),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 30,
                child: Row(
                  children: <Widget>[
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontSize: 11,
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
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: StarButton(
                          isStarred: isStarred,
                          size: 20,
                          onPressed: () async {
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
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: IconButton(
                          tooltip: context.l10n.previousTrack,
                          onPressed: service.previous,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
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
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                state.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 27,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: IconButton(
                          tooltip: context.l10n.nextTrack,
                          onPressed: service.next,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: IconButton(
                          tooltip: context.l10n.queueTitle,
                          onPressed: () => showQueuePanel(context, service),
                          icon: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      tooltip: _loopModeLabel(context, state.loopMode),
                      padding: EdgeInsets.zero,
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
                        color: state.loopMode == AppLoopMode.off
                            ? Colors.white60
                            : const Color(0xFF1E7BF6),
                      ),
                    ),
                    const SizedBox(width: 28),
                    IconButton(
                      tooltip: state.shuffle
                      ? context.l10n.shuffleOff
                      : context.l10n.shuffleOn,
                      padding: EdgeInsets.zero,
                      onPressed: () => service.setShuffle(!state.shuffle),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: state.shuffle
                            ? const Color(0xFF1E7BF6)
                            : Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 28),
                    IconButton(
                      tooltip: context.l10n.sleepTimer,
                      padding: EdgeInsets.zero,
                      onPressed: () => _showSleepTimer(context),
                      icon: const Icon(
                        Icons.timer_outlined,
                        color: Colors.white60,
                      ),
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

  void _showSleepTimer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: Text(
          dialogContext.l10n.sleepTimerTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final minutes in <int>[15, 30, 60])
              ListTile(
                title: Text(
                  dialogContext.l10n.minutesLabel(minutes),
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        dialogContext.l10n.sleepTimerSet(minutes),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
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
            const Icon(
              Icons.music_note_rounded,
              size: 72,
              color: Color(0xFF1E7BF6),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E7BF6),
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
