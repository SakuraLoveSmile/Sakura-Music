import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/webdav/webdav_client.dart';
import 'package:sakuramusic/data/webdav/webdav_providers.dart';
import 'package:sakuramusic/features/webdav/webdav_browse_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Widget coverage for the WebDAV browse screen. Four behaviours only exist in
/// the widget layer and are pinned here:
///
/// * AC7 — the folder remembered for the active server is restored *before* the
///   first listing request, so the root (`''`) is never listed by accident.
/// * AC8 — every navigation (folder tap, up) is written back to the database.
/// * AC9 — a row shows the tag title/`artist · album` when the file carries
///   tags and otherwise falls back to the cleaned-up file name.
/// * AC10 — tapping a row enqueues the whole folder starting at that row
///   (zero-based), so the queue order and the row order agree.
/// * Row state reuse — `ListView.builder` reuses one row state per index, so a
///   row that is handed a different href (leaving a folder and coming back)
///   must report its tags again instead of falling back to the file name.
///
/// `WebDavClient` and `AudioPlayerService` are replaced by hand-written fakes:
/// no HTTP request and no platform player is involved, only the fake client's
/// canned listings and canned tag bytes. The screen is mounted with the real
/// [AppDatabase] (in-memory) so the remembered-path round-trip is the
/// production one. The 16-byte ID3 helper below is local on purpose: this file
/// must not depend on the other WebDAV test files.
void main() {
  testWidgets('restores the remembered folder and never lists the root (AC7)', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setWebDavLastPath(1, '/Backup/%E9%9F%B3%E4%B9%90/');

    final client = _FakeWebDavClient()
      ..listings['/Backup/%E9%9F%B3%E4%B9%90/'] = const <WebDavEntry>[
        WebDavEntry(
          href: '/Backup/%E9%9F%B3%E4%B9%90/Live/',
          name: 'Live',
          isDirectory: true,
        ),
        WebDavEntry(
          href: '/Backup/%E9%9F%B3%E4%B9%90/01%20-%20Song.mp3',
          name: '01 - Song.mp3',
          isDirectory: false,
        ),
      ];
    final player = _FakePlayerService();

    await _pumpBrowse(
      tester,
      database: database,
      client: client,
      player: player,
    );

    // The remembered folder is read from the database first, so the root is
    // never requested.
    expect(client.listCalls, <String>['/Backup/%E9%9F%B3%E4%B9%90/']);
    // The app bar shows the decoded path, never the raw percent-encoded href.
    expect(find.text('/Backup/音乐/'), findsOneWidget);
    expect(find.text('/Backup/%E9%9F%B3%E4%B9%90/'), findsNothing);
    // The breadcrumb renders the decoded segment name.
    expect(find.text('音乐'), findsOneWidget);
    // The remembered folder's own listing is what got rendered.
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);
  });

  testWidgets('lists the root when no folder was remembered', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final client = _FakeWebDavClient()
      ..listings[''] = const <WebDavEntry>[
        WebDavEntry(href: '/Music/', name: 'Music', isDirectory: true),
        WebDavEntry(
          href: '/Root%20Song.mp3',
          name: 'Root Song.mp3',
          isDirectory: false,
        ),
      ];
    final player = _FakePlayerService();

    await _pumpBrowse(
      tester,
      database: database,
      client: client,
      player: player,
    );

    expect(client.listCalls, <String>['']);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Root Song'), findsOneWidget);
  });

  testWidgets('persists the folder on every navigation (AC8)', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final client = _FakeWebDavClient()
      ..listings[''] = const <WebDavEntry>[
        WebDavEntry(href: '/Backup/', name: 'Backup', isDirectory: true),
      ]
      ..listings['/Backup/'] = const <WebDavEntry>[
        WebDavEntry(
          href: '/Backup/Inside.mp3',
          name: 'Inside.mp3',
          isDirectory: false,
        ),
      ];
    final player = _FakePlayerService();

    await _pumpBrowse(
      tester,
      database: database,
      client: client,
      player: player,
    );

    expect(client.listCalls, <String>['']);
    expect(await database.getWebDavLastPath(1), '');

    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();

    // The href is stored verbatim (encoded, with the trailing slash).
    expect(await database.getWebDavLastPath(1), '/Backup/');
    expect(client.listCalls, <String>['', '/Backup/']);
    expect(find.text('/Backup/'), findsOneWidget);
    expect(find.text('Inside'), findsOneWidget);
  });

  testWidgets('persists the root when navigating up from a remembered folder', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setWebDavLastPath(1, '/Backup/');

    final client = _FakeWebDavClient()
      ..listings['/Backup/'] = const <WebDavEntry>[
        WebDavEntry(
          href: '/Backup/Inside.mp3',
          name: 'Inside.mp3',
          isDirectory: false,
        ),
      ]
      ..listings[''] = const <WebDavEntry>[
        WebDavEntry(
          href: '/Root%20Song.mp3',
          name: 'Root Song.mp3',
          isDirectory: false,
        ),
      ];
    final player = _FakePlayerService();

    await _pumpBrowse(
      tester,
      database: database,
      client: client,
      player: player,
    );

    expect(client.listCalls, <String>['/Backup/']);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // `/Backup/` loses its only segment, so the remembered folder is the root.
    expect(await database.getWebDavLastPath(1), '');
    expect(client.listCalls, <String>['/Backup/', '']);
    expect(find.text('Root Song'), findsOneWidget);
  });

  testWidgets(
    'shows tag metadata and falls back to the cleaned file name (AC9)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        // One folder, so both section headers are rendered.
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(href: '/Sub/', name: 'Sub', isDirectory: true),
          WebDavEntry(
            href: '/tagged.mp3',
            name: '01 tagged-file.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/plain.flac',
            name: '02 - Plain Song.flac',
            isDirectory: false,
          ),
        ]
        ..tagBytes['/tagged.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Tag Title',
          'TPE1': 'Tag Artist',
          'TALB': 'Tag Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      // Tagged row: the tag title wins, with `artist · album` as the subtitle.
      expect(find.text('Tag Title'), findsOneWidget);
      expect(find.text('Tag Artist \u00B7 Tag Album'), findsOneWidget);
      expect(find.text('01 tagged-file.mp3'), findsNothing);

      // Untagged row: falls back to `cleanTrackTitle('02 - Plain Song.flac')`.
      expect(find.text('Plain Song'), findsOneWidget);
      expect(find.text('02 - Plain Song.flac'), findsNothing);

      // Localized section headers, each exactly once.
      expect(find.text('文件夹'), findsOneWidget);
      expect(find.text('歌曲'), findsOneWidget);
    },
  );

  testWidgets('enqueues the whole folder starting at the tapped row (AC10)', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final client = _FakeWebDavClient()
      ..listings[''] = const <WebDavEntry>[
        WebDavEntry(href: '/one.mp3', name: '01 - One.mp3', isDirectory: false),
        WebDavEntry(href: '/two.mp3', name: '02 - Two.mp3', isDirectory: false),
        WebDavEntry(
          href: '/three.flac',
          name: '03 - Three.flac',
          isDirectory: false,
        ),
      ];
    final player = _FakePlayerService();

    await _pumpBrowse(
      tester,
      database: database,
      client: client,
      player: player,
    );

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Two'));
    await tester.pumpAndSettle();

    expect(player.queues, hasLength(1));
    expect(player.queues.single, hasLength(3));
    expect(player.queues.single.map((item) => item.title).toList(), <String>[
      'One',
      'Two',
      'Three',
    ]);
    // Zero-based index of the tapped row.
    expect(player.startIndexes, <int>[1]);
    expect(player.playCalls, 1);
    // The stream URL and auth header come from the fake client's base URL.
    expect(player.queues.single.first.streamUrl, 'https://dav.test/one.mp3');
    expect(player.queues.single.first.headers, <String, String>{
      'Authorization': 'Basic bGlzdGVuZXI6c2VjcmV0',
    });
  });

  testWidgets(
    'enqueues tag titles for rows whose tags were resolved (AC9/AC10)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(
            href: '/tagged.mp3',
            name: '01 tagged-file.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/plain.flac',
            name: '02 - Plain Song.flac',
            isDirectory: false,
          ),
        ]
        ..tagBytes['/tagged.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Tag Title',
          'TPE1': 'Tag Artist',
          'TALB': 'Tag Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      // Both rows rendered: the tagged one through its tag title.
      expect(find.text('Tag Title'), findsOneWidget);
      expect(find.text('Plain Song'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Tag Title'));
      await tester.pumpAndSettle();

      expect(player.queues, hasLength(1));
      expect(player.queues.single, hasLength(2));
      // The row that already resolved its tags keeps them in the queue instead
      // of starting a fresh probe per file.
      expect(player.queues.single[0].title, 'Tag Title');
      expect(player.queues.single[0].artist, 'Tag Artist');
      expect(player.queues.single[0].album, 'Tag Album');
      // No tags were resolved for this file, so it falls back to the cleaned
      // file name and carries no artist/album.
      expect(player.queues.single[1].title, 'Plain Song');
      expect(player.queues.single[1].artist, isNull);
      expect(player.queues.single[1].album, isNull);
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
    },
  );

  // Regression: `ListView.builder` reuses one row state per index. Browsing
  // into a folder and back hands a different href to a row state that already
  // reported the sub folder's tags, so the upward report has to be remembered
  // per href instead of being latched off for the lifetime of the state.
  testWidgets(
    'keeps tag metadata when returning to the parent folder (regression)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        // One folder plus one song: the root song row sits on index 3, the same
        // index the sub folder's third song row occupies.
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(href: '/Sub/', name: 'Sub', isDirectory: true),
          WebDavEntry(
            href: '/tagged-root.mp3',
            name: '01 - Root Song.mp3',
            isDirectory: false,
          ),
        ]
        ..listings['/Sub/'] = const <WebDavEntry>[
          WebDavEntry(href: '/Sub/s1.mp3', name: 's1.mp3', isDirectory: false),
          WebDavEntry(href: '/Sub/s2.mp3', name: 's2.mp3', isDirectory: false),
          WebDavEntry(href: '/Sub/s3.mp3', name: 's3.mp3', isDirectory: false),
        ]
        // Every row that can land on the reused index carries tags, so its row
        // state is latched before the parent folder is shown again.
        ..tagBytes['/tagged-root.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Root Tag Title',
          'TPE1': 'Root Artist',
          'TALB': 'Root Album',
        })
        ..tagBytes['/Sub/s1.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Sub Tag 1',
          'TPE1': 'Sub Artist',
          'TALB': 'Sub Album',
        })
        ..tagBytes['/Sub/s2.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Sub Tag 2',
          'TPE1': 'Sub Artist',
          'TALB': 'Sub Album',
        })
        ..tagBytes['/Sub/s3.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Sub Tag 3',
          'TPE1': 'Sub Artist',
          'TALB': 'Sub Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      // The root row resolves its tags before the folder is opened.
      expect(find.text('Root Tag Title'), findsOneWidget);

      await tester.tap(find.text('Sub'));
      await tester.pumpAndSettle();
      expect(find.text('Sub Tag 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // The parent listing shows the tag title again ...
      expect(find.text('Root Tag Title'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Root Tag Title'));
      await tester.pumpAndSettle();

      // ... and enqueueing still uses the tags, not the cleaned file name.
      expect(player.queues, hasLength(1));
      expect(player.queues.single, hasLength(1));
      expect(player.queues.single.first.title, 'Root Tag Title');
      expect(player.queues.single.first.artist, 'Root Artist');
      expect(player.queues.single.first.album, 'Root Album');
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
    },
  );

  // Regression: the same round trip with two folder levels
  // (root -> A -> B -> root), where the reused row state is the one created for
  // B's listing and survives both steps back up.
  testWidgets(
    'keeps tag metadata on a root -> A -> B -> root round trip (regression)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(href: '/A/', name: 'A', isDirectory: true),
          WebDavEntry(
            href: '/tagged-root.mp3',
            name: '01 - Root Song.mp3',
            isDirectory: false,
          ),
        ]
        // One folder plus three songs: index 3 is a song row here too.
        ..listings['/A/'] = const <WebDavEntry>[
          WebDavEntry(href: '/A/B/', name: 'B', isDirectory: true),
          WebDavEntry(href: '/A/a1.mp3', name: 'a1.mp3', isDirectory: false),
          WebDavEntry(href: '/A/a2.mp3', name: 'a2.mp3', isDirectory: false),
          WebDavEntry(href: '/A/a3.mp3', name: 'a3.mp3', isDirectory: false),
        ]
        ..listings['/A/B/'] = const <WebDavEntry>[
          WebDavEntry(
            href: '/A/B/b1.mp3',
            name: 'b1.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/A/B/b2.mp3',
            name: 'b2.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/A/B/b3.mp3',
            name: 'b3.mp3',
            isDirectory: false,
          ),
        ]
        ..tagBytes['/tagged-root.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Root Tag Title',
          'TPE1': 'Root Artist',
          'TALB': 'Root Album',
        })
        ..tagBytes['/A/a1.mp3'] = _id3v23(<String, String>{
          'TIT2': 'A Tag 1',
          'TPE1': 'A Artist',
          'TALB': 'A Album',
        })
        ..tagBytes['/A/a2.mp3'] = _id3v23(<String, String>{
          'TIT2': 'A Tag 2',
          'TPE1': 'A Artist',
          'TALB': 'A Album',
        })
        ..tagBytes['/A/a3.mp3'] = _id3v23(<String, String>{
          'TIT2': 'A Tag 3',
          'TPE1': 'A Artist',
          'TALB': 'A Album',
        })
        ..tagBytes['/A/B/b1.mp3'] = _id3v23(<String, String>{
          'TIT2': 'B Tag 1',
          'TPE1': 'B Artist',
          'TALB': 'B Album',
        })
        ..tagBytes['/A/B/b2.mp3'] = _id3v23(<String, String>{
          'TIT2': 'B Tag 2',
          'TPE1': 'B Artist',
          'TALB': 'B Album',
        })
        ..tagBytes['/A/B/b3.mp3'] = _id3v23(<String, String>{
          'TIT2': 'B Tag 3',
          'TPE1': 'B Artist',
          'TALB': 'B Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      expect(find.text('Root Tag Title'), findsOneWidget);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(find.text('A Tag 1'), findsOneWidget);

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(find.text('B Tag 3'), findsOneWidget);

      // Back to `/A/`, then back to the root: both listings come from the
      // provider cache, so the row state at index 3 is reused, not rebuilt.
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(find.text('A Tag 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Root Tag Title'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Root Tag Title'));
      await tester.pumpAndSettle();

      expect(player.queues, hasLength(1));
      expect(player.queues.single, hasLength(1));
      expect(player.queues.single.first.title, 'Root Tag Title');
      expect(player.queues.single.first.artist, 'Root Artist');
      expect(player.queues.single.first.album, 'Root Album');
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
    },
  );

  // Regression: the crumb of the folder that is already on screen carries the
  // path the screen is showing, so tapping it re-enters the *same* path. The
  // listing provider is cached and every row keeps its href, so
  // `ListView.builder` reuses the row states and a row that already reported
  // its tags never reports again. Emptying the parent tag cache on such a
  // no-op navigation therefore leaves it empty for good, and enqueueing
  // silently falls back to the cleaned file name.
  testWidgets(
    'keeps tag metadata after re-tapping the current folder crumb (regression)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(href: '/Sub/', name: 'Sub', isDirectory: true),
        ]
        ..listings['/Sub/'] = const <WebDavEntry>[
          WebDavEntry(
            href: '/Sub/s1.mp3',
            name: '01 - Sub One.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/Sub/s2.mp3',
            name: '02 - Sub Two.mp3',
            isDirectory: false,
          ),
        ]
        ..tagBytes['/Sub/s1.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Sub Tag 1',
          'TPE1': 'Sub Artist',
          'TALB': 'Sub Album',
        })
        ..tagBytes['/Sub/s2.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Sub Tag 2',
          'TPE1': 'Sub Artist',
          'TALB': 'Sub Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      await tester.tap(find.text('Sub'));
      await tester.pumpAndSettle();
      // Both rows resolved their tags in this listing.
      expect(find.text('Sub Tag 1'), findsOneWidget);

      // The current folder's own crumb: the same path, so the row states (and
      // their "already reported this href" memory) survive the rebuild.
      final crumb = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Sub'),
      );
      expect(crumb, findsOneWidget);
      await tester.tap(crumb);
      await tester.pumpAndSettle();

      // The listing is unchanged, so the rows are still the same rows.
      expect(find.text('Sub Tag 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Sub Tag 1'));
      await tester.pumpAndSettle();

      expect(player.queues, hasLength(1));
      expect(player.queues.single, hasLength(2));
      // Tag values, never `cleanTrackTitle('01 - Sub One.mp3')`, and never a
      // null artist/album.
      expect(player.queues.single[0].title, 'Sub Tag 1');
      expect(player.queues.single[0].artist, 'Sub Artist');
      expect(player.queues.single[0].album, 'Sub Album');
      expect(player.queues.single[1].title, 'Sub Tag 2');
      expect(player.queues.single[1].artist, 'Sub Artist');
      expect(player.queues.single[1].album, 'Sub Album');
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
    },
  );

  // Regression: at the root the `/` crumb is the current crumb, so tapping it
  // re-enters the root it is already showing. The same crumb text also appears
  // in the app bar (`webdavPathLabel('')` is `/`), so the finder is scoped to
  // the breadcrumb subtree to keep the tap unambiguous.
  testWidgets(
    'keeps tag metadata after re-tapping the root crumb (regression)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _FakeWebDavClient()
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(
            href: '/root-one.mp3',
            name: '01 - Root One.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/root-two.mp3',
            name: '02 - Root Two.mp3',
            isDirectory: false,
          ),
        ]
        ..tagBytes['/root-one.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Root Tag Title',
          'TPE1': 'Root Artist',
          'TALB': 'Root Album',
        })
        ..tagBytes['/root-two.mp3'] = _id3v23(<String, String>{
          'TIT2': 'Root Tag Two',
          'TPE1': 'Root Artist',
          'TALB': 'Root Album',
        });
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      // No folder was remembered, so the root is already on screen.
      expect(client.listCalls, <String>['']);
      expect(find.text('Root Tag Title'), findsOneWidget);

      final rootCrumb = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('/'),
      );
      expect(rootCrumb, findsOneWidget);
      await tester.tap(rootCrumb);
      await tester.pumpAndSettle();

      expect(find.text('Root Tag Title'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Root Tag Title'));
      await tester.pumpAndSettle();

      expect(player.queues, hasLength(1));
      expect(player.queues.single, hasLength(2));
      expect(player.queues.single[0].title, 'Root Tag Title');
      expect(player.queues.single[0].artist, 'Root Artist');
      expect(player.queues.single[0].album, 'Root Album');
      expect(player.queues.single[1].title, 'Root Tag Two');
      expect(player.queues.single[1].artist, 'Root Artist');
      expect(player.queues.single[1].album, 'Root Album');
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
    },
  );

  // Regression: a real WebDAV folder also lists sidecars (`.lrc`, `.jpg`,
  // `.m3u`). They used to be treated as songs, so `cover.jpg` got a row and
  // tapping a song queued its LRC — the player then showed `♪ LRC` with
  // `00:00 / 00:00`. Only real audio files may reach the songs section and the
  // playback queue.
  testWidgets(
    'lists and enqueues only audio files, never their sidecars (regression)',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      // The screen uses an entry's href verbatim, so the listing below is the
      // root and the file hrefs still carry their folder prefix.
      final client = _FakeWebDavClient()
        ..listings[''] = const <WebDavEntry>[
          WebDavEntry(href: '/Album/', name: 'Album', isDirectory: true),
          WebDavEntry(
            href: '/Album/01%20-%20One.mp3',
            name: '01 - One.mp3',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/Album/01%20-%20One.lrc',
            name: '01 - One.lrc',
            isDirectory: false,
          ),
          WebDavEntry(
            href: '/Album/cover.jpg',
            name: 'cover.jpg',
            isDirectory: false,
          ),
        ];
      final player = _FakePlayerService();

      await _pumpBrowse(
        tester,
        database: database,
        client: client,
        player: player,
      );

      // The folder row stays, the audio row shows once, and no sidecar gets a
      // row of its own.
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.textContaining('.lrc'), findsNothing);
      expect(find.textContaining('cover.jpg'), findsNothing);

      await tester.tap(find.widgetWithText(ListTile, 'One'));
      await tester.pumpAndSettle();

      // The whole folder is enqueued, but only its audio file is.
      expect(player.queues, hasLength(1));
      expect(player.queues.single.map((item) => item.id).toList(), <String>[
        '/Album/01%20-%20One.mp3',
      ]);
      expect(player.startIndexes, <int>[0]);
      expect(player.playCalls, 1);
      // Only the audio href was probed for tags.
      expect(client.fetchCalls, contains('/Album/01%20-%20One.mp3'));
      expect(client.fetchCalls.any((href) => href.endsWith('.lrc')), isFalse);
      expect(client.fetchCalls.any((href) => href.endsWith('.jpg')), isFalse);
    },
  );
}

