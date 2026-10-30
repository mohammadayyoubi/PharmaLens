import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_text.dart';
import '../models/medicine_reminder.dart';
import 'health_profile_service.dart';
import 'prescription_history_service.dart';
import 'reminder_service.dart';

/// A plain-text summary of one person's medicines for a doctor or an
/// emergency room: allergies, conditions, current medicines with doses, and
/// the latest scanned prescription.
class MedicationListService {
  const MedicationListService();

  String build({required bool isArabic}) {
    final profile = HealthProfileService().active;
    final reminders = ReminderService().reminders.where((r) => r.profileId == profile.id && r.enabled && !r.isExpired).toList();
    final latest = PrescriptionHistoryService().records.where((r) => r.profileId == profile.id).firstOrNull;
    String t(String en, String ar) => isArabic ? ar : en;
    final date = DateTime.now().toIso8601String().substring(0, 10);

    final out = StringBuffer()
      ..writeln('${t('Medicine list', 'لائحة الأدوية')}${profile.isOwner ? '' : ' – ${profile.name}'} ($date)')
      ..writeln();

    out.writeln(t('Allergies:', 'الحساسية:'));
    out.writeln(profile.allergies.isEmpty ? t('  None recorded', '  لا شيء مسجّل') : profile.allergies.map((a) => '  • $a').join('\n'));
    if (profile.conditions.isNotEmpty) {
      out
        ..writeln()
        ..writeln(t('Conditions:', 'الحالات الصحية:'))
        ..writeln(profile.conditions.map((c) => '  • ${c.label(isArabic: isArabic)}').join('\n'));
    }

    out
      ..writeln()
      ..writeln(t('Current medicines:', 'الأدوية الحالية:'));
    if (reminders.isEmpty) {
      out.writeln(t('  None recorded', '  لا شيء مسجّل'));
    } else {
      for (final reminder in reminders) {
        final times = reminder.times.map(MedicineReminder.formatTime).join(', ');
        out.writeln('  • ${reminder.medicineName} – $times${reminder.doseNote.isEmpty ? '' : ' – ${reminder.doseNote}'}');
      }
    }

    if (latest != null && latest.medicines.isNotEmpty) {
      out
        ..writeln()
        ..writeln('${t('Latest prescription', 'آخر وصفة')} '
            '(${latest.createdAt.toIso8601String().substring(0, 10)}${latest.doctorName.isEmpty ? '' : ', ${latest.doctorName}'}):');
      for (final entry in latest.medicines) {
        final details = [entry.strength, entry.instructions].where((s) => s.isNotEmpty).join(' – ');
        out.writeln('  • ${entry.displayName}${details.isEmpty ? '' : ' – $details'}${entry.verified ? '' : t(' (not verified)', ' (غير متحقق منه)')}');
      }
    }

    out
      ..writeln()
      ..writeln(t('Made with PharmaLens. Please verify with the patient.', 'أُعدّت بواسطة PharmaLens. يرجى التحقق مع المريض.'));
    return out.toString();
  }

  /// Opens the share sheet; falls back to the clipboard where sharing is not
  /// available. Returns true when shared, false when copied.
  Future<bool> share({required bool isArabic}) async {
    final text = build(isArabic: isArabic);
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: appText(isArabic).medicineList));
      return true;
    } catch (error) {
      debugPrint('MedicationListService: share failed, copying instead: $error');
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }
}
