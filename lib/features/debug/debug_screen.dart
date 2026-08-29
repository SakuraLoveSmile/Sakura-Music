import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../audio/playback_debug_log.dart';
import '../../data/settings_repository.dart';
import '../../l10n/l10n.dart';

/// Collects on-device playback evidence to diagnose silent playback.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  List<AudioDevice> _outputDevices = <AudioDevice>[];
  int? _selectedDeviceId;
  StreamSubscription<Set<AudioDevice>>? _devicesSub;

  bool _safeAudioMode = false;
  bool _selfTesting = false;
  AudioPlayer? _selfTestPlayer;

  @override
  void initState() {
    super.initState();
    _loadSafeAudioMode();
    _initDevices();
  }

  Future<void> _loadSafeAudioMode() async {
    final settings = await ref.read(settingsRepositoryProvider).read();
    if (mounted) {
      setState(() => _safeAudioMode = settings?.safeAudioMode ?? false);
    }
  }

  Future<void> _initDevices() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      if (mounted) {
        setState(
          () => _outputDevices = devices.where((d) => d.isOutput).toList(),
        );
      }
      _devicesSub = session.devicesStream.listen((set) {
        if (!mounted) {
          return;
        }
        final outputs = set.where((d) => d.isOutput).toList();
        setState(() {
          _outputDevices = outputs;
          // A disconnected device automatically falls back to the system
          // default route, so the UI selection follows.
          if (_selectedDeviceId != null &&
              !outputs.any((d) => int.tryParse(d.id) == _selectedDeviceId)) {
            _selectedDeviceId = null;
          }
        });
      });
    } catch (error) {
      playbackDebugLog.add('DebugScreen devices init failed: $error');
    }
  }

  Future<void> _selectOutputDevice(AudioDevice? device) async {
    final name = device?.name ?? context.l10n.debugOutputDeviceDefault;
    // audio_session exposes Android device ids as strings; the native
    // just_audio channel expects the underlying integer id.
    final deviceId = device == null ? null : int.tryParse(device.id);
    playbackDebugLog.add('DebugScreen select output device: $name');
    final applied = await ref
        .read(audioPlayerProvider)
        .setPreferredOutputDevice(deviceId);
    playbackDebugLog.add('DebugScreen select output device applied: $applied');
    if (!mounted) {
      return;
    }
    if (applied) {
      setState(() => _selectedDeviceId = deviceId);
    }
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? l10n.debugOutputDeviceApplied(name)
              : l10n.debugOutputDeviceFailed,
        ),
      ),
    );
  }

  Future<void> _toggleSafeAudioMode(bool value) async {
    await ref
        .read(settingsRepositoryProvider)
        .updateSafeAudioMode(enabled: value);
    playbackDebugLog.add('safeAudioMode -> $value (restart to apply)');
    if (mounted) {
      setState(() => _safeAudioMode = value);
    }
  }

  Future<void> _toggleSelfTest() async {
    if (_selfTesting || _selfTestPlayer != null) {
      await _stopSelfTest();
      return;
    }
    final snapshot = ref.read(audioPlayerProvider).currentSnapshot;
    final item = snapshot?.currentItem;
    if (item == null || item.streamUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.debugNoTrack)));
      }
      return;
    }
    try {
      final player = AudioPlayer();
      _selfTestPlayer = player;
      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _selfTesting = state.playing);
        }
        playbackDebugLog.add(
          'selfTest playerState: ${state.processingState.name} '
          'playing=${state.playing}',
        );
      });
      await player.setUrl(item.streamUrl);
      await player.play();
      playbackDebugLog.add('selfTest play: ${item.streamUrl}');
      if (mounted) {
        setState(() => _selfTesting = true);
      }
    } catch (error) {
      playbackDebugLog.add('selfTest error: $error');
      if (mounted) {
        setState(() => _selfTesting = false);
      }
    }
  }

  Future<void> _stopSelfTest() async {
    try {
      await _selfTestPlayer?.stop();
      await _selfTestPlayer?.dispose();
    } catch (_) {
      // Ignore teardown errors.
    }
    _selfTestPlayer = null;
    if (mounted) {
      setState(() => _selfTesting = false);
    }
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _selfTestPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          tooltip: l10n.back,
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.debugTitle,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _SnapshotCard(),
          const SizedBox(height: 16),
          _AudioSessionCard(
            devices: _outputDevices,
            selectedDeviceId: _selectedDeviceId,
            onSelect: _selectOutputDevice,
            selectionSupported: !Platform.isWindows,
          ),
          const SizedBox(height: 16),
          _SafeAudioCard(
            value: _safeAudioMode,
            onChanged: _toggleSafeAudioMode,
          ),
          const SizedBox(height: 16),
          _SelfTestCard(testing: _selfTesting, onToggle: _toggleSelfTest),
          const SizedBox(height: 16),
          _LogCard(),
        ],
      ),
    );
  }
}

