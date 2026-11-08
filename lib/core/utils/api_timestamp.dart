/// Parses timestamps the way the API encodes them.
///
/// The backend is not consistent about the shape of a timestamp: auth user
/// payloads send epoch seconds as strings (`"1699999999"`), while organisation
/// payloads send ISO-8601 strings (`"2023-11-14T22:13:19.000Z"`). Both arrive
/// in the same sign-in response, so every model has to accept either shape.
///
/// Accepts:
/// - ISO-8601 strings, with or without a timezone;
/// - epoch seconds as a [String], [int] or [num].
///
/// Throws a [FormatException] naming [field] when the value is missing or not
/// a recognisable timestamp, so the failure points at the offending field
/// instead of surfacing as a bare cast error.
DateTime parseApiTimestamp(Object? value, {String field = 'timestamp'}) {
  if (value == null) {
    throw FormatException('Missing $field');
  }

  if (value is num) {
    return _fromEpochSeconds(value.toInt());
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) {
    throw FormatException('Empty $field');
  }

  // A bare number parses as an extended year (e.g. "1700000000" becomes the
  // year 169999), so epoch seconds are checked before ISO-8601.
  if (int.tryParse(raw) case final epoch?) {
    return _fromEpochSeconds(epoch);
  }

  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso;

  throw FormatException('Unrecognised $field: $raw');
}

/// [parseApiTimestamp] for model fields that must not fail a whole payload,
/// such as the sign-in response: a missing or unreadable value becomes epoch 0
/// instead of throwing, and epoch seconds come back in local time, as the auth
/// models have always read them.
DateTime parseApiTimestampOrEpoch(Object? value, {String field = 'timestamp'}) {
  try {
    final parsed = parseApiTimestamp(value, field: field);
    final isEpoch =
        value is num || int.tryParse(value.toString().trim()) != null;
    return isEpoch ? parsed.toLocal() : parsed;
  } on FormatException {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

DateTime _fromEpochSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
