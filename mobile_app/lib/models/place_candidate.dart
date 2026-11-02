class PlaceCandidate {
  const PlaceCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.primaryType,
    this.phoneNumber = '',
    this.rating,
    this.ratingCount,
    this.priceLevel,
    this.openNow,
    this.openingHours = const <String>[],
    this.googleMapsUrl = '',
    this.photoUrl = '',
    this.photoAuthor = '',
    this.detailsLoaded = false,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String primaryType;
  final String phoneNumber;

  /// Voto medio Google (1-5) e numero di recensioni.
  final double? rating;
  final int? ratingCount;

  /// Fascia di prezzo Google: 0 gratis, 1 economico ... 4 molto caro.
  final int? priceLevel;

  /// Aperto in questo momento, se Google lo sa.
  final bool? openNow;
  final List<String> openingHours;
  final String googleMapsUrl;
  final String photoUrl;
  final String photoAuthor;

  /// True quando i dettagli completi del locale sono gia stati scaricati.
  final bool detailsLoaded;

  bool get hasGoogleExtras =>
      rating != null || priceLevel != null || openNow != null;

  factory PlaceCandidate.fromJson(Map<String, dynamic> json) {
    return PlaceCandidate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      primaryType: (json['primary_type'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt(),
      priceLevel: (json['price_level'] as num?)?.toInt(),
      openNow: json['open_now'] is bool ? json['open_now'] as bool : null,
      openingHours: (json['opening_hours'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      googleMapsUrl: (json['google_maps_url'] ?? '').toString(),
      photoUrl: (json['photo_url'] ?? '').toString(),
      photoAuthor: (json['photo_author'] ?? '').toString(),
    );
  }

  /// Unisce i dettagli scaricati ai dati base gia mostrati sulla mappa.
  PlaceCandidate mergeDetails(PlaceCandidate details) {
    return PlaceCandidate(
      id: id,
      name: details.name.isEmpty ? name : details.name,
      address: details.address.isEmpty ? address : details.address,
      latitude: details.latitude != 0 ? details.latitude : latitude,
      longitude: details.longitude != 0 ? details.longitude : longitude,
      primaryType:
          details.primaryType.isEmpty ? primaryType : details.primaryType,
      phoneNumber: details.phoneNumber,
      rating: details.rating,
      ratingCount: details.ratingCount,
      priceLevel: details.priceLevel,
      openNow: details.openNow,
      openingHours: details.openingHours,
      googleMapsUrl: details.googleMapsUrl,
      photoUrl: details.photoUrl,
      photoAuthor: details.photoAuthor,
      detailsLoaded: true,
    );
  }
}
