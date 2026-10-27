import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prescription_record.dart';

/// Keeps scanned prescriptions on this device only (nothing is uploaded).
class PrescriptionHistoryService extends ChangeNotifier {
  PrescriptionHistoryService._internal();

  static final PrescriptionHistoryService _instance = PrescriptionHistoryService._internal();

  factory PrescriptionHistoryService() => _instance;

  static const String _storageKey = 'pharmalens_prescription_history_v1';
  static const int maxRecords = 50;

  List<PrescriptionRecord> _records = <PrescriptionRecord>[];
  bool _loaded = false;

  List<PrescriptionRecord> get records => List<PrescriptionRecord>.unmodifiable(_records);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _records = decoded
              .whereType<Map>()
              .map((m) => PrescriptionRecord.fromJson(Map<String, dynamic>.from(m)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      }
    } catch (error) {
      debugPrint('PrescriptionHistoryService: could not load history: $error');
    }

    _loaded = true;
    notifyListeners();
  }

  /// Saves a scan. [imageBytes] is copied into app storage so the photo
  /// survives the image picker's temporary file being cleaned up.
  Future<PrescriptionRecord> add({
    required List<PrescriptionMedicineEntry> medicines,
    String doctorName = '',
    String specialty = '',
    Uint8List? imageBytes,
  }) async {
    await load();

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final imagePath = imageBytes == null ? '' : await _saveImage(id, imageBytes);

    final record = PrescriptionRecord(
      id: id,
      createdAt: DateTime.now(),
      doctorName: doctorName,
      specialty: specialty,
      imagePath: imagePath,
      medicines: medicines,
    );

    _records = <PrescriptionRecord>[record, ..._records];

    while (_records.length > maxRecords) {
      await _deleteImage(_records.removeLast());
    }

    await _persist();
    notifyListeners();
    return record;
  }

  /// Replaces the medicines of a saved record, e.g. after the user picks
  /// the exact product for a line that could not be verified automatically.
  Future<void> updateMedicines(String id, List<PrescriptionMedicineEntry> medicines) async {
    await load();

    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;

    final old = _records[index];
    _records[index] = PrescriptionRecord(
      id: old.id,
      createdAt: old.createdAt,
      doctorName: old.doctorName,
      specialty: old.specialty,
      imagePath: old.imagePath,
      medicines: medicines,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await load();

    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;

    final removed = _records.removeAt(index);
    await _deleteImage(removed);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await load();

    for (final record in _records) {
      await _deleteImage(record);
    }
    _records = <PrescriptionRecord>[];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_records.map((r) => r.toJson()).toList()));
    } catch (error) {
      debugPrint('PrescriptionHistoryService: could not save history: $error');
    }
  }

  Future<String> _saveImage(String id, Uint8List bytes) async {
    if (kIsWeb || bytes.isEmpty) return '';

    try {
      final directory = await getApplicationSupportDirectory();
      final folder = Directory('${directory.path}${Platform.pathSeparator}prescriptions');
      if (!folder.existsSync()) {
        await folder.create(recursive: true);
      }
      final file = File('${folder.path}${Platform.pathSeparator}$id.img');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (error) {
      debugPrint('PrescriptionHistoryService: could not save image: $error');
      return '';
    }
  }

  Future<void> _deleteImage(PrescriptionRecord record) async {
    if (kIsWeb || record.imagePath.isEmpty) return;

    try {
      final file = File(record.imagePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
