import 'package:flutter/material.dart';

import '../models/medicine_price.dart';
import '../models/verified_medicine_result.dart';
import '../theme/pharmalens_theme.dart';

class VerifiedMedicineCard extends StatelessWidget {
  const VerifiedMedicineCard({
    super.key,
    required this.result,
    required this.isArabic,
    required this.onOpenDetails,
    required this.onReviewMatch,
  });

  final VerifiedMedicineResult result;
  final bool isArabic;

  final VoidCallback? onOpenDetails;
  final VoidCallback? onReviewMatch;

  String _t({
    required String en,
    required String ar,
  }) {
    return isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    if (result.wasSkipped) {
      return _buildSkippedCard(context);
    }

    if (result.failed) {
      return _buildFailureCard(context);
    }

    final medicine = result.candidate;

    if (result.isNotFound || medicine == null) {
      return _buildNotFoundCard(context);
    }

    return _buildCandidateCard(
      context,
      medicine,
    );
  }

  Widget _buildCandidateCard(
      BuildContext context,
      MedicinePrice medicine,
      ) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isDark = PharmaLensTheme.isDark(context);

    final verified =
        result.hasVerifiedPrescriptionMatch;

    final manual =
        result.isManualSelection;

    final possible =
        !verified && !manual;

    final Color accent = verified
        ? PharmaLensColors.teal
        : manual
        ? PharmaLensColors.info
        : PharmaLensColors.warning;

    final VoidCallback? action =
    verified || manual
        ? onOpenDetails
        : onReviewMatch;

    final title = possible
        ? _detectedMedicineName()
        : result.displayName;

