import 'package:test/test.dart';

import 'package:subsonic_api/subsonic_api.dart';

void main() {
  test('creates the Subsonic token with a fixed salt', () {
    expect(
      SubsonicAuth.tokenFor(password: 'password', salt: 'salt'),
      'b305cadbb3bce54f3aa59c64fec00dea',
    );
  });

  test('includes all standard request parameters', () {
    final parameters = const SubsonicAuth().parameters(
      username: 'demo',
      password: 'password',
      salt: 'salt',
    );

    expect(parameters, containsPair('u', 'demo'));
    expect(parameters, containsPair('s', 'salt'));
    expect(parameters, containsPair('t', 'b305cadbb3bce54f3aa59c64fec00dea'));
    expect(parameters, containsPair('v', '1.16.1'));
    expect(parameters, containsPair('c', 'sakuramusic'));
    expect(parameters, containsPair('f', 'json'));
  });

  test('derives stable media salts from the password, id, and seed', () {
    const auth = SubsonicAuth(saltSeed: 'seed');
    final first = auth.parameters(
      username: 'demo',
      password: 'password',
      stableId: 'song-1',
    );
    final second = auth.parameters(
      username: 'demo',
      password: 'password',
      stableId: 'song-1',
    );
    final other = auth.parameters(
      username: 'demo',
      password: 'password',
      stableId: 'song-2',
    );

    expect(first['s'], second['s']);
    expect(first['t'], second['t']);
    expect(first['s'], isNot(other['s']));
    expect(
      first['t'],
      SubsonicAuth.tokenFor(password: 'password', salt: first['s']!),
    );
  });
}
