import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../audio/audio_player_service.dart';
import '../../../audio/playable_item_builder.dart';
import '../../../core/providers.dart';
import '../../../l10n/l10n.dart';
import '../../shared/media_widgets.dart';

Future<void> showTrackDiscoverySheet(
  BuildContext context, {
  required PlayableItem item,
  required AudioPlayerService service,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => TrackDiscoverySheet(item: item, service: service),
  );
}

class TrackDiscoverySheet extends ConsumerStatefulWidget {
  const TrackDiscoverySheet({
    required this.item,
    required this.service,
    super.key,
  });

  final PlayableItem item;
  final AudioPlayerService service;

  @override
  ConsumerState<TrackDiscoverySheet> createState() =>
      _TrackDiscoverySheetState();
}

class _TrackDiscoverySheetState extends ConsumerState<TrackDiscoverySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Song> _similarSongs = <Song>[];
  List<Song> _artistSongs = <Song>[];
  bool _loadingSimilar = true;
  bool _loadingArtist = true;
  bool _isStartingRadio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) {
      if (mounted) {
        setState(() {
          _loadingSimilar = false;
          _loadingArtist = false;
        });
      }
      return;
    }

    // 1. Fetch Similar Songs
    client
        .getSimilarSongs2(widget.item.id, count: 20)
        .then((songs) {
          if (mounted) {
            setState(() {
              _similarSongs = songs;
              _loadingSimilar = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _loadingSimilar = false);
        });

    // 2. Fetch Artist Songs
    if (widget.item.artistId != null && widget.item.artistId!.isNotEmpty) {
      client
          .getArtist(widget.item.artistId!)
          .then((artist) {
            final allSongs = <Song>[
              for (final album in artist.albums) ...album.songs,
            ];
            if (mounted) {
              setState(() {
                _artistSongs = allSongs
                    .where((s) => s.id != widget.item.id)
                    .toList();
                _loadingArtist = false;
              });
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _loadingArtist = false);
          });
    } else if (widget.item.artist != null && widget.item.artist!.isNotEmpty) {
      client
          .search3(widget.item.artist!)
          .then((result) {
            if (mounted) {
              setState(() {
                _artistSongs = result.songs
                    .where((s) => s.id != widget.item.id)
                    .toList();
                _loadingArtist = false;
              });
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _loadingArtist = false);
          });
    } else {
      if (mounted) setState(() => _loadingArtist = false);
    }
  }

  Future<void> _startInstantRadio() async {
    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) return;

    setState(() => _isStartingRadio = true);
    try {
      List<Song> candidates = _similarSongs;
      if (candidates.isEmpty) {
        candidates = await client.getRandomSongs(size: 20);
      }
      if (candidates.isEmpty) return;

      final playableItems = candidates
          .map((s) => playableItemForSong(client, s))
          .toList();

      final currentSnapshot = widget.service.currentSnapshot;
      final currentQueue = currentSnapshot?.queue ?? <PlayableItem>[];
      final currentIndex = currentSnapshot?.currentIndex ?? 0;

      final updatedQueue = <PlayableItem>[...currentQueue, ...playableItems];
      await widget.service.setQueue(updatedQueue, startIndex: currentIndex);

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.radioStarted(playableItems.length)),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isStartingRadio = false);
    }
  }

  Future<void> _playSong(Song song) async {
    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) return;

    final playable = playableItemForSong(client, song);
    await widget.service.insertNext(playable);
    await widget.service.next();
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _insertNextSong(Song song) async {
    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) return;

    final playable = playableItemForSong(client, song);
    await widget.service.insertNext(playable);
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${song.title} -> ${context.l10n.queueTitle}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(activeSubsonicClientProvider);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header & Instant Radio Action Button
            Row(
              children: <Widget>[
                const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFF5BA4FF),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.discovery,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Instant Track Radio Banner
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isStartingRadio ? null : _startInstantRadio,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF1E7BF6), Color(0xFF3346B8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    _isStartingRadio
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.sensors_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.trackRadio,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.l10n.startRadio,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1E7BF6),
              indicatorWeight: 3,
              labelColor: const Color(0xFF5BA4FF),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
              tabs: <Widget>[
                Tab(text: context.l10n.similarSongs),
                Tab(text: context.l10n.moreByArtist),
              ],
            ),
            const SizedBox(height: 8),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  // 1. Similar Songs View
                  _buildSongsList(
                    songs: _similarSongs,
                    loading: _loadingSimilar,
                    client: client,
                  ),
                  // 2. More by Artist View
                  _buildSongsList(
                    songs: _artistSongs,
                    loading: _loadingArtist,
                    client: client,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList({
    required List<Song> songs,
    required bool loading,
    required SubsonicClient? client,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (songs.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noRecommendations,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: songs.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.white.withValues(alpha: 0.04),
        height: 1,
        indent: 52,
      ),
      itemBuilder: (context, index) {
        final song = songs[index];
        final coverUrl = client != null
            ? resolveSongCoverUrl(song: song, client: client, size: 100)
            : null;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          leading: SizedBox.square(
            dimension: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl == null
                  ? Container(
                      color: const Color(0xFF222634),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 100,
                      memCacheHeight: 100,
                    ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [song.artist, song.album].whereType<String>().join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11.5,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.queueTitle,
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  size: 20,
                  color: Colors.white60,
                ),
                onPressed: () => _insertNextSong(song),
              ),
              IconButton(
                tooltip: context.l10n.nowPlaying,
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 24,
                  color: Color(0xFF5BA4FF),
                ),
                onPressed: () => _playSong(song),
              ),
            ],
          ),
        );
      },
    );
  }
}
