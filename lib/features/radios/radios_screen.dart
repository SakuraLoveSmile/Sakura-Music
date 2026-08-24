import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.genre,
    required this.streamUrl,
    required this.accentColor,
    required this.icon,
    this.description,
  });

  final String id;
  final String name;
  final String genre;
  final String streamUrl;
  final Color accentColor;
  final IconData icon;
  final String? description;
}

const _presetStations = <RadioStation>[
  RadioStation(
    id: 'radio_lofi',
    name: 'Lofi Chill Radio',
    genre: 'Lo-Fi / Relax',
    streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
    accentColor: Color(0xFF5C6BC0),
    icon: Icons.coffee_rounded,
    description: '舒适惬意的学习与工作放松音乐伴侣',
  ),
  RadioStation(
    id: 'radio_jazz',
    name: 'Classic Jazz 24/7',
    genre: 'Jazz / Blues',
    streamUrl: 'https://stream.zeno.fm/c3592h4z8h8uv',
    accentColor: Color(0xFF8D6E63),
    icon: Icons.nightlife_rounded,
    description: '午夜慢调爵士乐与萨克斯风经典选段',
  ),
  RadioStation(
    id: 'radio_classical',
    name: 'Masterpieces Classical',
    genre: 'Classical / Symphony',
    streamUrl: 'https://stream.zeno.fm/4w8u22yv988uv',
    accentColor: Color(0xFF26A69A),
    icon: Icons.piano_rounded,
    description: '巴赫、莫扎特与肖邦钢琴交响世界名曲',
  ),
  RadioStation(
    id: 'radio_synth',
    name: 'Synthwave & Cyberpunk',
    genre: 'Electronic / Retro',
    streamUrl: 'https://stream.zeno.fm/w2g8p4zv988uv',
    accentColor: Color(0xFFAB47BC),
    icon: Icons.electric_bolt_rounded,
    description: '80年代复古电子音浪与赛博朋克节拍',
  ),
  RadioStation(
    id: 'radio_ambient',
    name: 'Deep Ambient Sleep',
    genre: 'Ambient / Drone',
    streamUrl: 'https://stream.zeno.fm/k2kzp72x3z8uv',
    accentColor: Color(0xFF37474F),
    icon: Icons.bedtime_rounded,
    description: '白噪音、大自然与冥想深层助眠声景',
  ),
  RadioStation(
    id: 'radio_game',
    name: 'Game Soundtracks',
    genre: 'OST / Instrumental',
    streamUrl: 'https://stream.zeno.fm/m9e1h4zv988uv',
    accentColor: Color(0xFFEC407A),
    icon: Icons.sports_esports_rounded,
    description: '经典怀旧与次时代史诗级游戏原声大碟',
  ),
];

class RadiosScreen extends ConsumerWidget {
  const RadiosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }

    final playerService = ref.watch(audioPlayerProvider);

    return StreamBuilder<({String? id, bool playing})>(
      stream: playerService.snapshot
          .map((state) => (id: state.currentItem?.id, playing: state.playing))
          .distinct(),
      initialData: (
        id: playerService.currentSnapshot?.currentItem?.id,
        playing: playerService.currentSnapshot?.playing ?? false,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data ?? (id: null, playing: false);
        final currentStationId = state.id;
        final isPlaying = state.playing;

        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  title: Text(
                    context.l10n.navRadios,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  floating: true,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.crossAxisExtent / 260)
                          .floor()
                          .clamp(1, 4)
                          .toInt();

                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: _presetStations.length,
                        itemBuilder: (context, index) {
                          final station = _presetStations[index];
                          final isCurrent = currentStationId == station.id;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (isCurrent && isPlaying) {
                                  await playerService.pause();
                                } else {
                                  final item = PlayableItem(
                                    id: station.id,
                                    title: station.name,
                                    artist: station.genre,
                                    album: context.l10n.internetRadio,
                                    streamUrl: station.streamUrl,
                                  );
                                  await playerService.setQueue(<PlayableItem>[
                                    item,
                                  ]);
                                  await playerService.play();
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? station.accentColor.withValues(
                                          alpha: 0.25,
                                        )
                                      : const Color(0xFF1C1D24),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCurrent
                                        ? station.accentColor
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: isCurrent ? 1.5 : 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: station.accentColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        station.icon,
                                        color: station.accentColor,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Text(
                                            station.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            station.genre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: station.accentColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (station.description != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              station.description!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withValues(
                                                  alpha: 0.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isCurrent && isPlaying
                                            ? station.accentColor
                                            : Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCurrent && isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
      },
    );
  }
}
