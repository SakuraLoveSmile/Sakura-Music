import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../data/server_repository.dart';
import '../../data/webdav/webdav_client.dart';
import '../../data/webdav/webdav_display.dart';
import '../../data/webdav/webdav_providers.dart';
import '../../data/webdav/webdav_tags.dart';
import '../../l10n/l10n.dart';

/// Title for one row: the tag title when the file carries one, otherwise the
/// cleaned-up file name. Shared by the list rows and the queue builder so the
/// two can never disagree.
String _trackTitle(AudioTags? tags, String fileName) {
  final title = tags?.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return cleanTrackTitle(fileName);
}

/// `artist · album` for a row, or `null` when the tags carry neither.
String? _trackSubtitle(AudioTags? tags) {
  final artist = tags?.artist?.trim() ?? '';
  final album = tags?.album?.trim() ?? '';
  final parts = <String>[
    if (artist.isNotEmpty) artist,
    if (album.isNotEmpty) album,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// One line of the browse list. The list is built with `ListView.builder`, so
/// rows are produced as data first and rendered per index.
sealed class _BrowseRow {
  const _BrowseRow();
}

/// Section divider: "Folders" / "Songs". [label] is rendered as its own `Text`
/// so the localized string stays findable verbatim. [count] is carried by the
/// row model but not rendered as a bare number, which would collide with the
/// song-position `Text` inside the same list.
class _SectionHeaderRow extends _BrowseRow {
  const _SectionHeaderRow(this.label, this.count);

  final String label;
  final int count;
}

class _FolderRow extends _BrowseRow {
  const _FolderRow(this.entry);

  final WebDavEntry entry;
}

class _SongRow extends _BrowseRow {
  const _SongRow({
    required this.entry,
    required this.index,
    required this.onTap,
  });

  final WebDavEntry entry;

  /// One-based position shown in the row's leading slot.
  final int index;

  /// Enqueues the whole folder starting at this row (zero-based).
  final VoidCallback onTap;
}

/// File browser for a WebDAV source. The active server must be of type
/// `webdav`; navigation state is kept internally (no new route).
class WebDavBrowseScreen extends ConsumerStatefulWidget {
  const WebDavBrowseScreen({super.key});

  @override
  ConsumerState<WebDavBrowseScreen> createState() => _WebDavBrowseScreenState();
}

class _WebDavBrowseScreenState extends ConsumerState<WebDavBrowseScreen> {
  /// Browsed folder. `null` means the remembered folder has not been read from
  /// the database yet: the listing must not be requested before that, or the
  /// first request would hit the root instead of the remembered folder.
  String? _path;

  /// Server whose remembered folder [_path] currently belongs to. `null` until
  /// the first restore lands, so an early switch cannot reuse another
  /// server's path.
  int? _loadedServerId;

  /// Tags the visible rows have resolved, keyed by href. Enqueueing reads this
  /// cache: `ref.read(webdavTagProvider(href))` would *create* one probe per
  /// file in the folder, turning a tap into a request storm.
  final Map<String, AudioTags> _resolvedTags = <String, AudioTags>{};

  List<WebDavEntry> _entries = const <WebDavEntry>[];

  List<WebDavEntry> get _folders =>
      _entries.where((e) => e.isDirectory).toList();

  List<WebDavEntry> get _audioFiles =>
      _entries.where((e) => !e.isDirectory).toList();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLastPath());
  }

  /// Reads the folder browsed last time for the active server. A database
  /// hiccup falls back to the root; browsing must never be blocked by it.
  Future<void> _restoreLastPath() async {
    final serverId = ref.read(activeServerProvider)?.id;
    var path = '';
    if (serverId != null) {
      try {
        path = await ref.read(databaseProvider).getWebDavLastPath(serverId);
      } catch (_) {
        path = '';
      }
    }
    // The active server can change while the database read is in flight;
    // applying a stale result would show one server's folder under another.
    if (!mounted || ref.read(activeServerProvider)?.id != serverId) {
      return;
    }
    setState(() {
      _path = path;
      _loadedServerId = serverId;
    });
  }

  /// Every directory jump (folder tap, up, breadcrumb) goes through here so
  /// the new folder is shown immediately and remembered in the background.
  void _navigateTo(String path) {
    setState(() {
      _path = path;
      // The tag cache belongs to the folder that was on screen: a new folder
      // starts empty so a stale href can never be enqueued with the wrong
      // title.
      _resolvedTags.clear();
    });
    final serverId = ref.read(activeServerProvider)?.id;
    if (serverId == null) {
      return;
    }
    unawaited(() async {
      try {
        await ref.read(databaseProvider).setWebDavLastPath(serverId, path);
      } catch (_) {
        // Remembering the folder is a convenience; a database hiccup must
        // never block browsing.
      }
    }());
  }

  /// Drops the last path segment: `/a/b/` becomes `/a/`, `/a/` becomes root.
  void _goUp() {
    final path = _path;
    if (path == null || path.isEmpty) {
      return;
    }
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      // A stored value such as `/` has nothing above the root.
      _navigateTo('');
      return;
    }
    segments.removeLast();
    _navigateTo(segments.isEmpty ? '' : '/${segments.join('/')}/');
  }

  Future<void> _playFrom(int index) async {
    final client = ref.read(webdavClientProvider);
    if (client == null) return;
    final files = _audioFiles;
    if (index < 0 || index >= files.length) return;
    final items = <PlayableItem>[
      for (final file in files)
        PlayableItem(
          id: file.href,
          // Tag-first titles reuse whatever the rows already resolved; files
          // without tags (or not seen yet) fall back to the cleaned name.
          title: _trackTitle(_resolvedTags[file.href], file.name),
          artist: _resolvedTags[file.href]?.artist?.trim(),
          album: _resolvedTags[file.href]?.album?.trim(),
          streamUrl: Uri.parse(client.baseUrl).resolve(file.href).toString(),
          headers: <String, String>{'Authorization': client.authHeader},
          albumId: null,
          artistId: null,
        ),
    ];
    final service = ref.read(audioPlayerProvider);
    await service.setQueue(items, startIndex: index);
    await service.play();
  }

  /// Records the tags a visible row resolved. Rows are built lazily, so the
  /// cache only holds files the user actually scrolled past.
  void _rememberTags(String href, AudioTags tags) {
    _resolvedTags[href] = tags;
  }

  @override
  Widget build(BuildContext context) {
    // The shell keeps this screen alive while the active server changes, so a
    // switch must re-read that server's remembered folder.
    ref.listen(activeServerProvider, (previous, next) {
      if (previous?.id == next?.id || _loadedServerId == next?.id) {
        return;
      }
      setState(() {
        _path = null;
        _loadedServerId = null;
        _resolvedTags.clear();
      });
      unawaited(_restoreLastPath());
    });
    final client = ref.watch(webdavClientProvider);
    if (client == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF131418),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131418),
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text(
            context.l10n.serverType,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            context.l10n.notConnected,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Still restoring the remembered folder: no listing request yet.
    final path = _path;
    if (path == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF131418),
        body: Center(
          child: SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final listing = ref.watch(webdavListingProvider(path));
    _entries = listing.value ?? const <WebDavEntry>[];
    final folders = _folders;
    final audioFiles = _audioFiles;

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          tooltip: context.l10n.back,
          onPressed: path.isEmpty ? null : _goUp,
        ),
        title: Text(
          webdavPathLabel(path),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: _WebDavBreadcrumbs(path: path, onNavigate: _navigateTo),
        ),
        actions: <Widget>[
          if (audioFiles.isNotEmpty)
            TextButton.icon(
              onPressed: () => _playFrom(0),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                context.l10n.playAll,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: listing.when(
        loading: () => const Center(
          child: SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.loadError,
              style: const TextStyle(color: Color(0xFFFF6961), fontSize: 13),
            ),
          ),
        ),
        data: (_) {
          if (folders.isEmpty && audioFiles.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noContentYet,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            );
          }
          final rows = <_BrowseRow>[
            if (folders.isNotEmpty)
              _SectionHeaderRow(context.l10n.webdavFolders, folders.length),
            for (final folder in folders) _FolderRow(folder),
            if (audioFiles.isNotEmpty)
              _SectionHeaderRow(context.l10n.webdavSongs, audioFiles.length),
            for (var index = 0; index < audioFiles.length; index++)
              _SongRow(
                entry: audioFiles[index],
                index: index + 1,
                onTap: () => _playFrom(index),
              ),
          ];
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return switch (row) {
                final _SectionHeaderRow header => _SectionHeader(
                  label: header.label,
                ),
                // The folder href is remembered verbatim.
                final _FolderRow folder => _FolderTile(
                  entry: folder.entry,
                  onTap: () => _navigateTo(folder.entry.href),
                ),
                final _SongRow song => _SongTile(
                  entry: song.entry,
                  index: song.index,
                  onTap: song.onTap,
                  onTags: _rememberTags,
                ),
              };
            },
          );
        },
      ),
    );
  }
}

