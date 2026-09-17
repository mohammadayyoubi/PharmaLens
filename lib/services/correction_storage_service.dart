import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/correction_record.dart';

class CorrectionStorageService {
  static const String _fileName = 'pharmalens_corrections.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<CorrectionRecord>> getCorrections() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(content);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .map(
            (item) =>
                CorrectionRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCorrection(CorrectionRecord record) async {
    final file = await _getFile();
    final corrections = await getCorrections();

    corrections.add(record);

    final encoded = jsonEncode(
      corrections.map((correction) => correction.toJson()).toList(),
    );

    await file.writeAsString(encoded);
  }
}
