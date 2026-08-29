import 'package:flutter/material.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_service.dart';
import '../../l10n/l10n.dart';

enum AudioQualityTier { lossless, standard }

/// Only reports values that can be derived from real data (Subsonic `suffix`,
/// `bitRate`, the item duration and the stream URL scheme). Everything the
/// server does not tell us is rendered as 未知 instead of a guessed constant:
/// no "FLAC => 96 kHz/24 bit" inference, no fake Hi-Res tier, no fabricated
/// file sizes.
class AudioQualityInfo {
  const AudioQualityInfo({
    required this.tier,
    required this.badgeLabel,
    required this.codec,
    required this.bitrateText,
    required this.sampleRateText,
    required this.bitDepthText,
    required this.channelsText,
    required this.sourceTypeText,
    required this.fileSizeText,
  });

  /// Codecs that are lossless by definition. Lossless is judged only on the
  /// actual codec, never on a high bitrate.
  static const _losslessCodecs = <String>{
    'FLAC',
    'WAV',
    'ALAC',
    'AIFF',
    'APE',
    'DSF',
    'DFF',
    'DSD',
    'WV',
  };

  static const unknownText = '未知';

  factory AudioQualityInfo.fromItem(PlayableItem item, {Song? song}) {
    final rawSuffix = (song?.suffix ?? _extractExtension(item.streamUrl))
        ?.toUpperCase();
    final codec = (rawSuffix != null && rawSuffix.isNotEmpty)
        ? rawSuffix
        : unknownText;
    final isLosslessCodec = _losslessCodecs.contains(codec);

    final tier = isLosslessCodec
        ? AudioQualityTier.lossless
        : AudioQualityTier.standard;

    final bitRate = song?.bitRate;
    final bitrateText = (bitRate != null && bitRate > 0)
        ? '$bitRate kbps'
        : unknownText;

    // Sample rate, bit depth and channel layout are not provided by the
    // Subsonic API responses this app consumes, so they stay unknown.
    const sampleRateText = unknownText;
    const bitDepthText = unknownText;
    const channelsText = unknownText;

    final sourceTypeText = item.streamUrl.startsWith('file:')
        ? '本地文件（已下载）'
        : '服务器在线流';

    String fileSizeText;
    if (item.duration != null && bitRate != null && bitRate > 0) {
      // Arithmetic on real data; still labelled as an estimate.
      final estBytes = (item.duration!.inSeconds * bitRate * 1000) ~/ 8;
      fileSizeText = '~${_formatBytes(estBytes)}（估算）';
    } else {
      fileSizeText = unknownText;
    }

    final parts = <String>[
      if (tier == AudioQualityTier.lossless) 'Lossless',
      if (codec != unknownText) codec,
      if (bitRate != null && bitRate > 0) '${bitRate}k',
    ];
    final badgeLabel = parts.isEmpty ? unknownText : parts.join(' • ');

    return AudioQualityInfo(
      tier: tier,
      badgeLabel: badgeLabel,
      codec: codec,
      bitrateText: bitrateText,
      sampleRateText: sampleRateText,
      bitDepthText: bitDepthText,
      channelsText: channelsText,
      sourceTypeText: sourceTypeText,
      fileSizeText: fileSizeText,
    );
  }

  final AudioQualityTier tier;
  final String badgeLabel;
  final String codec;
  final String bitrateText;
  final String sampleRateText;
  final String bitDepthText;
  final String channelsText;
  final String sourceTypeText;
  final String fileSizeText;

  static String? _extractExtension(String? url) {
    if (url == null) return null;
    final path = url.split('?').first;
    // Only the last path segment can carry a file extension; this avoids
    // misreading host fragments like `example.com/rest/stream` as a codec.
    final slash = path.lastIndexOf('/');
    final segment = slash == -1 ? path : path.substring(slash + 1);
    final dot = segment.lastIndexOf('.');
    if (dot == -1 || dot == segment.length - 1) {
      return null;
    }
    final extension = segment.substring(dot + 1);
    if (!RegExp('^[A-Za-z0-9]{1,5}\$').hasMatch(extension)) {
      return null;
    }
    return extension;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

/// Interactive Capsule Badge that displays audio fidelity info and triggers the Inspector Modal.
class AudioStreamQualityBadge extends StatelessWidget {
  const AudioStreamQualityBadge({
    required this.item,
    this.song,
    this.compact = false,
    super.key,
  });

  final PlayableItem item;
  final Song? song;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = AudioQualityInfo.fromItem(item, song: song);

    final Color primaryColor;
    final Color backgroundColor;
    final Color borderColor;
    final IconData icon;

    switch (info.tier) {
      case AudioQualityTier.lossless:
        primaryColor = const Color(0xFF64B5F6); // Cyan / Sky Blue
        backgroundColor = const Color(0xFF152638);
        borderColor = const Color(0xFF64B5F6).withValues(alpha: 0.4);
        icon = Icons.graphic_eq_rounded;
      case AudioQualityTier.standard:
        primaryColor = Colors.white70;
        backgroundColor = Colors.white.withValues(alpha: 0.08);
        borderColor = Colors.white.withValues(alpha: 0.12);
        icon = Icons.music_note_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            showAudioStreamInspectorSheet(context, item: item, song: song),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: compact ? 2.5 : 3.5,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: compact ? 11 : 12.5, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                info.badgeLabel,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: compact ? 12 : 13,
                color: primaryColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the full Audio Stream Inspector Modal Sheet.
void showAudioStreamInspectorSheet(
  BuildContext context, {
  required PlayableItem item,
  Song? song,
}) {
  final info = AudioQualityInfo.fromItem(item, song: song);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF16171E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              const SizedBox(height: 14),

              // Title Row
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7BF6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF5BA4FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ctx.l10n.audioStreamInspector,
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
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hero Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF182B42), Color(0xFF161C26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF64B5F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          info.tier == AudioQualityTier.lossless
                              ? Icons.verified_rounded
                              : Icons.graphic_eq_rounded,
                          size: 18,
                          color: info.tier == AudioQualityTier.lossless
                              ? const Color(0xFF64B5F6)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          info.tier == AudioQualityTier.lossless
                              ? ctx.l10n.audioLossless
                              : ctx.l10n.audioStandard,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64B5F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      item.artist ?? ctx.l10n.unknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2x3 Grid of Specs Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: <Widget>[
                  _buildSpecCard(
                    icon: Icons.audio_file_outlined,
                    label: ctx.l10n.audioCodec,
                    value: info.codec,
                  ),
                  _buildSpecCard(
                    icon: Icons.speed_rounded,
                    label: ctx.l10n.audioBitrate,
                    value: info.bitrateText,
                  ),
                  _buildSpecCard(
                    icon: Icons.tune_rounded,
                    label: ctx.l10n.audioSampleRate,
                    value: info.sampleRateText,
                  ),
                  _buildSpecCard(
                    icon: Icons.diamond_outlined,
                    label: ctx.l10n.audioBitDepth,
                    value: info.bitDepthText,
                  ),
                  _buildSpecCard(
                    icon: Icons.headphones_outlined,
                    label: ctx.l10n.audioChannels,
                    value: info.channelsText,
                  ),
                  _buildSpecCard(
                    icon: Icons.folder_zip_outlined,
                    label: ctx.l10n.audioFileSize,
                    value: info.fileSizeText,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Source transmission indicator card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.cloud_sync_outlined,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ctx.l10n.audioSourceType,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      info.sourceTypeText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5BA4FF),
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

Widget _buildSpecCard({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1F212B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFF5BA4FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
