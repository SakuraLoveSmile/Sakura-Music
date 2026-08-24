import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/features/welcome/widgets/server_url.dart';

void main() {
  group('composeBaseUrl', () {
    test('omits an empty port (scheme default)', () {
      expect(
        composeBaseUrl(scheme: 'https', host: 'music.example.com', port: ''),
        'https://music.example.com',
      );
      expect(
        composeBaseUrl(scheme: 'https', host: 'music.example.com'),
        'https://music.example.com',
      );
    });

    test('appends an explicit port', () {
      expect(
        composeBaseUrl(scheme: 'http', host: 'example.com', port: '4533'),
        'http://example.com:4533',
      );
    });

    test('keeps reverse-proxy subpaths', () {
      expect(
        composeBaseUrl(scheme: 'https', host: 'example.com/music', port: null),
        'https://example.com/music',
      );
    });

    test('strips pasted scheme and surrounding slashes', () {
      expect(
        composeBaseUrl(scheme: 'https', host: ' https://music.example.com/ '),
        'https://music.example.com',
      );
      expect(
        composeBaseUrl(scheme: 'http', host: '/example.com/music/'),
        'http://example.com/music',
      );
    });

    test('whitespace-only port is treated as empty', () {
      expect(
        composeBaseUrl(scheme: 'https', host: 'example.com', port: '  '),
        'https://example.com',
      );
    });
  });

  group('decomposeBaseUrl', () {
    test('splits scheme, host and explicit port', () {
      final parts = decomposeBaseUrl('http://example.com:4533');
      expect(parts.scheme, 'http');
      expect(parts.host, 'example.com');
      expect(parts.port, '4533');
    });

    test('scheme default port yields null', () {
      final parts = decomposeBaseUrl('https://music.example.com');
      expect(parts.port, isNull);
    });

    test('keeps subpath in host and drops trailing slash', () {
      final parts = decomposeBaseUrl('https://example.com/music/');
      expect(parts.host, 'example.com/music');
      expect(parts.port, isNull);
    });

    test('treats input without scheme as https', () {
      final parts = decomposeBaseUrl('example.com:4040');
      expect(parts.scheme, 'https');
      expect(parts.host, 'example.com');
      expect(parts.port, '4040');
    });

    test('round-trips through composeBaseUrl', () {
      for (final url in <String>[
        'https://music.example.com',
        'http://192.168.1.10:4533',
        'https://example.com/music',
      ]) {
        final parts = decomposeBaseUrl(url);
        expect(
          composeBaseUrl(scheme: parts.scheme, host: parts.host, port: parts.port),
          url,
        );
      }
    });
  });

  group('inferServerType', () {
    test('maps well-known ports to server types', () {
      expect(inferServerType('https://nd.example.com:4533'), 'Navidrome');
      expect(inferServerType('http://sub.example.com:4040'), 'Subsonic');
      expect(inferServerType('http://media.example.com:8096'), 'Emby');
    });

    test('returns null for unknown or default ports', () {
      expect(inferServerType('https://example.com'), isNull);
      expect(inferServerType('https://example.com:8443'), isNull);
    });
  });
}
