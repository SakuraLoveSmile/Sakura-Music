/// Pure helpers for composing and decomposing server base URLs used by the
/// add-server form. Keeping them free of Flutter dependencies makes the
/// paste-tolerant normalization rules easy to unit test.
library;

/// Default port per server type chip in the add-server dialog.
const Map<String, String> serverTypeDefaultPorts = <String, String>{
  'Navidrome': '4533',
  'Subsonic': '4040',
  'OpenSubsonic': '4040',
  'Emby': '8096',
};

/// Builds the full base URL from the split form controls.
///
/// An empty [port] means the scheme's default port and is omitted. Pasting a
/// full URL into [host] is tolerated: a leading `scheme://` is stripped along
/// with surrounding slashes, so `https://example.com/music/` and
/// `example.com/music` compose identically.
String composeBaseUrl({
  required String scheme,
  required String host,
  String? port,
}) {
  var normalizedHost = host.trim();
  final schemeMatch = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9+.-]*://',
  ).firstMatch(normalizedHost);
  if (schemeMatch != null) {
    normalizedHost = normalizedHost.substring(schemeMatch.end);
  }
  normalizedHost = normalizedHost.replaceAll(RegExp(r'^/+|/+$'), '');

  final normalizedPort = port?.trim() ?? '';
  if (normalizedPort.isEmpty) {
    return '$scheme://$normalizedHost';
  }
  // The port belongs after the hostname, never after a reverse-proxy
  // subpath (and never inside an IPv6 literal's brackets).
  final pathStart = normalizedHost.indexOf('/');
  final hostname = pathStart == -1
      ? normalizedHost
      : normalizedHost.substring(0, pathStart);
  final path = pathStart == -1 ? '' : normalizedHost.substring(pathStart);
  return '$scheme://$hostname:$normalizedPort$path';
}

/// The split representation of a stored base URL, used to refill the form in
/// edit mode. [scheme] is always `http` or `https`; [host] carries an optional
/// reverse-proxy subpath; [port] is null when the URL had no explicit port.
class ServerUrlParts {
  const ServerUrlParts({required this.scheme, required this.host, this.port});

  final String scheme;
  final String host;
  final String? port;
}

/// Splits a stored base URL back into form fields. Input without a scheme is
/// treated as https, matching the compose default.
ServerUrlParts decomposeBaseUrl(String baseUrl) {
  var raw = baseUrl.trim();
  if (!raw.contains('://')) {
    raw = 'https://$raw';
  }
  final uri = Uri.tryParse(raw);

  var scheme = 'https';
  var host = '';
  String? port;
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    scheme = uri.scheme;
    final path = uri.path == '/' ? '' : uri.path;
    // Dart's Uri.host strips the brackets from an IPv6 literal; they must be
    // kept so composeBaseUrl can round-trip the address.
    final bareHost = uri.host;
    host = (bareHost.contains(':') ? '[$bareHost]' : bareHost) + path;
    port = uri.hasPort ? uri.port.toString() : null;
  } else {
    host = raw.replaceFirst(RegExp(r'^[a-zA-Z0-9+.-]*://'), '');
  }
  host = host.replaceAll(RegExp(r'^/+|/+$'), '');
  return ServerUrlParts(scheme: scheme, host: host, port: port);
}

/// Best-effort server type for list badges. The type is not persisted, so it is
/// inferred from well-known ports; reverse-proxied servers return null and the
/// badge is simply hidden.
String? inferServerType(String baseUrl) {
  return switch (decomposeBaseUrl(baseUrl).port) {
    '4533' => 'Navidrome',
    '4040' => 'Subsonic',
    '8096' => 'Emby',
    _ => null,
  };
}