    final subtitle = possible
        ? _possibleIdentityLine()
        : _confirmedIdentityLine(
      medicine,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        22,
      ),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(
          22,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: accent.withValues(
                alpha: isDark ? 0.32 : 0.16,
              ),
            ),
            boxShadow: palette.cardShadow,
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius:
                    BorderRadius.circular(
                      99,
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsetsDirectional.fromSTEB(
                  18,
                  15,
                  14,
                  15,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _MedicineVisual(
                          icon: _medicineIcon(
                            possible
                                ? result.suggestion.form
                                : medicine.dosageForm,
                          ),
                          color: possible
                              ? PharmaLensColors.warning
                              : PharmaLensColors.teal,
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                textDirection:
                                TextDirection.ltr,
                                maxLines: 2,
                                overflow:
                                TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                  palette.textPrimary,
                                  fontSize: 18,
                                  height: 1.15,
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                              if (subtitle
                                  .isNotEmpty) ...[
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  subtitle,
                                  textDirection:
                                  TextDirection.ltr,
                                  maxLines: 2,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette
                                        .textSecondary,
                                    fontSize: 12.2,
                                    height: 1.35,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(
                            width: 8,
                          ),
                          _ArrowButtonVisual(
                            color: accent,
                            isArabic: isArabic,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _StatusPill(
                          icon: verified
                              ? Icons
                              .verified_rounded
                              : manual
                              ? Icons
                              .touch_app_rounded
                              : Icons
                              .help_outline_rounded,
                          label: _statusLabel(),
                          color: accent,
                        ),
                        if (result
                            .hasMultipleCandidates &&
                            !verified)
                          _StatusPill(
                            icon:
                            Icons.layers_outlined,
                            label: _t(
                              en:
                              '${result.candidateCount} products',
                              ar:
                              '${result.candidateCount} منتجات',
                            ),
                            color:
                            PharmaLensColors.warning,
                          ),
                        if ((verified || manual) &&
                            medicine.hasPrice)
                          _StatusPill(
                            icon:
                            Icons.payments_outlined,
                            label:
                            medicine.formattedPrice,
                            color:
                            PharmaLensColors.teal,
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 11,
                    ),
                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha:
                          isDark ? 0.11 : 0.055,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            possible
                                ? Icons
                                .manage_search_rounded
                                : Icons
                                .inventory_2_outlined,
                            color: accent,
                            size: 18,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              _actionMessage(),
                              style: TextStyle(
                                color:
                                palette.textSecondary,
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundCard(
      BuildContext context,
      ) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isDark = PharmaLensTheme.isDark(context);

    const accent =
        PharmaLensColors.warning;

    final subtitle =
    _possibleIdentityLine();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        22,
      ),
      child: InkWell(
        onTap: onReviewMatch,
        borderRadius: BorderRadius.circular(
          22,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: accent.withValues(
                alpha: isDark ? 0.32 : 0.16,
              ),
            ),
            boxShadow: palette.cardShadow,
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius:
                    BorderRadius.circular(
                      99,
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsetsDirectional.fromSTEB(
                  18,
                  15,
                  14,
                  15,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MedicineVisual(
                          icon: _medicineIcon(
                            result.suggestion.form,
                          ),
                          color: accent,
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _detectedMedicineName(),
                                textDirection:
                                TextDirection.ltr,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                  palette.textPrimary,
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                subtitle.isNotEmpty
                                    ? subtitle
                                    : _t(
                                  en:
                                  'Medicine product not identified',
                                  ar:
                                  'لم يتم تحديد المنتج الدوائي',
                                ),
                                textDirection:
                                TextDirection.ltr,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette
                                      .textSecondary,
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onReviewMatch != null)
                          _ArrowButtonVisual(
                            color: accent,
                            isArabic: isArabic,
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    _StatusPill(
                      icon:
                      Icons.search_off_rounded,
                      label: _t(
                        en:
                        'No safe product match',
                        ar:
                        'لا توجد مطابقة آمنة',
                      ),
                      color: accent,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha:
                          isDark ? 0.11 : 0.055,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .manage_search_rounded,
                            color: accent,
                            size: 18,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              _t(
                                en:
                                'Tap to search the medicine database and choose the exact product.',
                                ar:
                                'اضغط للبحث في قاعدة الأدوية واختيار المنتج الدقيق.',
                              ),
                              style: TextStyle(
                                color:
                                palette.textSecondary,
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkippedCard(
      BuildContext context,
      ) {
    final category =
        result.suggestion.isCategoryOnly;

    return _StateMedicineCard(
      icon: category
          ? Icons.category_outlined
          : Icons.visibility_off_outlined,
      color: PharmaLensColors.warning,
      title: category
          ? _t(
        en: 'Medicine category only',
        ar: 'فئة دوائية فقط',
      )
          : _t(
        en: 'Unreadable medicine',
        ar: 'دواء غير مقروء',
      ),
      message: result.statusExplanation(
        isArabic: isArabic,
      ),
    );
  }

  Widget _buildFailureCard(
      BuildContext context,
      ) {
    return _StateMedicineCard(
      icon: Icons.cloud_off_outlined,
      color: PharmaLensColors.danger,
      title: _t(
        en:
        'Medicine verification unavailable',
        ar:
        'التحقق من الدواء غير متاح',
      ),
      message: result.statusExplanation(
        isArabic: isArabic,
      ),
    );
  }

  String _statusLabel() {
    if (result
        .hasVerifiedPrescriptionMatch) {
      return _t(
        en: 'Verified',
        ar: 'مؤكد',
      );
    }

    if (result.isManualSelection) {
      return _t(
        en: 'Product selected',
        ar: 'منتج مختار',
      );
    }

    if (result.hasMultipleCandidates) {
      return _t(
        en: 'Choose exact product',
        ar: 'اختر المنتج الدقيق',
      );
    }

    return _t(
      en: 'Possible match',
      ar: 'مطابقة محتملة',
    );
  }

  String _actionMessage() {
    if (result
        .hasVerifiedPrescriptionMatch) {
      return _t(
        en:
        'Tap to open price, composition and full medicine information.',
        ar:
        'اضغط لعرض السعر والتركيبة وكامل معلومات الدواء.',
      );
    }

    if (result.isManualSelection) {
      return _t(
        en:
        'Tap to open the selected product and its medicine information.',
        ar:
        'اضغط لفتح المنتج المختار ومعلوماته الدوائية.',
      );
    }

    if (result.hasMultipleCandidates) {
      return _t(
        en:
        'More than one product matches. Tap to choose the exact variant.',
        ar:
        'يوجد أكثر من منتج محتمل. اضغط لاختيار المنتج الدقيق.',
      );
    }

    return _t(
      en:
      'Tap to review and confirm the exact medicine product.',
      ar:
      'اضغط لمراجعة المنتج الدوائي الدقيق وتأكيده.',
    );
  }

  String _detectedMedicineName() {
    final values = <String>[
      result.suggestion.writtenFragment,
      result.suggestion.name,
      result.suggestion.displayTitle,
      result.suggestion.exactWrittenText,
    ];

    for (final raw in values) {
      final value = raw.trim();

      if (_usable(value)) {
        return value;
      }
    }

    return _t(
      en: 'Unknown medicine',
      ar: 'دواء غير معروف',
    );
  }

  String _possibleIdentityLine() {
    return _joinUnique(
      <String>[
        result.suggestion.strength,
        result.suggestion.form,
      ],
    );
  }

  String _confirmedIdentityLine(
      MedicinePrice medicine,
      ) {
    return _joinUnique(
      <String>[
        if (medicine.hasGenericName)
          medicine.displayGenericName,
        if (medicine.hasStrength)
          medicine.displayStrength,
        if (medicine.hasDosageForm)
          medicine.displayDosageForm,
      ],
    );
  }

  String _joinUnique(
      Iterable<String> values,
      ) {
    final output = <String>[];
    final seen = <String>{};

    for (final raw in values) {
      final value = raw.trim();

      if (!_usable(value)) {
        continue;
      }

      final normalized =
      value.toLowerCase();

      if (seen.add(normalized)) {
        output.add(value);
      }
    }

    return output.join(' • ');
  }

  bool _usable(
      String value,
      ) {
    final normalized =
    value.trim().toLowerCase();

    return normalized.isNotEmpty &&
        !const <String>{
          '-',
          '--',
          '—',
          'unknown',
          'unreadable',
          'none',
          'null',
          'n/a',
          'na',
        }.contains(normalized);
  }
}

class _MedicineVisual extends StatelessWidget {
  const _MedicineVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? 0.15 : 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 25,
      ),
    );
  }
}

class _ArrowButtonVisual
    extends StatelessWidget {
  const _ArrowButtonVisual({
    required this.color,
    required this.isArabic,
  });

  final Color color;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? 0.14 : 0.07,
        ),
        borderRadius:
        BorderRadius.circular(
          11,
        ),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        color: color,
        size: 22,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? 0.15 : 0.075,
        ),
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.7,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMedicineCard
    extends StatelessWidget {
  const _StateMedicineCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: color.withValues(
            alpha: isDark ? 0.32 : 0.16,
          ),
        ),
        boxShadow:
        palette.cardShadow,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _MedicineVisual(
            icon: icon,
            color: color,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color:
                    palette.textPrimary,
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  message,
                  maxLines: 3,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette
                        .textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _medicineIcon(
    String? dosageForm,
    ) {
  final form =
      dosageForm?.trim().toLowerCase() ?? '';

  if (form.contains('inject') ||
      form.contains('ampoule') ||
      form.contains('ampule') ||
      form.contains('vial')) {
    return Icons.vaccines_outlined;
  }

  if (form.contains('syrup') ||
      form.contains('solution') ||
      form.contains('suspension')) {
    return Icons.local_drink_outlined;
  }

  if (form.contains('drop')) {
    return Icons.water_drop_outlined;
  }

  if (form.contains('cream') ||
      form.contains('ointment') ||
      form.contains('gel')) {
    return Icons.sanitizer_outlined;
  }

  if (form.contains('spray') ||
      form.contains('inhal')) {
    return Icons.air_rounded;
  }

  return Icons.medication_outlined;
}