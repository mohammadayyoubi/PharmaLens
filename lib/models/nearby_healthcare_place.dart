enum NearbyHealthcarePlaceKind { pharmacy, medicalCenter }

class NearbyHealthcarePlace {
  const NearbyHealthcarePlace({
    required this.id,
    required this.placeId,
    required this.name,
    required this.kind,
    required this.primaryType,
    required this.address,
    required this.phone,
    required this.googleMapsUri,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingCount,
    required this.openNow,
  });

  final String id;
  final String placeId;
  final String name;
  final NearbyHealthcarePlaceKind kind;
  final String primaryType;
  final String address;
  final String phone;
  final String googleMapsUri;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingCount;
  final bool? openNow;

  bool get hasValidLocation =>
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      latitude != 0 &&
      longitude != 0;

  bool get isPharmacy => kind == NearbyHealthcarePlaceKind.pharmacy;
}
