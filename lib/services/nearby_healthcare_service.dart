import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/nearby_healthcare_place.dart';
import '../private/google_maps_private_config.dart';

enum NearbyHealthcareErrorCode {
  invalidLocation,
  configuration,
  timeout,
  rateLimited,
  unavailable,
  invalidResponse,
  unexpected,
}

class NearbyHealthcareException implements Exception {
  const NearbyHealthcareException({
    required this.code,
    required this.message,
    this.retryable = true,
  });

  final NearbyHealthcareErrorCode code;

  /// Safe UI message.
  final String message;

  final bool retryable;

  @override
  String toString() {
    return message;
  }
}

class NearbyHealthcareService {
  NearbyHealthcareService({
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration cacheLifetime = const Duration(minutes: 5),
  }) : _httpClient = httpClient ?? http.Client(),
       _requestTimeout = requestTimeout,
       _cacheLifetime = cacheLifetime;

  static const String _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';

  final http.Client _httpClient;

  final Duration _requestTimeout;
  final Duration _cacheLifetime;

  List<NearbyHealthcarePlace>? _cachedPlaces;

  DateTime? _cachedAt;

  String _cachedLocationKey = '';

  Future<List<NearbyHealthcarePlace>> loadNearby({
    required double latitude,
    required double longitude,
    required String languageCode,
    double radiusMeters = 5000,
    int maxResults = 8,
    bool forceRefresh = false,
  }) async {
    _validateCoordinates(latitude, longitude);

    if (!GoogleMapsPrivateConfig.hasValidPlacesApiKey) {
      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.configuration,
        message: 'Nearby healthcare search is not configured.',
        retryable: false,
      );
    }

    final safeRadius = radiusMeters.clamp(500, 10000).toDouble();

    final safeMaxResults = maxResults.clamp(1, 20).toInt();

    final safeLanguageCode = languageCode.trim().toLowerCase() == 'ar'
        ? 'ar'
        : 'en';

    final cacheKey = <String>[
      latitude.toStringAsFixed(3),
      longitude.toStringAsFixed(3),
      safeRadius.round().toString(),
      safeMaxResults.toString(),
      safeLanguageCode,
    ].join('|');

    if (!forceRefresh) {
      final cached = _readCache(cacheKey);

      if (cached != null) {
        return cached;
      }
    }

    http.Response response;

    try {
      response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': GoogleMapsPrivateConfig.googlePlacesApiKey,
              'X-Goog-FieldMask': <String>[
                'places.id',
                'places.displayName',
                'places.primaryType',
                'places.types',
                'places.formattedAddress',
                'places.location',
                'places.internationalPhoneNumber',
                'places.nationalPhoneNumber',
                'places.googleMapsUri',
                'places.currentOpeningHours.openNow',
                'places.businessStatus',
                'places.rating',
                'places.userRatingCount',
              ].join(','),
            },
            body: jsonEncode(<String, dynamic>{
              'includedTypes': <String>[
                'pharmacy',
              ],

              'maxResultCount': safeMaxResults,

              'rankPreference': 'DISTANCE',

              'languageCode': safeLanguageCode,

              'regionCode': 'LB',

              'locationRestriction': <String, dynamic>{
                'circle': <String, dynamic>{
                  'center': <String, dynamic>{
                    'latitude': latitude,
                    'longitude': longitude,
                  },
                  'radius': safeRadius,
                },
              },
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _debugLog('Nearby healthcare request timed out.', error, stackTrace);

      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.timeout,
        message: 'Nearby healthcare search took too long. Please try again.',
      );
    } on http.ClientException catch (error, stackTrace) {
      _debugLog('Nearby healthcare network request failed.', error, stackTrace);

      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.unavailable,
        message: 'Nearby healthcare search is temporarily unavailable.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _debugProviderError(response);

      throw _httpException(response.statusCode);
    }

    final places = _parsePlaces(response.body);

    final immutable = List<NearbyHealthcarePlace>.unmodifiable(places);

    _cachedPlaces = immutable;

    _cachedAt = DateTime.now();

    _cachedLocationKey = cacheKey;

