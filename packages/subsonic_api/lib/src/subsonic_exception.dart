/// An error returned by a Subsonic server.
class SubsonicException implements Exception {
  const SubsonicException(this.code, this.message, {this.cause});

  final int code;
  final String message;
  final Object? cause;

  bool get isAuthenticationError => code == 40 || code == 41;

  @override
  String toString() {
    final details = cause == null ? '' : ' ($cause)';
    return 'SubsonicException($code): $message$details';
  }
}
