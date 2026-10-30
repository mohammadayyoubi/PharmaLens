import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../services/health_profile_service.dart';
import '../services/medication_safety_service.dart';
import '../services/moph_medicine_service.dart';
import '../theme/pharmalens_theme.dart';

/// "For you": the parts of a medicine's label that matter for the selected
/// person, i.e. their allergies, pregnancy or breastfeeding, a child, kidney
/// or liver disease, and their age, weight and BMI (My Health > Health).
/// Shows nothing when none apply.
///
/// It only points at what the label says and asks the user to check with a
/// doctor; it never decides a medicine is safe and never changes a dose.
class ForYouCard extends StatelessWidget {
  const ForYouCard({super.key, required this.medicine, required this.knowledge, required this.isArabic});

  final MedicinePrice medicine;
  final MedicineKnowledge? knowledge;
  final bool isArabic;

  static const Map<HealthCondition, List<String>> _keywords = {
    HealthCondition.pregnant: ['pregnan', 'حمل', 'الحامل'],
    HealthCondition.breastfeeding: ['breast', 'lactat', 'nursing', 'رضاع', 'المرضع'],
    HealthCondition.child: ['child', 'pediatric', 'paediatric', 'infant', 'under 12', 'أطفال', 'الطفل', 'رضع'],
    HealthCondition.kidney: ['kidney', 'renal', 'الكلى', 'كلوي'],
    HealthCondition.liver: ['liver', 'hepat', 'الكبد', 'كبدي'],
  };

  static const List<String> _teenWords = [
    'adolescent', 'under 18', 'below 18', 'younger than 18', 'المراهقين', 'دون 18', 'أقل من 18', 'تحت 18',
  ];
  static const List<String> _olderWords = [
    'elderly', 'older adult', 'older patient', 'geriatric', 'over 65', '65 years', 'المسنين', 'كبار السن', 'المسن',
  ];
  static const List<String> _weightDoseWords = [
    'mg/kg', 'mg / kg', 'per kg', 'body weight', 'kg of', 'by weight', 'ملغ/كغ', 'لكل كغ', 'لكل كيلو', 'وزن الجسم', 'حسب الوزن',
  ];
  static const List<String> _bmiWords = [
    'obes', 'overweight', 'underweight', 'weight gain', 'weight loss', 'body mass', 'bmi',
    'السمنة', 'البدانة', 'زيادة الوزن', 'نقص الوزن', 'فقدان الوزن', 'نقصان الوزن',
  ];

  static String? _quote(List<String> lines, List<String> words) =>
      lines.where((line) => words.any(line.toLowerCase().contains)).firstOrNull;

  static String _kg(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

  /// Age, weight and BMI notes. A label line is quoted when one mentions the
  /// group; otherwise only the clear-cut cases (65 and over, under 40 kg, a
  /// weight-loss medicine with a normal BMI) get a general note.
  List<(IconData, String, String)> _bodyItems(HealthProfile person, List<String> lines) {
    final text = appText(isArabic);
    final check = text.checkWithYourDoctorBeforeUsingIt;
    final items = <(IconData, String, String)>[];
    final age = person.age;
    final weight = person.weightKg;
    final bmi = person.bmi;

    if (age != null && age >= 12 && age < 18) {
      final quote = _quote(lines, _teenWords);
      if (quote != null) items.add((Icons.cake_outlined, text.ageYearsOld(age), '$quote\n$check'));
    } else if (age != null && age >= 65) {
      final quote = _quote(lines, _olderWords);
      items.add((Icons.elderly_rounded, text.ageYearsOld(age), quote == null ? text.peopleOver65OftenNeedALower : '$quote\n$check'));
    }

    if (weight != null) {
      final quote = _quote(lines, _weightDoseWords);
      if (quote != null) {
        items.add((Icons.monitor_weight_outlined, text.weightKgValue(_kg(weight)), '${text.theDoseDependsOnBodyWeight(_kg(weight))}\n$quote'));
      } else if (weight < 40 && (age == null || age >= 12)) {
        items.add((Icons.monitor_weight_outlined, text.weightKgValue(_kg(weight)), text.atThisWeightAdultDosesMay));
      }
    }

    if (bmi != null) {
      final title = text.bmiValue(bmi.toStringAsFixed(1), bmiCategory(bmi, isArabic: isArabic));
      final weightLossMedicine = (medicine.atcCode ?? '').toUpperCase().startsWith('A08');
      if (weightLossMedicine && bmi < 25) {
        items.add((Icons.speed_rounded, title, text.thisIsAWeightLossMedicine));
      } else if (bmi < 18.5 || bmi >= 30) {
        final quote = _quote(lines, _bmiWords);
        if (quote != null) items.add((Icons.speed_rounded, title, '$quote\n$check'));
      }
    }
    return items;
  }

  List<String> _lines() {
    final k = knowledge;
    if (k == null) return const <String>[];
    return <String>[
      ...(isArabic && k.seriousWarningsAr.isNotEmpty ? k.seriousWarningsAr : k.seriousWarningsEn),
      ...(isArabic && k.contraindicationsAr.isNotEmpty ? k.contraindicationsAr : k.contraindicationsEn),
      ...(isArabic && k.howToTakeAr.isNotEmpty ? k.howToTakeAr : k.howToTakeEn).split(RegExp(r'(?<=[.!؟?])\s+')),
    ].map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = HealthProfileService();

    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) {
        final palette = PharmaLensTheme.paletteOf(context);
        final person = profile.active;
        final items = <(IconData, String, String)>[];

        final alerts = const MedicationSafetyService().check(
          <MedicinePrice>[medicine],
          allergies: person.allergies,
          catalog: MophMedicineService().catalog,
        );
        for (final alert in alerts) {
          items.add((Icons.no_food_rounded, alert.title(isArabic: isArabic), alert.message(isArabic: isArabic)));
        }

        final lines = _lines();
        // Until the label information has loaded there is nothing to quote.
        // A child's age counts as the "child" condition.
        final age = person.age;
        final conditions = knowledge == null
            ? const <HealthCondition>{}
            : <HealthCondition>{...person.conditions, if (age != null && age < 12) HealthCondition.child};
        for (final condition in conditions) {
          final words = _keywords[condition]!;
          String? match;
          if (condition == HealthCondition.pregnant || condition == HealthCondition.breastfeeding) {
            final text = isArabic && (knowledge?.pregnancyWarningAr ?? '').isNotEmpty
                ? knowledge!.pregnancyWarningAr
                : knowledge?.pregnancyWarningEn ?? '';
            if (text.trim().isNotEmpty) match = text.trim();
          }
          match ??= lines.where((line) => words.any(line.toLowerCase().contains)).firstOrNull;

          items.add((
            Icons.monitor_heart_outlined,
            condition.label(isArabic: isArabic),
            match ??
                appText(isArabic).theLabelInformationHereSaysNothing,
          ));
        }

        items.addAll(_bodyItems(person, lines));

        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PharmaLensColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PharmaLensColors.warning.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, color: PharmaLensColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'لـ${person.displayName(isArabic: true)}'
                          : 'For ${person.isOwner ? 'you' : person.name}',
                      style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              for (final item in items) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$1, size: 18, color: palette.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(item.$3, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                appText(isArabic).basedOnTheHealthProfileSaved,
                style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}
