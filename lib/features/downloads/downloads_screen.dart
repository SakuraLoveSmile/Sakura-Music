import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/download_manager.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final manager = ref.watch(downloadManagerProvider);
    final client = ref.watch(activeSubsonicClientProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              leading: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/library');
                  }
                },
              ),
              title: const Text('下载'),
              floating: true,
            ),
          downloads.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('读取下载失败：$error')),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('还没有下载歌曲。')),
                );
              }
              final active = items
                  .where((item) => item.status != 'completed')
                  .toList(growable: false);
              final completed = items
                  .where((item) => item.status == 'completed')
                  .toList(growable: false);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                sliver: SliverMainAxisGroup(
                  slivers: <Widget>[
                    if (active.isNotEmpty) ...<Widget>[
                      const _DownloadSectionHeader(title: '进行中'),
                      SliverList.builder(
                        itemCount: active.length,
                        itemBuilder: (context, index) => _downloadTile(
                          context: context,
                          ref: ref,
                          download: active[index],
                          manager: manager,
                          client: client,
                        ),
                      ),
                    ],
                    if (completed.isNotEmpty) ...<Widget>[
                      const _DownloadSectionHeader(title: '已完成'),
                      SliverList.builder(
                        itemCount: completed.length,
                        itemBuilder: (context, index) => _downloadTile(
                          context: context,
                          ref: ref,
                          download: completed[index],
                          manager: manager,
                          client: client,
                        ),
                      ),
                    ],
                  ],
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

class _DownloadSectionHeader extends StatelessWidget {
  const _DownloadSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

Widget _downloadTile({
  required BuildContext context,
  required WidgetRef ref,
  required Download download,
  required DownloadManager? manager,
  required SubsonicClient? client,
}) {
  final isComplete = download.status == 'completed';
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ListTile(
        leading: Icon(
          isComplete
              ? Icons.download_done
              : download.status == 'failed'
              ? Icons.error_outline
              : Icons.downloading,
        ),
        title: Text(download.title),
        subtitle: Text(
          [
            download.artist,
            download.album,
            if (!isComplete) _statusLabel(download.status),
          ].whereType<String>().join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isComplete && manager != null)
              IconButton(
                tooltip: '取消下载',
                onPressed: () => manager.cancel(download.songId),
                icon: const Icon(Icons.close),
              ),
            IconButton(
              tooltip: '删除下载',
              onPressed: manager == null
                  ? null
                  : () => manager.delete(download.songId),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        onTap: !isComplete
            ? null
            : () async {
                final item = client == null
                    ? PlayableItem(
                        id: download.songId,
                        title: download.title,
                        artist: download.artist,
                        album: download.album,
                        streamUrl: Uri.file(download.filePath).toString(),
                      )
                    : await playableItemForSongWithLocalFile(
                        client,
                        manager,
                        Song(
                          id: download.songId,
                          title: download.title,
                          artist: download.artist,
                          album: download.album,
                          coverArt: download.coverArtId,
                        ),
                      );
                final service = ref.read(audioPlayerProvider);
                await service.setQueue(<PlayableItem>[item]);
                await service.play();
                if (context.mounted) {
                  context.go('/player');
                }
              },
      ),
      if (!isComplete)
        LinearProgressIndicator(
          value: download.progress > 0
              ? download.progress.clamp(0, 1).toDouble()
              : null,
          minHeight: 2,
        ),
    ],
  );
}

String _statusLabel(String status) {
  return switch (status) {
    'downloading' => '下载中',
    'failed' => '失败',
    _ => status,
  };
}
