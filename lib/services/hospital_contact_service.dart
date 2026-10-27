import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../private/google_maps_private_config.dart';

/// Public contact details of a hospital, from Google Places.
class HospitalContact {
  const HospitalContact({
    required this.name,
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.mapsUrl = '',
  });

  final String name;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String mapsUrl;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'maps_url': mapsUrl,
      };

  factory HospitalContact.fromJson(Map<String, dynamic> json) => HospitalContact(
        name: '${json['name'] ?? ''}',
        address: '${json['address'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        mapsUrl: '${json['maps_url'] ?? ''}',
      );
}

/// Looks up the phone number and location of the hospital a doctor works at.
///
/// The Lebanese Order of Physicians list gives no doctor phone numbers or
/// addresses, but 37% of doctors list a hospital. Hospital switchboards are
/// public, so calling the hospital is the reliable way to reach the doctor.
/// Results are cached on the device for 30 days.
class HospitalContactService {
  HospitalContactService._internal();

  static final HospitalContactService _instance = HospitalContactService._internal();

  factory HospitalContactService() => _instance;

  static const String _endpoint = 'https://places.googleapis.com/v1/places:searchText';
  static const String _cachePrefix = 'hospital_contact_v1:';
  static const Duration _cacheLifetime = Duration(days: 30);

  final Map<String, Future<HospitalContact?>> _inFlight = <String, Future<HospitalContact?>>{};

  bool get isConfigured => GoogleMapsPrivateConfig.hasValidPlacesApiKey;

  Future<HospitalContact?> find(String hospitalName, {required String languageCode}) {
    final name = hospitalName.trim();
    if (name.isEmpty || !isConfigured) return Future<HospitalContact?>.value(null);

    final key = '$_cachePrefix${languageCode == 'ar' ? 'ar' : 'en'}:${name.toLowerCase()}';
    return _inFlight.putIfAbsent(key, () => _load(key, name, languageCode).whenComplete(() => _inFlight.remove(key)));
  }

  Future<HospitalContact?> _load(String cacheKey, String name, String languageCode) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final savedAt = DateTime.tryParse('${decoded['saved_at'] ?? ''}');
        if (savedAt != null && DateTime.now().difference(savedAt) < _cacheLifetime) {
          final contact = decoded['contact'];
          return contact is Map ? HospitalContact.fromJson(Map<String, dynamic>.from(contact)) : null;
        }
      }
    } catch (_) {}

    try {
      final query = RegExp(r'hospital|medical center|مستشفى', caseSensitive: false).hasMatch(name)
          ? '$name, Lebanon'
          : '$name Hospital, Lebanon';

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': GoogleMapsPrivateConfig.googlePlacesApiKey,
              'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location,'
                  'places.nationalPhoneNumber,places.internationalPhoneNumber,places.googleMapsUri,places.types',
            },
            body: jsonEncode(<String, dynamic>{
              'textQuery': query,
              'languageCode': languageCode == 'ar' ? 'ar' : 'en',
              'regionCode': 'LB',
              'includedType': 'hospital',
              'pageSize': 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('HospitalContactService: HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final places = decoded is Map ? decoded['places'] : null;
      HospitalContact? contact;

      if (places is List && places.isNotEmpty && places.first is Map) {
        final place = Map<String, dynamic>.from(places.first as Map);
        final location = place['location'] is Map ? Map<String, dynamic>.from(place['location'] as Map) : null;
        final displayName = place['displayName'] is Map ? '${(place['displayName'] as Map)['text'] ?? ''}' : '';

        contact = HospitalContact(
          name: displayName.isNotEmpty ? displayName : name,
          address: '${place['formattedAddress'] ?? ''}',
          phone: '${place['internationalPhoneNumber'] ?? place['nationalPhoneNumber'] ?? ''}',
          latitude: (location?['latitude'] as num?)?.toDouble(),
          longitude: (location?['longitude'] as num?)?.toDouble(),
          mapsUrl: '${place['googleMapsUri'] ?? ''}',
        );
      }

      await prefs?.setString(
        cacheKey,
        jsonEncode(<String, dynamic>{'saved_at': DateTime.now().toIso8601String(), 'contact': contact?.toJson()}),
      );
      return contact;
    } catch (error) {
      debugPrint('HospitalContactService: lookup failed: $error');
      return null;
    }
  }
}
