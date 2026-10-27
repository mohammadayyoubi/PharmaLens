import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's own allergy list, stored on this device only.
///
/// Entries are free text: an ingredient ("Amoxicillin") or a known class
/// ("Penicillin", "NSAID"); see MedicationSafetyService for how they match.
class HealthProfileService extends ChangeNotifier {
  HealthProfileService._internal();

  static final HealthProfileService _instance = HealthProfileService._internal();

  factory HealthProfileService() => _instance;

  static const String _allergiesKey = 'pharmalens_allergies_v1';

  List<String> _allergies = <String>[];
  bool _loaded = false;

  List<String> get allergies => List<String>.unmodifiable(_allergies);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _allergies = prefs.getStringList(_allergiesKey) ?? <String>[];
    } catch (error) {
      debugPrint('HealthProfileService: could not load allergies: $error');
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> addAllergy(String value) async {
    await load();

    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    if (_allergies.any((a) => a.toLowerCase() == cleaned.toLowerCase())) return;

    _allergies = <String>[..._allergies, cleaned];
    await _persist();
    notifyListeners();
  }

  Future<void> removeAllergy(String value) async {
    await load();

    _allergies = _allergies.where((a) => a != value).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_allergiesKey, _allergies);
    } catch (error) {
      debugPrint('HealthProfileService: could not save allergies: $error');
    }
  }
}
