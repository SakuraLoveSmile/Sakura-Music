import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server_repository.dart';
import 'webdav_client.dart';

/// Builds a [WebDavClient] for the active server, or `null` when no WebDAV
/// server is active.
final webdavClientProvider = Provider<WebDavClient?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null || server.type != 'webdav') {
    return null;
  }
  return WebDavClient(
    baseUrl: server.baseUrl,
    username: server.username,
    password: server.password,
  );
});

/// Directory listing for [path] (empty string = root). Watched by the browse
/// screen so re-entering refreshes automatically.
final webdavListingProvider = FutureProvider.family<List<WebDavEntry>, String>((
  ref,
  path,
) async {
  final client = ref.watch(webdavClientProvider);
  if (client == null) {
    return const <WebDavEntry>[];
  }
  return client.list(path);
});
