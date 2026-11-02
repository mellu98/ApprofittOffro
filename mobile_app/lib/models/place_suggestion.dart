/// Suggerimento della ricerca nella mappa: un locale oppure una zona.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.distanceMeters,
  });

  final String id;

  /// 'place' per un locale, 'area' per citta, quartieri e vie.
  final String kind;
  final String title;
  final String subtitle;
  final int? distanceMeters;

  bool get isArea => kind == 'area';

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'place').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
    );
  }
}

/// Posizione di una zona scelta dai suggerimenti.
class PlaceArea {
  const PlaceArea({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.south,
    this.west,
    this.north,
    this.east,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final double? south;
  final double? west;
  final double? north;
  final double? east;

  bool get hasViewport =>
      south != null && west != null && north != null && east != null;

  factory PlaceArea.fromJson(Map<String, dynamic> json) {
    final viewport = json['viewport'] as Map<String, dynamic>?;
    return PlaceArea(
      id: (json['id'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: (json['address'] ?? '').toString(),
      south: (viewport?['south'] as num?)?.toDouble(),
      west: (viewport?['west'] as num?)?.toDouble(),
      north: (viewport?['north'] as num?)?.toDouble(),
      east: (viewport?['east'] as num?)?.toDouble(),
    );
  }
}
