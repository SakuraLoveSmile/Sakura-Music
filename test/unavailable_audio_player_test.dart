import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/unavailable_audio_player_service.dart';

void main() {
  test('reports an error snapshot', () {
    final service = UnavailableAudioPlayerService();
    addTearDown(service.dispose);

    final snapshot = service.currentSnapshot;
    expect(snapshot, isNotNull);
    expect(snapshot!.status, PlayerStatus.error);
    expect(snapshot.error, isNotNull);
  });

  test('playback actions fail with a predictable error', () async {
    final service = UnavailableAudioPlayerService();
    addTearDown(service.dispose);

    await expectLater(
      service.setQueue(<PlayableItem>[]),
      throwsA(isA<StateError>()),
    );
    await expectLater(service.play(), throwsA(isA<StateError>()));
    await expectLater(service.seek(Duration.zero), throwsA(isA<StateError>()));
    await expectLater(service.pause(), throwsA(isA<StateError>()));
  });

  test('snapshot subscribers receive the error state', () async {
    final service = UnavailableAudioPlayerService();
    addTearDown(service.dispose);

    final snapshot = await service.snapshot.first;
    expect(snapshot.status, PlayerStatus.error);
  });

  test('dispose is safe to call once', () async {
    final service = UnavailableAudioPlayerService();
    await service.dispose();
    // A second dispose must not throw.
    await service.dispose();
  });
}
