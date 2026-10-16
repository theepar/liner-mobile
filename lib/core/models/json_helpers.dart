typedef JsonMap = Map<String, dynamic>;

JsonMap? asMap(Object? value) => value is JsonMap ? value : null;

List<Object?>? asList(Object? value) => value is List ? value : null;

String? asString(Object? value) => value is String ? value : null;

bool? asBool(Object? value) => value is bool ? value : null;

int? asInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text),
  _ => null,
};

/// Parses every map entry of [raw] with [parse], skipping malformed entries so
/// that one bad item never discards the whole list.
List<T> parseList<T>(Object? raw, T Function(JsonMap json) parse) {
  if (raw is! List) return <T>[];
  return [
    for (final item in raw)
      if (item is JsonMap) parse(item),
  ];
}
