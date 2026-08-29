import '../../data/db/app_database.dart';

/// A server row plus the credential needed to talk to it.
///
/// Business code builds clients from this object instead of reaching into
/// `server.password` — the database copy of the password is empty once the
/// credential lives in the platform secure storage.
class ServerConnection {
  const ServerConnection({required this.server, required this.password});

  final Server server;
  final String password;

  String get baseUrl => server.baseUrl;
  String get username => server.username;
  bool get isWebDav => server.type == 'webdav';
}