/// Section divider row: the localized label only, in the dark theme's muted
/// style.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.entry, required this.onTap});

  final WebDavEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_rounded, color: Color(0xFF0A84FF)),
      title: Text(
        entry.name,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: onTap,
    );
  }
}

/// One audio row of the playlist: position (or the play state of the current
/// item) on the left, tag title over `artist · album` in the middle.
class _SongTile extends ConsumerStatefulWidget {
  const _SongTile({
    required this.entry,
    required this.index,
    required this.onTap,
    required this.onTags,
  });

  final WebDavEntry entry;
  final int index;
  final VoidCallback onTap;

  /// Reports the tags this row resolved upwards, so enqueueing can reuse them
  /// instead of starting a probe for every file in the folder.
  final void Function(String href, AudioTags tags) onTags;

  @override
  ConsumerState<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<_SongTile> {
  /// href this row already reported upwards. Remembered per (state, href)
  /// instead of as a one-shot latch: `ListView.builder` reuses one row state
  /// per index, so leaving a folder and coming back hands this state another
  /// file's href — and that file has to be reported too, otherwise the parent
  /// cache stays empty after every navigation (it is cleared per folder).
  String? _reportedHref;

  @override
  Widget build(BuildContext context) {
    final href = widget.entry.href;
    // `value` never throws and is null while the tag probe runs or when it
    // fails, so the row falls back to the file name without blocking the list.
    final tags = ref.watch(webdavTagProvider(href)).value;
    if (tags != null && _reportedHref != href) {
      _reportedHref = href;
      // Reporting upwards mutates the parent, which must not happen while
      // this row is building: hand it to the end of the current frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The row may have been reused for another file before the callback
        // runs; a stale report would be filed under the wrong cache entry.
        if (!mounted || widget.entry.href != href) return;
        widget.onTags(href, tags);
      });
    }
    final service = ref.watch(audioPlayerProvider);
    return StreamBuilder<PlayerSnapshot>(
      stream: service.snapshot,
      initialData: service.currentSnapshot,
      builder: (context, snapshot) {
        final current = snapshot.data?.currentItem;
        final isCurrent = current != null && current.id == widget.entry.href;
        final isPlaying = isCurrent && (snapshot.data?.playing ?? false);
        final subtitle = _trackSubtitle(tags);
        return ListTile(
          leading: SizedBox(
            width: 34,
            child: Center(
              child: isCurrent
                  ? Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFFF48FB1),
                      size: 22,
                    )
                  : Text(
                      '${widget.index}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          title: Text(
            _trackTitle(tags, widget.entry.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? const Color(0xFFF48FB1) : Colors.white,
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
          onTap: widget.onTap,
        );
      },
    );
  }
}

/// Horizontally scrolling breadcrumb trail: `/` first, then one entry per path
/// segment. Each entry carries the cumulated path so a tap jumps straight to
/// that folder (and remembers it through `_navigateTo`).
class _WebDavBreadcrumbs extends StatelessWidget {
  const _WebDavBreadcrumbs({required this.path, required this.onNavigate});

  final String path;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final children = <Widget>[];
    var accumulated = '';
    for (var index = -1; index < segments.length; index++) {
      if (index < 0) {
        // Root crumb.
        children.add(_crumb('/', '', index == segments.length - 1));
        continue;
      }
      accumulated = '$accumulated/${segments[index]}/';
      children.add(
        const Icon(
          Icons.chevron_right_rounded,
          size: 14,
          color: Colors.white24,
        ),
      );
      children.add(
        _crumb(
          webdavPathLabel(segments[index]),
          accumulated,
          index == segments.length - 1,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: children),
    );
  }

  Widget _crumb(String label, String target, bool isCurrent) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onNavigate(target),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
