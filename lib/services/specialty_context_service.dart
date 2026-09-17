import '../models/doctor_context.dart';

class SpecialtyContextService {
  DoctorContext detectDoctorContext(String ocrText) {
    final text = _clean(ocrText);

    final doctorName = _extractDoctorName(ocrText);
    final specialty = _detectSpecialty(text);

    double confidence = 0;

    if (doctorName.isNotEmpty) {
      confidence += 0.35;
    }

    if (specialty.isNotEmpty) {
      confidence += 0.55;
    }

    if (confidence > 1) {
      confidence = 1;
    }

    return DoctorContext(
      detectedDoctorName: doctorName,
      detectedSpecialty: specialty,
      confidence: confidence,
    );
  }

  String _extractDoctorName(String originalText) {
    final lines = originalText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      final lower = line.toLowerCase();

      if (lower.startsWith('dr ') ||
          lower.startsWith('dr.') ||
          lower.contains('doctor')) {
        return line;
      }
    }

    return '';
  }

  String _detectSpecialty(String text) {
    final specialties = <String, List<String>>{
      'gastroenterology': [
        'gastro',
        'gastroenterology',
        'stomach',
        'digestive',
        'hepatology',
        'معدة',
        'جهاز هضمي',
        'هضمي',
      ],
      'pediatrics': [
        'pediatric',
        'pediatrics',
        'paediatric',
        'paediatrics',
        'child',
        'children',
        'اطفال',
        'أطفال',
        'طفل',
      ],
      'cardiology': ['cardio', 'cardiology', 'heart', 'قلب', 'قلبي'],
      'internal medicine': [
        'internal medicine',
        'inter medicine',
        'internal',
        'general medecine',
        'general medicine',
        'باطني',
        'داخلية',
      ],
      'general medicine': [
        'general medicine',
        'general medecine',
        'family medicine',
        'طب عام',
        'عام',
      ],
      'ent': [
        'ent',
        'ear nose throat',
        'orl',
        'اذن',
        'أذن',
        'انف',
        'أنف',
        'حنجرة',
      ],
      'dermatology': ['derma', 'dermatology', 'skin', 'جلدية', 'جلد'],
      'orthopedic': ['ortho', 'orthopedic', 'bones', 'عظام', 'مفاصل'],
      'endocrinology': [
        'endocrine',
        'endocrinology',
        'diabetes',
        'سكري',
        'غدد',
      ],
      'nephrology': ['nephro', 'nephrology', 'kidney', 'renal', 'كلى', 'كلية'],
    };

    for (final entry in specialties.entries) {
      for (final keyword in entry.value) {
        if (text.contains(_clean(keyword))) {
          return entry.key;
        }
      }
    }

    return '';
  }

  String _clean(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
