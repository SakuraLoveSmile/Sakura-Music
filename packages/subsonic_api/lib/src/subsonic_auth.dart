import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Builds the token-based authentication parameters required by Subsonic.
class SubsonicAuth {
  const SubsonicAuth({
    this.version = defaultVersion,
    this.clientName = defaultClientName,
    this.saltSeed = defaultSaltSeed,
  });

  static const defaultVersion = '1.16.1';
  static const defaultClientName = 'sakuramusic';
  static const defaultSaltSeed = 'sakuramusic-media';

  final String version;
  final String clientName;

  /// A stable seed used to sign media URLs. Ordinary API requests still use a
  /// fresh random salt. Set this to null to restore random media salts.
  final String? saltSeed;

  /// Returns `md5(password + salt)`, the token used by the Subsonic API.
  static String tokenFor({required String password, required String salt}) {
    return md5.convert(utf8.encode('$password$salt')).toString();
  }

  /// Derives the deterministic salt used for a stream or cover-art URL.
  String stableSaltFor({required String password, required String id}) {
    final seed = saltSeed;
    if (seed == null) {
      return createSalt();
    }
    return md5.convert(utf8.encode('$password$id$seed')).toString();
  }

  /// Creates a cryptographically random salt suitable for one request.
  String createSalt([int length = 16]) {
    if (length < 1) {
      throw ArgumentError.value(length, 'length', 'must be positive');
    }

    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  /// Returns a fresh set of authentication parameters for a request.
  Map<String, String> parameters({
    required String username,
    required String password,
    String? salt,
    String? stableId,
  }) {
    final requestSalt =
        salt ??
        (stableId == null
            ? createSalt()
            : stableSaltFor(password: password, id: stableId));
    return <String, String>{
      'u': username,
      't': tokenFor(password: password, salt: requestSalt),
      's': requestSalt,
      'v': version,
      'c': clientName,
      'f': 'json',
    };
  }
}
