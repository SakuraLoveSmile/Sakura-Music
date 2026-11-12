import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/media_kit_audio_service.dart';
import 'package:sakuramusic/audio/playback_coordinator.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/features/player/mini_player_bar.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Real media_kit backend, real coordinator, real `MiniPlayerBar`, in-memory
/// Drift database and a temporary local PCM WAV queue. Nothing here touches the
/// user's library, database or app bootstrap.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Window size used by the manual desktop check in the report.
  const windowSize = Size(1264, 761);

  final List<double> reportedVolumes = <double>[];
  final List<String> trace = <String>[];
  late Directory tempDirectory;
  late AppDatabase database;
  late Player player;
  late MediaKitAudioPlayerService service;
  late PlaybackCoordinator coordinator;
  late StreamSubscription<PlayerSnapshot> snapshots;
  late StreamSubscription<double> backendVolumes;

  double reportedVolume() =>
      reportedVolumes.isEmpty ? double.nan : reportedVolumes.last;

  bool atVolume(double expected) =>
      reportedVolumes.isNotEmpty && (reportedVolume() - expected).abs() < 0.5;

  setUpAll(() {
    MediaKit.ensureInitialized();
  });

  setUp(() async {
    trace.clear();
    reportedVolumes.clear();
    tempDirectory = await Directory.systemTemp.createTemp(
      'sakuramusic_volume_integration',
    );
    trace.add('temp:${tempDirectory.path}');
    final files = <File>[
      await _writeWav(File('${tempDirectory.path}/segment_a.wav')),
      await _writeWav(File('${tempDirectory.path}/segment_b.wav')),
    ];
    // Four queue entries over two equally loud segments, so a switch always has
    // a neighbour and the two clips cannot be told apart by amplitude.
    final queue = <PlayableItem>[
      for (var index = 0; index < 4; index++)
        PlayableItem(
          id: 'track-$index',
          title: 'Track $index',
          streamUrl: files[index % files.length].uri.toString(),
          duration: const Duration(seconds: 8),
        ),
    ];

    database = AppDatabase(NativeDatabase.memory());
    // An empty server: it exists only so the coordinator can persist playback
    // state. No request is issued because the queue is local and the password
    // is empty, so no Subsonic client is built.
    final serverId = await database.insertServer(
      ServersCompanion.insert(
        name: 'Offline integration server',
        baseUrl: 'http://127.0.0.1:9/',
        username: 'demo',
        password: '',
      ),
    );
    final server = (await database.getServer(serverId))!;

    player = Player(
      configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    backendVolumes = player.stream.volume.listen((value) {
      reportedVolumes.add(value);
      trace.add('backend-volume:${value.toStringAsFixed(2)}');
    });
    service = MediaKitAudioPlayerService(player: player);
    snapshots = service.snapshot.listen((snapshot) {
      final line =
          'snapshot: volume=${snapshot.volume} '
          'index=${snapshot.currentIndex} playing=${snapshot.playing} '
          'status=${snapshot.status.name}';
      if (trace.isEmpty || trace.last != line) {
        trace.add(line);
      }
    });
    coordinator = PlaybackCoordinator(
      service: service,
      database: database,
      server: server,
      readPassword: (_) => null,
      saveInterval: const Duration(seconds: 1),
    );
    trace.add('setup:queue');
    await service.setQueue(queue);
    await service.setLoopMode(AppLoopMode.all);
  });

  tearDown(() async {
    // Release in order: coordinator, player (through the service), the streams
    // subscribed by this test, the database, then the files created here.
    await coordinator.dispose();
    await service.dispose();
    await snapshots.cancel();
    await backendVolumes.cancel();
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> pumpMiniPlayer(WidgetTester tester) async {
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          starredIdsProvider.overrideWithValue((
            songs: const <String>{},
            albums: const <String>{},
            artists: const <String>{},
          )),
        ],
        child: MaterialApp(
          // The bar renders localized tooltips, so it needs the app's
          // delegates just like the real shell.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MiniPlayerBar(service: service),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Slider volumeSlider(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider));

  /// The slider value, or null while the bar is not mounted yet.
  double? sliderValue(WidgetTester tester) {
    final finder = find.byType(Slider);
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return tester.widget<Slider>(finder).value;
  }

  /// Waits for a state condition with an explicit timeout; a timeout dumps the
  /// operation order and every volume the backend reported.
  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    required String description,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        _dumpTrace(trace, reportedVolumes);
        throw TimeoutException(
          'condition not met within ${timeout.inSeconds}s: $description',
          timeout,
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// The bar rebuilds from the snapshot stream, so the expected slider value is
  /// waited for instead of read from whatever frame was painted last.
  Future<void> waitForSlider(
    WidgetTester tester,
    double expected, {
    required String description,
  }) => waitFor(
    tester,
    () => sliderValue(tester) == expected,
    description: description,
  );

  /// Reads the persisted volume, polling until the coordinator's asynchronous
  /// save has landed.
  Future<void> expectSavedVolume(
    WidgetTester tester,
    double expected, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var state = await database.getPlaybackState();
    while (state?.volume != expected) {
      if (DateTime.now().isAfter(deadline)) {
        _dumpTrace(trace, reportedVolumes);
        throw TimeoutException(
          'the coordinator persisted ${state?.volume} instead of $expected',
          timeout,
        );
      }
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state = await database.getPlaybackState();
    }
    expect(state?.volume, expected);
  }

  /// Runs [body] and prints the diagnostics when an expectation fails.
  Future<void> tracked(Future<void> Function() body) async {
    try {
      await body();
    } catch (_) {
      _dumpTrace(trace, reportedVolumes);
      rethrow;
    }
  }

  testWidgets('keeps 0.65 across at least 10 real track switches', (
    tester,
  ) async {
    await tracked(() async {
      await pumpMiniPlayer(tester);
      trace.add('setVolume(0.65)');
      await service.setVolume(0.65);
      await tester.pump();
      await waitForSlider(
        tester,
        0.65,
        description: 'the slider shows the user target',
      );

      final mark = reportedVolumes.length;
      await service.play();
      await waitFor(
        tester,
        () => service.currentSnapshot?.playing ?? false,
        description: 'playback started',
      );
      await waitFor(
        tester,
        () => reportedVolumes.length > mark && atVolume(65),
        description: 'the fade-in reached the target output',
      );

      for (var switchNumber = 1; switchNumber <= 10; switchNumber++) {
        final before = service.currentSnapshot!.currentIndex;
        trace.add('next #$switchNumber from index $before');
        await service.next();
        await waitFor(
          tester,
          () => service.currentSnapshot!.currentIndex != before,
          description: 'switch #$switchNumber moved the playlist',
        );
        await waitFor(
          tester,
          () => atVolume(65),
          description: 'switch #$switchNumber returned the output to 65',
        );
        await waitForSlider(
          tester,
          0.65,
          description:
              'the slider must keep the user target after switch '
              '#$switchNumber',
        );
        expect(service.currentSnapshot!.volume, 0.65);
      }

      expect(atVolume(65), isTrue);
      expect(service.currentSnapshot!.volume, 0.65);
      expect(volumeSlider(tester).value, 0.65);
      await expectSavedVolume(tester, 0.65);
    });
  });

  testWidgets('a mid-switch change to 0.35 is applied and kept', (
    tester,
  ) async {
    await tracked(() async {
      await pumpMiniPlayer(tester);
      await service.setVolume(0.65);
      await service.play();
      await waitFor(
        tester,
        () => service.currentSnapshot?.playing ?? false,
        description: 'playback started',
      );
      await waitFor(
        tester,
        () => atVolume(65),
        description: 'the fade-in reached the target output',
      );

      final before = service.currentSnapshot!.currentIndex;
      trace.add('next with a mid-switch volume change');
      final switching = service.next();
      // Let the 120 ms fade-out run, then drive the real slider callback the way
      // a drag would while the switch is still in flight.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      trace.add('slider.onChanged(0.35)');
      volumeSlider(tester).onChanged!(0.35);
      await switching;
      await waitFor(
        tester,
        () => service.currentSnapshot!.currentIndex != before,
        description: 'the switch moved the playlist',
      );
      await waitFor(
        tester,
        () => atVolume(35),
        description: 'the output settled on the new target',
      );
      await waitForSlider(
        tester,
        0.35,
        description: 'the slider shows the new target',
      );
      expect(service.currentSnapshot!.volume, 0.35);
      expect(atVolume(35), isTrue);
      await expectSavedVolume(tester, 0.35);
    });
  });

  testWidgets('a muted target stays silent across switches', (tester) async {
    await tracked(() async {
      await pumpMiniPlayer(tester);
      trace.add('setVolume(0)');
      await service.setVolume(0);
      await service.play();
      await waitFor(
        tester,
        () => service.currentSnapshot?.playing ?? false,
        description: 'playback started',
      );
      await waitFor(
        tester,
        () => atVolume(0),
        description: 'the output is silent',
      );
      await waitForSlider(
        tester,
        0,
        description: 'the slider shows the muted target',
      );

      for (var switchNumber = 1; switchNumber <= 3; switchNumber++) {
        final before = service.currentSnapshot!.currentIndex;
        trace.add('next #$switchNumber while muted');
        await service.next();
        await waitFor(
          tester,
          () => service.currentSnapshot!.currentIndex != before,
          description: 'switch #$switchNumber moved the playlist',
        );
        await waitFor(
          tester,
          () => atVolume(0),
          description: 'switch #$switchNumber stayed silent',
        );
        await waitForSlider(
          tester,
          0,
          description: 'a muted target must survive switch #$switchNumber',
        );
        expect(service.currentSnapshot!.volume, 0);
      }

      // Every report from the moment the output became silent must stay at 0.
      expect(
        reportedVolumes.skipWhile((value) => value != 0),
        everyElement(0.0),
      );
      await expectSavedVolume(tester, 0);
    });
  });
}

/// Writes an 8 s, 8 kHz, 16-bit mono PCM WAV with a steady 440 Hz tone. Both
/// segments use the same amplitude, so switching tracks cannot change the
/// perceived level by itself.
Future<File> _writeWav(
  File file, {
  double amplitude = 0.3,
  int sampleRate = 8000,
  int seconds = 8,
}) async {
  const channels = 1;
  const bitsPerSample = 16;
  const bytesPerSample = channels * bitsPerSample ~/ 8;
  final sampleCount = sampleRate * seconds;
  final dataSize = sampleCount * bytesPerSample;
  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);

  void writeTag(int offset, String tag) {
    for (var index = 0; index < tag.length; index++) {
      bytes[offset + index] = tag.codeUnitAt(index);
    }
  }

  writeTag(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  writeTag(8, 'WAVE');
  writeTag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeTag(36, 'data');
  data.setUint32(40, dataSize, Endian.little);

  final peak = (amplitude * 32767).round();
  for (var index = 0; index < sampleCount; index++) {
    final sample = (peak * math.sin(2 * math.pi * 440 * index / sampleRate))
        .round();
    data.setInt16(44 + index * bytesPerSample, sample, Endian.little);
  }
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

void _dumpTrace(List<String> trace, List<double> reportedVolumes) {
  final buffer = StringBuffer()
    ..writeln('volume retention diagnostics')
    ..writeln('  operation order:');
  for (final entry in trace) {
    buffer.writeln('    $entry');
  }
  buffer.writeln(
    '  backend volume reports (${reportedVolumes.length}): '
    '${reportedVolumes.map((value) => value.toStringAsFixed(1)).join(', ')}',
  );
  debugPrint(buffer.toString());
}
