import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../data/webdav/webdav_client.dart';
import '../../data/webdav/webdav_providers.dart';
import '../../l10n/l10n.dart';

/// File browser for a WebDAV source. The active server must be of type
/// `webdav`; navigation state is kept internally (no new route).
class WebDavBrowseScreen extends ConsumerStatefulWidget {
  const WebDavBrowseScreen({super.key});

  @override
  ConsumerState<WebDavBrowseScreen> createState() => _WebDavBrowseScreenState();
}

class _WebDavBrowseScreenState extends ConsumerState<WebDavBrowseScreen> {
  String _path = '';

  List<WebDavEntry> get _folders =>
      _entries.where((e) => e.isDirectory).toList();

  List<WebDavEntry> get _audioFiles =>
      _entries.where((e) => !e.isDirectory).toList();

  List<WebDavEntry> _entries = const <WebDavEntry>[];

  Future<void> _playFrom(int index) async {
    final client = ref.read(webdavClientProvider);
    if (client == null) return;
    final files = _audioFiles;
    if (index < 0 || index >= files.length) return;
    final items = <PlayableItem>[
      for (final file in files)
        PlayableItem(
          id: file.href,
          title: file.name,
          streamUrl: Uri.parse(client.baseUrl).resolve(file.href).toString(),
          headers: <String, String>{
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${client.username}:${client.password}'))}',
          },
          albumId: null,
          artistId: null,
        ),
    ];
    final service = ref.read(audioPlayerProvider);
    await service.setQueue(items, startIndex: index);
    await service.play();
  }

  void _openFolder(WebDavEntry folder) {
    setState(() => _path = folder.href);
  }

  void _goUp() {
    if (_path.isEmpty) return;
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList()
      ..removeLast();
    setState(() => _path = segments.isEmpty ? '' : '/${segments.join('/')}/');
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(webdavClientProvider);
    final listing = ref.watch(webdavListingProvider(_path));

    _entries = listing.value ?? const <WebDavEntry>[];
    final folders = _folders;
    final audioFiles = _audioFiles;

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

    final pathLabel = _path.isEmpty ? '/' : _path;

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          tooltip: context.l10n.back,
          onPressed: _path.isEmpty ? null : _goUp,
        ),
        title: Text(
          pathLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              for (final folder in folders)
                ListTile(
                  leading: const Icon(
                    Icons.folder_rounded,
                    color: Color(0xFF0A84FF),
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
                  onTap: () => _openFolder(folder),
                ),
              for (final file in audioFiles)
                ListTile(
                  leading: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white70,
                  ),
                  title: Text(
                    file.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () => _playFrom(audioFiles.indexOf(file)),
                ),
            ],
          );
        },
      ),
    );
  }
}
