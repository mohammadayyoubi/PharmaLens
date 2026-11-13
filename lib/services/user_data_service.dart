import 'package:flutter/foundation.dart';

import 'chatbot_service.dart';
import 'dose_log_service.dart';
import 'health_profile_service.dart';
import 'medicine_info_service.dart';
import 'prescription_history_service.dart';
import 'reminder_service.dart';

/// "Delete all my data" (Settings): everything personal the app keeps on
/// the phone. Settings such as language, theme and alarm sound, and the
/// public MOPH price list, stay.
///
/// Nothing personal is stored anywhere else: the app has no server or
/// account (see the privacy policy).
Future<void> deleteAllUserData() async {
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      debugPrint('deleteAllUserData: $name failed: $error');
    }
  }

  await step('reminders', ReminderService().clearAll);
  await step('dose log', DoseLogService().clear);
  await step('prescriptions', PrescriptionHistoryService().clear);
  await step('profiles', HealthProfileService().reset);
  await step('medicine pages', MedicineInfoService().clearCache);
  await step('assistant', () async => ChatbotService().clearHistory());
}
