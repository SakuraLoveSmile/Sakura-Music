Map<String, dynamic>? asMap(dynamic value) {
  if (value is! Map) {
    return null;
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<dynamic> asList(dynamic value) {
  if (value == null) {
    return const <dynamic>[];
  }
  if (value is List) {
    return value;
  }
  return <dynamic>[value];
}

String? asString(dynamic value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

int? asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool? asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    };
  }
  return null;
}
