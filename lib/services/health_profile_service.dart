import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_text.dart';

/// Health situations that change what is safe to take. They are shown next
/// to the matching parts of a medicine's label; they never change doses.
enum HealthCondition { pregnant, breastfeeding, child, kidney, liver }

extension HealthConditionText on HealthCondition {
  String label({required bool isArabic}) {
    switch (this) {
      case HealthCondition.pregnant:
        return appText(isArabic).pregnant;
      case HealthCondition.breastfeeding:
        return appText(isArabic).breastfeeding;
      case HealthCondition.child:
        return appText(isArabic).childUnder12;
      case HealthCondition.kidney:
        return appText(isArabic).kidneyDisease;
      case HealthCondition.liver:
        return appText(isArabic).liverDisease;
    }
  }
}

enum BiologicalSex { female, male }

/// WHO adult categories: under 18.5, 18.5-24.9, 25-29.9, 30 and over.
String bmiCategory(double bmi, {required bool isArabic}) {
  final text = appText(isArabic);
  if (bmi < 18.5) return text.bmiUnderweight;
  if (bmi < 25) return text.bmiHealthy;
  if (bmi < 30) return text.bmiOverweight;
  return text.bmiObesity;
}

/// One person whose medicines are managed in the app (the user, a parent,
/// a child...).
class HealthProfile {
  const HealthProfile({
    required this.id,
    required this.name,
    this.allergies = const <String>[],
    this.conditions = const <HealthCondition>{},
    this.birthYear,
    this.sex,
    this.heightCm,
    this.weightKg,
  });

  /// "me" for the phone's owner.
  final String id;

  /// Empty for the owner ("Me").
  final String name;
  final List<String> allergies;
  final Set<HealthCondition> conditions;

  /// Entered as an age; the year is kept so the age stays right next year.
  final int? birthYear;
  final BiologicalSex? sex;
  final double? heightCm;
  final double? weightKg;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  /// Body mass index, when both height and weight are known.
  double? get bmi {
    final h = heightCm, w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  bool get hasBody => birthYear != null || sex != null || heightCm != null || weightKg != null;

  bool get isOwner => id == HealthProfileService.ownerId;

  String displayName({required bool isArabic}) => isOwner ? appText(isArabic).me : name;

  HealthProfile copyWith({String? name, List<String>? allergies, Set<HealthCondition>? conditions}) => HealthProfile(
        id: id,
        name: name ?? this.name,
        allergies: allergies ?? this.allergies,
        conditions: conditions ?? this.conditions,
        birthYear: birthYear,
        sex: sex,
        heightCm: heightCm,
        weightKg: weightKg,
      );

  /// Replaces all four body values; null clears one.
  HealthProfile withBody({int? birthYear, BiologicalSex? sex, double? heightCm, double? weightKg}) => HealthProfile(
        id: id,
        name: name,
        allergies: allergies,
        conditions: conditions,
        birthYear: birthYear,
        sex: sex,
        heightCm: heightCm,
        weightKg: weightKg,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'allergies': allergies,
        'conditions': conditions.map((c) => c.name).toList(),
        if (birthYear != null) 'birthYear': birthYear,
        if (sex != null) 'sex': sex!.name,
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
      };

  static HealthProfile? fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}';
    if (id.isEmpty) return null;
    return HealthProfile(
      id: id,
      name: '${json['name'] ?? ''}',
      allergies: json['allergies'] is List ? (json['allergies'] as List).map((e) => '$e').toList() : const <String>[],
      conditions: json['conditions'] is List
          ? (json['conditions'] as List)
              .map((e) => HealthCondition.values.where((c) => c.name == e).firstOrNull)
              .whereType<HealthCondition>()
              .toSet()
          : const <HealthCondition>{},
      birthYear: (json['birthYear'] as num?)?.toInt(),
      sex: BiologicalSex.values.where((s) => s.name == json['sex']).firstOrNull,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
    );
  }
}

/// The people managed in the app and each one's allergies and conditions,
/// stored on this device only. [allergies] and [conditions] are those of the
/// selected person ([active]).
///
/// Allergy entries are free text: an ingredient ("Amoxicillin") or a known
/// class ("Penicillin", "NSAID"); see MedicationSafetyService.
class HealthProfileService extends ChangeNotifier {
  HealthProfileService._internal();

