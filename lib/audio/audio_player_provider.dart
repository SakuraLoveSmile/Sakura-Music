import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_service.dart';
import 'just_audio_service.dart';
import 'media_kit_audio_service.dart';

AudioPlayerService createPlatformAudioPlayerService() {
  if (Platform.isMacOS || Platform.isWindows) {
    return MediaKitAudioPlayerService();
  }
  return JustAudioPlayerService();
}

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final service = createPlatformAudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