class _SnapshotCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final service = ref.watch(audioPlayerProvider);

    return StreamBuilder<PlayerSnapshot>(
      stream: service.snapshot,
      initialData: service.currentSnapshot,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final rows = <String, String>{
          l10n.debugStatus: data?.status.name ?? '—',
          l10n.debugPlaying: (data?.playing ?? false)
              ? l10n.debugPlaying
              : 'false',
          l10n.debugPosition: _fmt(data?.position),
          l10n.debugDuration: _fmt(data?.duration),
          l10n.debugVolume: (data?.volume ?? 0).toStringAsFixed(2),
          l10n.debugIndex: (data?.currentIndex ?? '—').toString(),
          l10n.debugQueueLen: (data?.queue.length ?? 0).toString(),
        };
        return _Card(
          title: l10n.debugSnapshot,
          child: Column(
            children: rows.entries
                .map((e) => _KeyValueRow(label: e.key, value: e.value))
                .toList(),
          ),
        );
      },
    );
  }

  static String _fmt(Duration? duration) {
    if (duration == null) return '—';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:${seconds.padLeft(2, '0')}';
  }
}

class _AudioSessionCard extends StatelessWidget {
  const _AudioSessionCard({
    required this.devices,
    required this.selectedDeviceId,
    required this.onSelect,
    required this.selectionSupported,
  });

  final List<AudioDevice> devices;
  final int? selectedDeviceId;
  final ValueChanged<AudioDevice?> onSelect;
  final bool selectionSupported;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _Card(
      title: l10n.debugAudioSession,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!selectionSupported)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Windows 桌面播放器暂不支持应用内切换输出设备',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          _KeyValueRow(
            label: l10n.debugOutputDevices,
            value: devices.length.toString(),
          ),
          const SizedBox(height: 8),
          _DeviceTile(
            icon: Icons.speaker,
            name: l10n.debugOutputDeviceDefault,
            selected: selectedDeviceId == null,
            onTap: selectionSupported ? () => onSelect(null) : null,
          ),
          if (devices.isEmpty)
            const _DeviceTile(
              icon: Icons.volume_up,
              name: '—',
              selected: false,
              onTap: null,
            )
          else
            ...devices.map(
              (device) => _DeviceTile(
                icon: Icons.volume_up,
                name: device.name,
                selected: selectedDeviceId == int.tryParse(device.id),
                onTap: selectionSupported ? () => onSelect(device) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.name,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlightColor = const Color(0xFF64D2FF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF0A84FF).withValues(alpha: 0.16)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? highlightColor : Colors.white54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check, size: 14, color: highlightColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafeAudioCard extends StatelessWidget {
  const _SafeAudioCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Card(
      title: l10n.debugSafeAudioMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.debugSafeAudioHint,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Switch(
                value: value,
                activeTrackColor: const Color(0xFF1E7BF6),
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelfTestCard extends StatelessWidget {
  const _SelfTestCard({required this.testing, required this.onToggle});

  final bool testing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Card(
      title: l10n.debugSelfTest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.debugSelfTestHint,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(testing ? Icons.stop : Icons.play_arrow, size: 18),
                  label: Text(
                    testing ? l10n.debugSelfTestStop : l10n.debugSelfTestStart,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: testing
                      ? const Color(0xFF30D158).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  testing ? l10n.debugSelfTestPlaying : l10n.debugSelfTestIdle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _Card(
      title: l10n.debugLog,
      action: TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: playbackDebugLog.copyAllText()),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.debugCopied)));
          }
        },
        icon: const Icon(Icons.copy, size: 16),
        label: Text(l10n.debugCopyLog),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF64D2FF)),
      ),
      child: SizedBox(
        height: 260,
        child: StreamBuilder<PlaybackLogEntry>(
          stream: playbackDebugLog.stream,
          builder: (context, _) {
            final entries = playbackDebugLog.entries;
            if (entries.isEmpty) {
              return Center(
                child: Text(
                  l10n.debugLogEmpty,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              );
            }
            return ListView.builder(
              reverse: true,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[entries.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    entry.line,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final Widget trailing = action ?? const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
