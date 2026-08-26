import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import '../smooth_position_builder.dart';
import 'lyrics_parser.dart';
import 'lyrics_service.dart';

/// Full-screen OLED landscape lyrics stage.
///
/// Automatically switches the device to landscape orientation with immersive
/// full-screen mode on mobile. The canvas is pure OLED black (#000000) with
/// smooth line-by-line scrolling lyrics centered on the screen.
///
/// Tapping the screen reveals a minimal, semi-transparent HUD overlay with
/// track information, clock, scrubber, and playback controls that automatically
/// fades out after 3.5 seconds of inactivity. Double-tapping anywhere toggles
/// playback immediately.
class OledLyricsStage extends ConsumerStatefulWidget {
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
  ConsumerState<OledLyricsStage> createState() => _OledLyricsStageState();
}

class _OledLyricsStageState extends ConsumerState<OledLyricsStage> {
  bool _showControls = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation on mobile
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Immersive fullscreen mode (hides status bar & navigation bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    // Restore default portrait & landscape orientations
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Restore edge-to-edge system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _onUserInteraction() {
    if (_showControls) {
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        widget.onExit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Container(
          color: Colors.black,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SmoothPositionBuilder(
              service: widget.service,
              duration: widget.duration,
              builder: (context, position, controls) {
                final maxMs = widget.duration.inMilliseconds > 0
                    ? widget.duration.inMilliseconds.toDouble()
                    : 1.0;
                final posMs = position.inMilliseconds
                    .clamp(0, maxMs.toInt())
                    .toDouble();

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTap: () async {
                    if (widget.playing) {
                      await widget.service.pause();
                    } else {
                      await widget.service.play();
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // 1. Center Line-by-Line Scrolling Lyrics
                      Positioned.fill(
                        child: _OledLandscapeLyricsView(
                          item: widget.item,
                          position: position,
                          onSeek: widget.service.seek,
                          onUserInteraction: _onUserInteraction,
                        ),
                      ),

                      // 2. Auto-fading Minimal HUD Controls Overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: SafeArea(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  _buildTopBar(context),
                                  _buildBottomControls(
                                    context,
                                    posMs,
                                    maxMs,
                                    controls,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final timeFormatted = '$hourStr:$minStr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: <Widget>[
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onExit,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.item.artist ?? context.l10n.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  timeFormatted,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
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
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
      thumbColor: Colors.white,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 24,
            child: Row(
              children: <Widget>[
                Text(
                  _formatDuration(Duration(milliseconds: posMs.round())),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      value: posMs,
                      max: maxMs,
                      onChanged: widget.duration == Duration.zero
                          ? null
                          : (value) {
                              _onUserInteraction();
                              controls.seek(
                                Duration(milliseconds: value.round()),
                              );
                            },
                      onChangeEnd: widget.duration == Duration.zero
                          ? null
                          : (_) {
                              _onUserInteraction();
                              controls.seekEnd();
                            },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(widget.duration),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.previousTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: () {
                  _onUserInteraction();
                  widget.service.previous();
                },
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 32),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () async {
                    _onUserInteraction();
                    if (widget.playing) {
                      await widget.service.pause();
                    } else {
                      await widget.service.play();
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      widget.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              IconButton(
                tooltip: context.l10n.nextTrack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: () {
                  _onUserInteraction();
                  widget.service.next();
                },
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 30,
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

/// Dedicated line-by-line scrolling lyrics engine optimized for landscape OLED display.
class _OledLandscapeLyricsView extends ConsumerStatefulWidget {
  const _OledLandscapeLyricsView({
    required this.item,
    required this.position,
    required this.onSeek,
    required this.onUserInteraction,
  });

  final PlayableItem item;
  final Duration position;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onUserInteraction;

  @override
  ConsumerState<_OledLandscapeLyricsView> createState() =>
      _OledLandscapeLyricsViewState();
}

class _OledLandscapeLyricsViewState
    extends ConsumerState<_OledLandscapeLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;
  bool _userScrolling = false;
  Timer? _resumeAutoScrollTimer;
  List<GlobalKey> _lineKeys = <GlobalKey>[];

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OledLandscapeLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _lastIndex = -1;
      _lineKeys = <GlobalKey>[];
      _userScrolling = false;
      _resumeAutoScrollTimer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _scrollToActiveIndex(int activeIndex, {bool immediate = false}) {
    if (activeIndex < 0 || activeIndex >= _lineKeys.length) {
      return;
    }
    final keyContext = _lineKeys[activeIndex].currentContext;
    if (keyContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      keyContext,
      alignment: 0.5,
      duration: immediate ? Duration.zero : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  int _findIndex(List<ParsedLyricsLine> lines, int positionMs) {
    var active = -1;
    var low = 0;
    var high = lines.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].timeMs <= positionMs) {
        active = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(
      lyricsProvider(
        LyricsQuery(
          id: widget.item.id,
          artist: widget.item.artist,
          title: widget.item.title,
        ),
      ),
    );

    return lyrics.when(
      loading: () => Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
      error: (error, stackTrace) => _buildNoLyrics(context),
      data: (lines) {
        if (lines == null || lines.isEmpty) {
          return _buildNoLyrics(context);
        }

        final activeIndex = _findIndex(lines, widget.position.inMilliseconds);
        if (_lineKeys.length != lines.length) {
          _lineKeys = List<GlobalKey>.generate(
            lines.length,
            (_) => GlobalKey(),
          );
        }

        if (activeIndex != _lastIndex) {
          final isInitial = _lastIndex == -1;
          _lastIndex = activeIndex;
          if (!_userScrolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToActiveIndex(activeIndex, immediate: isInitial);
              }
            });
          }
        }

        final viewportHeight = MediaQuery.sizeOf(context).height;
        final edgePadding = (viewportHeight * 0.42).clamp(100.0, 300.0);

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _userScrolling = true;
              _resumeAutoScrollTimer?.cancel();
              widget.onUserInteraction();
            } else if (notification is ScrollEndNotification ||
                (notification is UserScrollNotification &&
                    notification.direction == ScrollDirection.idle)) {
              _resumeAutoScrollTimer?.cancel();
              _resumeAutoScrollTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  _userScrolling = false;
                  _scrollToActiveIndex(_lastIndex);
                }
              });
            }
            return false;
          },
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: <double>[0.0, 0.18, 0.82, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                vertical: edgePadding,
                horizontal: 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < lines.length; i++)
                    _buildLyricLine(
                      key: _lineKeys[i],
                      line: lines[i],
                      index: i,
                      activeIndex: activeIndex,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricLine({
    required Key key,
    required ParsedLyricsLine line,
    required int index,
    required int activeIndex,
  }) {
    final distance = activeIndex >= 0 ? (index - activeIndex).abs() : 999;
    final isActive = distance == 0;

    // Graduated opacity and typography based on distance from current line
    final double mainFontSize;
    final double translationFontSize;
    final FontWeight fontWeight;
    final Color mainColor;
    final Color transColor;
    final double verticalPadding;

    if (isActive) {
      mainFontSize = 28;
      translationFontSize = 17;
      fontWeight = FontWeight.w800;
      mainColor = Colors.white;
      transColor = Colors.white.withValues(alpha: 0.75);
      verticalPadding = 12;
    } else if (distance == 1) {
      mainFontSize = 20;
      translationFontSize = 14.5;
      fontWeight = FontWeight.w600;
      mainColor = Colors.white.withValues(alpha: 0.35);
      transColor = Colors.white.withValues(alpha: 0.28);
      verticalPadding = 9;
    } else if (distance == 2) {
      mainFontSize = 17;
      translationFontSize = 13;
      fontWeight = FontWeight.w500;
      mainColor = Colors.white.withValues(alpha: 0.18);
      transColor = Colors.white.withValues(alpha: 0.14);
      verticalPadding = 7;
    } else {
      mainFontSize = 15;
      translationFontSize = 12;
      fontWeight = FontWeight.w400;
      mainColor = Colors.white.withValues(alpha: 0.08);
      transColor = Colors.white.withValues(alpha: 0.06);
      verticalPadding = 5;
    }

    final rawText = line.text;
    final lines = rawText.split('\n');
    final mainText = lines[0];
    final translationText =
        lines.length > 1 ? lines.sublist(1).join('\n') : null;

    return Center(
      key: key,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onUserInteraction();
          widget.onSeek(Duration(milliseconds: line.timeMs));
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: mainColor,
                  fontSize: mainFontSize,
                  fontWeight: fontWeight,
                  height: 1.35,
                  letterSpacing: isActive ? 0.2 : 0.0,
                ),
                child: Text(
                  mainText,
                  textAlign: TextAlign.center,
                ),
              ),
              if (translationText != null && translationText.isNotEmpty) ...[
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: transColor,
                    fontSize: translationFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  child: Text(
                    translationText,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLyrics(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lyrics_outlined,
              size: 36,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.artist ?? context.l10n.unknownArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noLyrics,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
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
