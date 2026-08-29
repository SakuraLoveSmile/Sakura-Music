import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/security/sensitive_data_redactor.dart';

void main() {
  group('redactSensitiveText', () {
    test('redacts Subsonic u/t/s query parameters but keeps host and id', () {
      const input = 'https://host/rest/stream?id=123&u=user&t=abcdef&s=abcdef';
      final output = redactSensitiveText(input);
      expect(
        output,
        'https://host/rest/stream?id=123&u=<redacted>'
        '&t=<redacted>&s=<redacted>',
      );
      expect(output, contains('host/rest/stream'));
      expect(output, contains('id=123'));
      expect(output, isNot(contains('user')));
      expect(output, isNot(contains('abcdef')));
    });

    test('redacts Basic auth header and standalone Basic credentials', () {
      expect(
        redactSensitiveText('Authorization: Basic dXNlcjpwYXNz'),
        'Authorization: Basic <redacted>',
      );
      expect(
        redactSensitiveText('{Authorization: Basic dXNlcjpwYXNz}'),
        '{Authorization: Basic <redacted>}',
      );
      expect(
        redactSensitiveText('request failed with Basic dXNlcjpwYXNz'),
        isNot(contains('dXNlcjpwYXNz')),
      );
    });

    test('redacts Bearer tokens', () {
      expect(
        redactSensitiveText('Authorization: Bearer mb_abc123def'),
        'Authorization: Bearer <redacted>',
      );
      expect(
        redactSensitiveText('ListenBrainz Bearer mb_abc123def failed'),
        'ListenBrainz Bearer <redacted> failed',
      );
    });

    test('handles URL parameter order variations', () {
      const reversed = 'https://host/rest/stream?s=abcdef&t=abcdef&u=user';
      final output = redactSensitiveText(reversed);
      expect(
        output,
        'https://host/rest/stream?s=<redacted>'
        '&t=<redacted>&u=<redacted>',
      );

      const first =
          'https://host/rest/getCoverArt?u=user&t=tok&id=al-1&size=600';
      final firstOutput = redactSensitiveText(first);
      expect(firstOutput, contains('u=<redacted>'));
      expect(firstOutput, contains('t=<redacted>'));
      expect(firstOutput, contains('id=al-1'));
      expect(firstOutput, contains('size=600'));
    });

    test('leaves ordinary URLs and text untouched', () {
      const plain =
          'https://host/rest/getAlbumList?type=newest&size=12&offset=30 '
          'loaded 12 albums at 2026-08-29T10:00:00';
      expect(redactSensitiveText(plain), plain);

      const noParams = 'https://music.example.com/subsonic/rest/stream?id=5';
      expect(redactSensitiveText(noParams), noParams);
    });

    test('redacts multiple sensitive fields at once', () {
      const input =
          'GET https://host/rest/stream?id=9&u=admin&t=md5token '
          'Authorization: Basic dXNlcjpwYXNz password=hunter2 token=jwt.value';
      final output = redactSensitiveText(input);
      expect(output, contains('u=<redacted>'));
      expect(output, contains('t=<redacted>'));
      expect(output, contains('Authorization: Basic <redacted>'));
      expect(output, contains('password: <redacted>'));
      expect(output, contains('token: <redacted>'));
      expect(output, isNot(contains('admin')));
      expect(output, isNot(contains('md5token')));
      expect(output, isNot(contains('dXNlcjpwYXNz')));
      expect(output, isNot(contains('hunter2')));
      expect(output, isNot(contains('jwt.value')));
    });

    test('does not redact non-credential lookalike words', () {
      const input = 'title=Hello total=5 size=1200 entries=2';
      expect(redactSensitiveText(input), input);
    });

    test('redacts WebDAV Authorization header values', () {
      const input =
          "headers: {Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=}, url: https://dav/rel.flac";
      final output = redactSensitiveText(input);
      expect(output, contains('Authorization: Basic <redacted>'));
      expect(output, isNot(contains('dXNlcm5hbWU6cGFzc3dvcmQ=')));
      expect(output, contains('https://dav/rel.flac'));
    });
  });
}