    return immutable;
  }

  List<NearbyHealthcarePlace> _parsePlaces(String body) {
    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (error, stackTrace) {
      _debugLog('Google Places response JSON was invalid.', error, stackTrace);

      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.invalidResponse,
        message: 'Nearby healthcare results could not be processed.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.invalidResponse,
        message: 'Nearby healthcare results could not be processed.',
      );
    }

    final rawPlaces = decoded['places'];

    if (rawPlaces == null) {
      return const <NearbyHealthcarePlace>[];
    }

    if (rawPlaces is! List) {
      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.invalidResponse,
        message: 'Nearby healthcare results could not be processed.',
      );
    }

    final result = <NearbyHealthcarePlace>[];

    final seen = <String>{};

    for (final rawPlace in rawPlaces) {
      if (rawPlace is! Map) {
        continue;
      }

      try {
        final place = _parsePlace(Map<String, dynamic>.from(rawPlace));

        if (place == null || !place.hasValidLocation) {
          continue;
        }

        if (!seen.add(place.id)) {
          continue;
        }

        result.add(place);
      } catch (error, stackTrace) {
        /*
         * One malformed Google place must not break
         * all other nearby locations.
         */
        _debugLog('Nearby healthcare place parsing failed.', error, stackTrace);
      }
    }

    return result;
  }

  NearbyHealthcarePlace? _parsePlace(Map<String, dynamic> json) {
    final businessStatus =
        json['businessStatus']?.toString().trim().toUpperCase() ?? '';

    if (businessStatus == 'CLOSED_PERMANENTLY') {
      return null;
    }

    final rawLocation = json['location'];

    if (rawLocation is! Map) {
      return null;
    }

    final location = Map<String, dynamic>.from(rawLocation);

    final latitude = _toDouble(location['latitude']);

    final longitude = _toDouble(location['longitude']);

    if (!_coordinatesAreValid(latitude, longitude)) {
      return null;
    }

    final rawDisplayName = json['displayName'];

    var name = '';

    if (rawDisplayName is Map) {
      name = rawDisplayName['text']?.toString().trim() ?? '';
    }

    if (name.isEmpty) {
      name = 'Healthcare location';
    }

    final primaryType =
        json['primaryType']?.toString().trim().toLowerCase() ?? '';

    final types = <String>{};

    final rawTypes = json['types'];

    if (rawTypes is List) {
      for (final item in rawTypes) {
        final value = item.toString().trim().toLowerCase();

        if (value.isNotEmpty) {
          types.add(value);
        }
      }
    }

    final isPharmacy = primaryType == 'pharmacy' || types.contains('pharmacy');
    if (!isPharmacy) {
      return null;
    }

    const kind = NearbyHealthcarePlaceKind.pharmacy;

    final placeId = json['id']?.toString().trim() ?? '';

    final id = placeId.isNotEmpty
        ? placeId
        : '${latitude.toStringAsFixed(6)}_'
              '${longitude.toStringAsFixed(6)}';

    bool? openNow;

    final rawOpeningHours = json['currentOpeningHours'];

    if (rawOpeningHours is Map) {
      final value = rawOpeningHours['openNow'];

      if (value is bool) {
        openNow = value;
      }
    }

    return NearbyHealthcarePlace(
      id: id,
      placeId: placeId,
      name: name,
      kind: kind,
      primaryType: primaryType,
      address: json['formattedAddress']?.toString().trim() ?? '',
      phone: _firstNonEmpty(<dynamic>[
        json['internationalPhoneNumber'],
        json['nationalPhoneNumber'],
      ]),
      googleMapsUri: json['googleMapsUri']?.toString().trim() ?? '',
      latitude: latitude,
      longitude: longitude,
      rating: _toDouble(json['rating']),
      userRatingCount: _toInt(json['userRatingCount']),
      openNow: openNow,
    );
  }

  NearbyHealthcareException _httpException(int statusCode) {
    switch (statusCode) {
      case 400:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.unavailable,
          message: 'Nearby healthcare search could not process this request.',
        );

      case 401:
      case 403:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.configuration,
          message: 'Nearby healthcare search is temporarily unavailable.',
          retryable: false,
        );

      case 408:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.timeout,
          message: 'Nearby healthcare search took too long. Please try again.',
        );

      case 429:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.rateLimited,
          message:
              'Nearby healthcare search is busy. Please try again shortly.',
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.unavailable,
          message: 'Nearby healthcare search is temporarily unavailable.',
        );

      default:
        return const NearbyHealthcareException(
          code: NearbyHealthcareErrorCode.unexpected,
          message: 'Nearby healthcare search is temporarily unavailable.',
        );
    }
  }

  void _validateCoordinates(double latitude, double longitude) {
    if (!_coordinatesAreValid(latitude, longitude)) {
      throw const NearbyHealthcareException(
        code: NearbyHealthcareErrorCode.invalidLocation,
        message:
            'A valid location is required to find nearby healthcare services.',
        retryable: false,
      );
    }
  }

  bool _coordinatesAreValid(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  List<NearbyHealthcarePlace>? _readCache(String cacheKey) {
    final cached = _cachedPlaces;

    final cachedAt = _cachedAt;

    if (cached == null || cachedAt == null || _cachedLocationKey != cacheKey) {
      return null;
    }

    if (DateTime.now().difference(cachedAt) >= _cacheLifetime) {
      clearCache();

      return null;
    }

    return cached;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  void clearCache() {
    _cachedPlaces = null;

    _cachedAt = null;

    _cachedLocationKey = '';
  }

  void dispose() {
    _httpClient.close();
  }

  void _debugProviderError(http.Response response) {
    if (!kDebugMode) {
      return;
    }

    final body = response.body.length > 500
        ? '${response.body.substring(0, 500)}…'
        : response.body;

    debugPrint(
      'Google Places request failed. '
      'HTTP ${response.statusCode}.',
    );

    debugPrint(body);
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('$message\n$error');

    debugPrintStack(stackTrace: stackTrace);
  }
}