  static final HealthProfileService _instance = HealthProfileService._internal();

  factory HealthProfileService() => _instance;

  static const String ownerId = 'me';
  static const String _profilesKey = 'pharmalens_profiles_v1';
  static const String _activeKey = 'pharmalens_active_profile_v1';

  /// Allergy list saved before profiles existed; moved into "me".
  static const String _legacyAllergiesKey = 'pharmalens_allergies_v1';

  List<HealthProfile> _profiles = const <HealthProfile>[HealthProfile(id: ownerId, name: '')];
  String _activeId = ownerId;
  bool _loaded = false;

  List<HealthProfile> get profiles => List<HealthProfile>.unmodifiable(_profiles);
  HealthProfile get active => _profiles.firstWhere((p) => p.id == _activeId, orElse: () => _profiles.first);
  HealthProfile? byId(String id) => _profiles.where((p) => p.id == id).firstOrNull;
  bool get hasFamily => _profiles.length > 1;

  List<String> get allergies => List<String>.unmodifiable(active.allergies);
  Set<HealthCondition> get conditions => Set<HealthCondition>.unmodifiable(active.conditions);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded.whereType<Map>().map((m) => HealthProfile.fromJson(Map<String, dynamic>.from(m))).whereType<HealthProfile>().toList();
          if (parsed.any((p) => p.id == ownerId)) _profiles = parsed;
        }
      } else {
        final legacy = prefs.getStringList(_legacyAllergiesKey) ?? <String>[];
        _profiles = <HealthProfile>[HealthProfile(id: ownerId, name: '', allergies: legacy)];
      }
      final active = prefs.getString(_activeKey) ?? ownerId;
      _activeId = _profiles.any((p) => p.id == active) ? active : ownerId;
    } catch (error) {
      debugPrint('HealthProfileService: could not load profiles: $error');
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    await load();
    if (!_profiles.any((p) => p.id == id) || id == _activeId) return;
    _activeId = id;
    await _persist();
    notifyListeners();
  }

  Future<HealthProfile> addProfile(String name) async {
    await load();
    final profile = HealthProfile(id: 'p${DateTime.now().millisecondsSinceEpoch}', name: name.trim());
    _profiles = <HealthProfile>[..._profiles, profile];
    _activeId = profile.id;
    await _persist();
    notifyListeners();
    return profile;
  }

  Future<void> renameProfile(String id, String name) => _update(id, (p) => p.copyWith(name: name.trim()));

  /// Removes a family member (never the owner).
  Future<void> removeProfile(String id) async {
    await load();
    if (id == ownerId) return;
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_activeId == id) _activeId = ownerId;
    await _persist();
    notifyListeners();
  }

  Future<void> addAllergy(String value) async {
    await load();

    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    if (active.allergies.any((a) => a.toLowerCase() == cleaned.toLowerCase())) return;

    await _update(_activeId, (p) => p.copyWith(allergies: <String>[...p.allergies, cleaned]));
  }

  Future<void> removeAllergy(String value) async {
    await load();
    await _update(_activeId, (p) => p.copyWith(allergies: p.allergies.where((a) => a != value).toList()));
  }

  Future<void> toggleCondition(HealthCondition condition) async {
    await load();
    await _update(_activeId, (p) {
      final next = Set<HealthCondition>.of(p.conditions);
      if (!next.remove(condition)) next.add(condition);
      return p.copyWith(conditions: next);
    });
  }

  /// Age, sex, height and weight of the selected person; medicine pages use
  /// them to point at label warnings (see ForYouCard).
  Future<void> setBody({int? age, BiologicalSex? sex, double? heightCm, double? weightKg}) async {
    await load();
    await _update(
      _activeId,
      (p) => p.withBody(
        birthYear: age == null ? null : DateTime.now().year - age,
        sex: sex,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );
  }

  Future<void> _update(String id, HealthProfile Function(HealthProfile) change) async {
    await load();
    _profiles = <HealthProfile>[for (final p in _profiles) p.id == id ? change(p) : p];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profilesKey, jsonEncode(_profiles.map((p) => p.toJson()).toList()));
      await prefs.setString(_activeKey, _activeId);
    } catch (error) {
      debugPrint('HealthProfileService: could not save profiles: $error');
    }
  }
}
