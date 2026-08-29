import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage boundary for server credentials and third-party tokens.
///
/// Implementations persist values on the platform secure storage and keep an
/// in-memory mirror of the server passwords so synchronous provider code
/// (Subsonic/WebDAV client construction) never needs a platform-channel round
/// trip per request.
abstract class CredentialStore {
  Future<String?> readServerPassword(int serverId);

  Future<void> writeServerPassword(int serverId, String password);

  Future<void> deleteServerPassword(int serverId);

  Future<String?> readListenBrainzToken();

  Future<void> writeListenBrainzToken(String? token);

  /// Synchronous mirror read for client construction. Returns null when the
  /// password has not been loaded into memory yet (call [warmUp] at startup).
  String? cachedServerPassword(int serverId);

  /// Preloads the in-memory mirror for the given servers.
  Future<void> warmUp(Iterable<int> serverIds);
}

/// Production implementation backed by the platform keystore / keychain /
/// DPAPI via flutter_secure_storage.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _serverKeyPrefix = 'sakuramusic.server.password.';
  static const _listenBrainzKey = 'sakuramusic.listenbrainz.token';

  final FlutterSecureStorage _storage;
  final Map<int, String?> _serverPasswordCache = <int, String?>{};

  @override
  Future<String?> readServerPassword(int serverId) async {
    if (_serverPasswordCache.containsKey(serverId)) {
      return _serverPasswordCache[serverId];
    }
    final value = await _storage.read(key: '$_serverKeyPrefix$serverId');
    _serverPasswordCache[serverId] = value;
    return value;
  }

  @override
  Future<void> writeServerPassword(int serverId, String password) async {
    await _storage.write(key: '$_serverKeyPrefix$serverId', value: password);
    _serverPasswordCache[serverId] = password;
  }

  @override
  Future<void> deleteServerPassword(int serverId) async {
    await _storage.delete(key: '$_serverKeyPrefix$serverId');
    _serverPasswordCache[serverId] = null;
  }

  @override
  Future<String?> readListenBrainzToken() =>
      _storage.read(key: _listenBrainzKey);

  @override
  Future<void> writeListenBrainzToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _listenBrainzKey);
    } else {
      await _storage.write(key: _listenBrainzKey, value: token);
    }
  }

  @override
  String? cachedServerPassword(int serverId) => _serverPasswordCache[serverId];

  @override
  Future<void> warmUp(Iterable<int> serverIds) async {
    for (final serverId in serverIds) {
      await readServerPassword(serverId);
    }
  }
}
