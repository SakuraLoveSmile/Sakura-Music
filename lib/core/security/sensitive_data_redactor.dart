/// Replaces credential-bearing substrings in diagnostics text with
/// `<redacted>` markers so logs, crash reports and clipboard exports can be
/// shared without leaking server credentials.
///
/// The host/path/id of a URL is kept (it is what debugging needs); only the
/// credential values are replaced:
///
/// ```text
/// https://host/rest/stream?id=123&u=user&t=abcdef&s=salt
///   -> https://host/rest/stream?id=123&u=<redacted>&t=<redacted>&s=<redacted>
/// Authorization: Basic dXNlcjpwYXNz
///   -> Authorization: Basic <redacted>
/// ```
String redactSensitiveText(String input) {
  if (input.isEmpty) {
    return input;
  }
  var output = input;

  // `Authorization: Basic ...` / `Authorization: Bearer ...` header values
  // (also matches the plain-map `toString()` form `{Authorization: Basic x}`).
  output = output.replaceAllMapped(
    RegExp(
      '(authorization\\s*[:=]\\s*)(basic|bearer)\\s+[^\\s,"\'&})]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)} <redacted>',
  );

  // Standalone `Basic <base64>` / `Bearer <token>` credentials that survive
  // outside a full header line.
  output = output.replaceAllMapped(
    RegExp('\\b(basic|bearer)\\s+[A-Za-z0-9+/=._-]{6,}', caseSensitive: false),
    (match) => '${match.group(1)} <redacted>',
  );

  // Credential-bearing URL query parameters. These must directly follow `?`
  // or `&` so ordinary words like `t=` inside prose are left untouched.
  output = output.replaceAllMapped(
    RegExp(
      '([?&])(u|p|t|s|password|token|apikey|api_key)=([^&\\s"\'<>]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)}=<redacted>',
  );

  // Body / map style assignments: `password=...`, `"token":"..."`,
  // `{password: ...}`. The marker value is excluded so an already redacted
  // fragment is not rewritten again.
  output = output.replaceAllMapped(
    RegExp(
      '["\']?\\b(password|token|secret)\\b["\']?\\s*[:=]\\s*'
      '(?:"[^"]*"|\'[^\']*\'|(?!<redacted>)[^\\s,;&}]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: <redacted>',
  );

  return output;
}
