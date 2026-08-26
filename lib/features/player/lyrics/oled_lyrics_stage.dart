import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../audio/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_view.dart';
import '../smooth_position_builder.dart';

/// Full-screen OLED lyrics stage.
///
/// Renders as the player screen body itself (not an overlay on top of the
/// normal player) so the ambient blurred cover, top bar, cover artwork and
/// bottom dock are not drawn. The root is fixed to pure black and the system
/// bars are switched to a light-on-black appearance.
class OledLyricsStage extends StatelessWidget {
  const OledLyricsStage({
    required this.service,
    required this.item,
    required this.playing,
    required this.duration,
    required this.onExit,
    super.key,
  });

  final AudioPlayerService service;
  final PlayableItem item;
  final bool playing;
  final Duration duration;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: SmoothPositionBuilder(
            service: service,
            duration: duration,
            builder: (context, position, controls) {
              final maxMs = duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0;
              final posMs = position.inMilliseconds
                  .clamp(0, maxMs.toInt())
                  .toDouble();

              return Column(
                children: <Widget>[
                  _buildTopBar(context),
                  Expanded(
                    child: LyricsView(
                      item: item,
                      position: position,
                      onSeek: service.seek,
                      textAlign: TextAlign.center,
                      oled: true,
                    ),
                  ),
                  _buildBottomControls(context, posMs, maxMs, controls),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: context.l10n.collapsePlayer,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: Colors.white,
            ),
            onPressed: onExit,
          ),
          const SizedBox(width: 4),
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
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.artist ?? context.l10n.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    double posMs,
    double maxMs,
    SmoothPositionControls controls,
  ) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 3.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 9.0),
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
      thumbColor: Colors.white,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 28,
            child: Row(
              children: <Widget>[
                Text(
                  _formatDuration(Duration(milliseconds: posMs.round())),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.previousTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 52,
                  height: 52,
                ),
                onPressed: service.previous,
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 24),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () async {
                    if (playing) {
                      await service.pause();
                    } else {
                      await service.play();
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 34,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                tooltip: context.l10n.nextTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 52,
                  height: 52,
                ),
                onPressed: service.next,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
