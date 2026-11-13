import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/prescription_record.dart';
import 'package:pharmalens/screens/privacy_policy_screen.dart';
import 'package:pharmalens/services/android_app_identity.dart';
import 'package:pharmalens/services/dose_log_service.dart';
import 'package:pharmalens/services/health_profile_service.dart';
import 'package:pharmalens/services/prescription_history_service.dart';
import 'package:pharmalens/services/reminder_service.dart';
import 'package:pharmalens/services/user_data_service.dart';
import 'package:pharmalens/widgets/report_answer_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_screens_test.dart' show setSize, wrap;

/// What Google Play needs from the app: a privacy policy, a way to report
/// AI answers, and a way for users to delete their data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('the privacy policy exists in both languages and names every service the app uses', () async {
    for (final lang in <String>['en', 'ar']) {
      final text = await rootBundle.loadString('assets/legal/privacy_policy_$lang.md');
      for (final service in <String>['Gemini', 'Places', 'openFDA', 'OpenStreetMap', 'GitHub', 'TechWrap LB', 'moph.gov.lb']) {
        expect(text, contains(service), reason: '$service missing from the $lang policy');
      }
    }
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('privacy policy screen renders in ${locale.languageCode}', (tester) async {
      await setSize(tester, const Size(360, 780));
      await tester.pumpWidget(wrap(const PrivacyPolicyScreen(), locale: locale));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining(locale.languageCode == 'ar' ? 'سياسة الخصوصية' : 'Privacy policy'), findsWidgets);
      expect(find.textContaining('TechWrap LB', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an AI answer can be reported with a reason', (tester) async {
    await setSize(tester, const Size(360, 780));
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showReportAnswerSheet(context, answer: 'Take 10 tablets.', isArabic: false),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Report an AI answer'), findsOneWidget);
    expect(find.text('Harmful or dangerous advice'), findsOneWidget);
    expect(find.text('Send report'), findsOneWidget);
    expect(find.textContaining('your question and health data are not'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Google API calls get no app headers where the app identity cannot be read', () async {
    expect(await AndroidAppIdentity.headers(), isEmpty);
  });

  test('"Delete all my data" removes profiles, prescriptions, reminders and the dose log', () async {
    final profiles = HealthProfileService();
    await profiles.load();
    await profiles.addAllergy('Penicillin');
    await profiles.toggleCondition(HealthCondition.asthma);
    await profiles.addProfile('Mom');
    await PrescriptionHistoryService().add(
      medicines: const <PrescriptionMedicineEntry>[PrescriptionMedicineEntry(writtenName: 'Panadol')],
    );
    await ReminderService().add(medicineName: 'Panadol', times: const <int>[480]);
    await DoseLogService().load();

    await deleteAllUserData();

    expect(profiles.profiles, hasLength(1));
    expect(profiles.active.isOwner, isTrue);
    expect(profiles.active.hasHealthInfo, isFalse);
    expect(PrescriptionHistoryService().records, isEmpty);
    expect(ReminderService().reminders, isEmpty);
    expect(DoseLogService().entries, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pharmalens_reminders_v1'), '[]');
    expect(prefs.getString('pharmalens_prescription_history_v1'), '[]');
  });
}
