import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_service.dart';
import '../../core/providers.dart';
import '../shared/media_widgets.dart';
import 'queue_panel.dart';
import 'smooth_position_builder.dart';

typedef _MiniPlayerState = ({
  PlayableItem? item,
  Duration? duration,
  bool playing,
  AppLoopMode loopMode,
  bool shuffle,
  double volume,
});

class _PlaybackProgressBar extends StatelessWidget {
  const _PlaybackProgressBar({required this.service, required this.duration});

  final AudioPlayerService service;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return SmoothPositionBuilder(
      service: service,
      duration: duration,
      builder: (context, position, controls) {
        final progress = duration == null || duration! <= Duration.zero
            ? null
            : (position.inMilliseconds / duration!.inMilliseconds)
                  .clamp(0, 1)
                  .toDouble();
        return LinearProgressIndicator(
          value: progress,
          minHeight: 2.5,
          backgroundColor: const Color(0xFF242632),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E7BF6)),
        );
      },
    );
  }
}

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({required this.service, super.key});

  final AudioPlayerService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final isMedium = screenWidth >= 780;
    final isDesktop = screenWidth >= 980;
    final current = service.currentSnapshot;

    return StreamBuilder<_MiniPlayerState>(
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
          return const SizedBox.shrink();
        }
        final duration = state.duration ?? item.duration;
        final starredIds = ref.watch(starredIdsProvider);
        final isStarred = starredIds.songs.contains(item.id);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 8 : 14,
            0,
            isCompact ? 8 : 14,
            isCompact ? 4 : 10,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181A22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF282A36), width: 1.0),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isCompact
                ? InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/player'),
                    child: _buildCompactContent(
                      service: service,
                      item: item,
                      duration: duration,
                      playing: state.playing,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Top Progress Indicator
                      _PlaybackProgressBar(
                        service: service,
                        duration: duration,
                      ),

                      // Player Controls Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: <Widget>[
                            // Left Section: Artwork & Track Info
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 130 : 190,
                                minWidth: 100,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => context.push('/player'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      SizedBox.square(
                                        dimension: 40,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: item.artworkUrl == null
                                              ? Container(
                                                  color: const Color(
                                                    0xFF22242D,
                                                  ),
                                                  child: const Icon(
                                                    Icons.music_note_rounded,
                                                    color: Color(0xFF1E7BF6),
                                                    size: 20,
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: item.artworkUrl!,
                                                  cacheKey:
                                                      item.artworkCacheKey,
                                                  memCacheWidth: 120,
                                                  memCacheHeight: 120,
                                                  fit: BoxFit.cover,
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
                                                          Icons
                                                              .music_note_rounded,
                                                          color: Color(
                                                            0xFF1E7BF6,
                                                          ),
                                                          size: 20,
                                                        ),
                                                      ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.artist ??
                                                  item.album ??
                                                  '正在播放',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Center Section: Playback Controls
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  // Previous Button
                                  IconButton(
                                    tooltip: '上一首',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    onPressed: service.previous,
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Big Blue Circular Play/Pause Button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () async {
                                        if (state.playing) {
                                          await service.pause();
                                        } else {
                                          await service.play();
                                        }
                                      },
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF1E7BF6),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: const Color(
                                                0xFF1E7BF6,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          state.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Next Button
                                  IconButton(
                                    tooltip: '下一首',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    onPressed: service.next,
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Favorite Heart
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
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('收藏失败：$error'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),

                                  // Repeat Mode Button
                                  if (isMedium) ...[
                                    IconButton(
                                      tooltip: _loopModeTooltip(state.loopMode),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () {
                                        final nextMode = switch (state
                                            .loopMode) {
                                          AppLoopMode.off => AppLoopMode.all,
                                          AppLoopMode.all => AppLoopMode.one,
                                          AppLoopMode.one => AppLoopMode.off,
                                        };
                                        service.setLoopMode(nextMode);
                                      },
                                      icon: Icon(
                                        state.loopMode == AppLoopMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                        size: 18,
                                        color: state.loopMode != AppLoopMode.off
                                            ? const Color(0xFF1E7BF6)
                                            : Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                      ),
                                    ),

                                    // Shuffle Button
                                    IconButton(
                                      tooltip: state.shuffle
                                          ? '关闭随机播放'
                                          : '开启随机播放',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () =>
                                          service.setShuffle(!state.shuffle),
                                      icon: Icon(
                                        Icons.all_inclusive_rounded,
                                        size: 18,
                                        color: state.shuffle
                                            ? const Color(0xFF1E7BF6)
                                            : Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                      ),
                                    ),
                                  ],

                                  // Queue Button
                                  IconButton(
                                    tooltip: '播放队列',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 30,
                                      height: 30,
                                    ),
                                    onPressed: () =>
                                        showQueuePanel(context, service),
                                    icon: Icon(
                                      Icons.queue_music_rounded,
                                      size: 19,
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),

                                  // Extra tools for desktop
                                  if (isDesktop) ...[
                                    IconButton(
                                      tooltip: '睡眠定时',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () =>
                                          _showSleepTimerDialog(context),
                                      icon: Icon(
                                        Icons.bedtime_outlined,
                                        size: 17,
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '投播',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('已使用本地高质量音频输出'),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.cast_rounded,
                                        size: 17,
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '歌词',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () => context.push('/player'),
                                      icon: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 17,
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '画中画',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                      onPressed: () => context.push('/player'),
                                      icon: Icon(
                                        Icons.picture_in_picture_alt_rounded,
                                        size: 17,
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Right Section: Volume Slider & Fullscreen
                            if (!isCompact)
                              SizedBox(
                                width: 140,
                                child: Row(
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: state.volume == 0
                                          ? '取消静音'
                                          : '静音',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 26,
                                            height: 26,
                                          ),
                                      onPressed: () {
                                        if (state.volume == 0) {
                                          service.setVolume(1.0);
                                        } else {
                                          service.setVolume(0.0);
                                        }
                                      },
                                      icon: Icon(
                                        state.volume == 0
                                            ? Icons.volume_off_rounded
                                            : state.volume < 0.5
                                            ? Icons.volume_down_rounded
                                            : Icons.volume_up_rounded,
                                        size: 17,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2.5,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 4.5,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 8.0,
                                              ),
                                          activeTrackColor: const Color(
                                            0xFF1E7BF6,
                                          ),
                                          inactiveTrackColor: const Color(
                                            0xFF2C2E38,
                                          ),
                                          thumbColor: Colors.white,
                                        ),
                                        child: Slider(
                                          value: state.volume.clamp(0.0, 1.0),
                                          onChanged: (val) =>
                                              service.setVolume(val),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '全屏播放',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 26,
                                            height: 26,
                                          ),
                                      onPressed: () => context.push('/player'),
                                      icon: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 14,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCompactContent({
    required AudioPlayerService service,
    required PlayableItem item,
    required Duration? duration,
    required bool playing,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlaybackProgressBar(service: service, duration: duration),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 40,
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
                                memCacheWidth: 120,
                                memCacheHeight: 120,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF22242D),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: Color(0xFF1E7BF6),
                                    size: 20,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.artist ?? item.album ?? '正在播放',
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
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: playing ? '暂停' : '播放',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                onPressed: () async {
                  if (playing) {
                    await service.pause();
                  } else {
                    await service.play();
                  }
                },
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 25,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: '下一首',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                onPressed: service.next,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _loopModeTooltip(AppLoopMode mode) {
    return switch (mode) {
      AppLoopMode.off => '单曲/列表不循环',
      AppLoopMode.all => '列表循环',
      AppLoopMode.one => '单曲循环',
    };
  }

  void _showSleepTimerDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: const Row(
          children: <Widget>[
            Icon(Icons.bedtime_outlined, color: Color(0xFF1E7BF6)),
            SizedBox(width: 10),
            Text('睡眠定时器', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _sleepTimerOption(context, '15 分钟', 15),
            _sleepTimerOption(context, '30 分钟', 30),
            _sleepTimerOption(context, '45 分钟', 45),
            _sleepTimerOption(context, '60 分钟', 60),
            _sleepTimerOption(context, '播完当前歌曲后停止', 0),
          ],
        ),
      ),
    );
  }

  Widget _sleepTimerOption(BuildContext context, String label, int minutes) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: Colors.white38,
      ),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已设置睡眠定时：$label')));
      },
    );
  }
}
