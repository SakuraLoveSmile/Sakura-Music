import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_service.dart';
import '../../core/providers.dart';
import '../../l10n/l10n.dart';

Future<void> showQuickAddToPlaylistSheet(
  BuildContext context, {
  required PlayableItem item,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => QuickAddToPlaylistSheet(item: item),
  );
}

class QuickAddToPlaylistSheet extends ConsumerStatefulWidget {
  const QuickAddToPlaylistSheet({required this.item, super.key});

  final PlayableItem item;

  @override
  ConsumerState<QuickAddToPlaylistSheet> createState() => _QuickAddToPlaylistSheetState();
}

class _QuickAddToPlaylistSheetState extends ConsumerState<QuickAddToPlaylistSheet> {
  bool _isCreating = false;

  Future<void> _addToExistingPlaylist(Playlist playlist) async {
    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) return;

    try {
      await client.updatePlaylist(
        playlistId: playlist.id,
        songIdsToAdd: <String>[widget.item.id],
      );
      ref.invalidate(playlistsProvider);
      ref.invalidate(playlistDetailsProvider(playlist.id));
      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.addedToPlaylist}: ${playlist.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF20232E),
        title: Text(ctx.l10n.createAndAdd, style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: ctx.l10n.newPlaylistName,
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E7BF6))),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E7BF6),
              foregroundColor: Colors.white,
            ),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) return;

    setState(() => _isCreating = true);
    try {
      await client.createPlaylist(name: name, songIds: <String>[widget.item.id]);
      ref.invalidate(playlistsProvider);
      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.addedToPlaylist}: $name'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.createPlaylistFailed}: $err'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final client = ref.watch(activeSubsonicClientProvider);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // Title Row
            Row(
              children: <Widget>[
                const Icon(Icons.playlist_add_rounded, color: Color(0xFF5BA4FF), size: 22),
                const SizedBox(width: 8),
                Text(
                  context.l10n.selectPlaylist,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Track brief preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 36,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: widget.item.artworkUrl == null
                          ? Container(
                              color: const Color(0xFF2A2D3A),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
                            )
                          : CachedNetworkImage(
                              imageUrl: widget.item.artworkUrl!,
                              cacheKey: widget.item.artworkCacheKey,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.item.artist ?? context.l10n.unknownArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Create New Playlist Row
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF1E7BF6).withValues(alpha: 0.12),
              leading: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E7BF6),
                  shape: BoxShape.circle,
                ),
                child: _isCreating
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
              title: Text(
                context.l10n.createAndAdd,
                style: const TextStyle(
                  color: Color(0xFF5BA4FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              onTap: _isCreating ? null : _showCreatePlaylistDialog,
            ),
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 4),

            // Playlists List
            Expanded(
              child: playlistsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => Center(
                  child: Text(
                    err.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return Center(
                      child: Text(
                        context.l10n.emptyPlaylists,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: playlists.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withValues(alpha: 0.04),
                      height: 1,
                      indent: 52,
                    ),
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      final coverUrl = pl.coverArt != null && client != null
                          ? client.coverArtUrl(pl.coverArt!, size: 100)
                          : null;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: SizedBox.square(
                          dimension: 38,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: coverUrl == null
                                ? Container(
                                    color: const Color(0xFF222634),
                                    child: const Icon(Icons.queue_music_rounded, color: Colors.white54, size: 20),
                                  )
                                : CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.queueSongCount(pl.songCount ?? 0),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                          color: Color(0xFF5BA4FF),
                        ),
                        onTap: () => _addToExistingPlaylist(pl),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