/// Mounts [WebDavBrowseScreen] with the production database and the fakes.
///
/// The three pumps are ordered on purpose: the first lets `_restoreLastPath`
/// finish its database read, the second lets the listing (and the per-row tag
/// probes) complete, and `pumpAndSettle` flushes whatever is left. Every fake
/// completes immediately, so this cannot hang.
Future<void> _pumpBrowse(
  WidgetTester tester, {
  required AppDatabase database,
  required _FakeWebDavClient client,
  required _FakePlayerService player,
}) async {
  final server = Server(
    id: 1,
    name: 'WebDAV',
    baseUrl: 'https://dav.test',
    username: 'listener',
    password: 'secret',
    type: 'webdav',
    createdAt: DateTime(2024, 1, 1),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        activeServerProvider.overrideWithValue(server),
        webdavClientProvider.overrideWithValue(client),
        audioPlayerProvider.overrideWithValue(player),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const WebDavBrowseScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Canned WebDAV server: `list` answers from [listings] and `fetchBytes` from
/// [tagBytes], recording every call so the tests can pin the requested paths.
class _FakeWebDavClient extends WebDavClient {
  _FakeWebDavClient()
    : super(
        baseUrl: 'https://dav.test',
        username: 'listener',
        password: 'secret',
      );

  final Map<String, List<WebDavEntry>> listings = <String, List<WebDavEntry>>{};
  final Map<String, Uint8List> tagBytes = <String, Uint8List>{};

  final List<String> listCalls = <String>[];
  final List<String> fetchCalls = <String>[];

  @override
  Future<List<WebDavEntry>> list(String path) async {
    listCalls.add(path);
    return listings[path] ?? const <WebDavEntry>[];
  }

  @override
  Future<Uint8List> fetchBytes(String href, {int maxBytes = 512 * 1024}) async {
    fetchCalls.add(href);
    return tagBytes[href] ?? Uint8List(0);
  }
}

/// Records what the screen asks the player to do. `snapshot` is empty and
/// `currentSnapshot` is `null`, so every row renders in its "not current"
/// state and only the queue calls matter here.
class _FakePlayerService implements AudioPlayerService {
  final List<List<PlayableItem>> queues = <List<PlayableItem>>[];
  final List<int> startIndexes = <int>[];
  final List<PlayerSnapshot> snapshots = <PlayerSnapshot>[];
  int playCalls = 0;

  @override
  Stream<PlayerSnapshot> get snapshot => const Stream<PlayerSnapshot>.empty();

  @override
  PlayerSnapshot? get currentSnapshot => null;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    queues.add(items);
    startIndexes.add(startIndex);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> playAt(int index) async {}

  @override
  Future<void> insertNext(PlayableItem item) async {}

  @override
  Future<void> removeAt(int index) async {}

  @override
  Future<void> moveItem(int from, int to) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

/// Builds a minimal ID3v2.3 tag block with UTF-8 (encoding `3`) text frames:
/// `ID3` + version `0x03 0x00` + flags `0x00` + syncsafe body length, then
/// per frame: 4-byte id, 4-byte big-endian length, 2 flag bytes, encoding byte
/// and the UTF-8 text.
Uint8List _id3v23(Map<String, String> frames) {
  final body = BytesBuilder();
  frames.forEach((id, text) {
    final payload = <int>[3, ...utf8.encode(text)];
    body
      ..add(utf8.encode(id))
      ..add(<int>[
        (payload.length >> 24) & 0xFF,
        (payload.length >> 16) & 0xFF,
        (payload.length >> 8) & 0xFF,
        payload.length & 0xFF,
      ])
      ..add(<int>[0, 0])
      ..add(payload);
  });
  final bytes = body.takeBytes();
  return Uint8List.fromList(<int>[
    ...utf8.encode('ID3'),
    3,
    0,
    0,
    (bytes.length >> 21) & 0x7F,
    (bytes.length >> 14) & 0x7F,
    (bytes.length >> 7) & 0x7F,
    bytes.length & 0x7F,
    ...bytes,
  ]);
}
