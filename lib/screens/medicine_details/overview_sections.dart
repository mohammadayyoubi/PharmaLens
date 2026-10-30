
// Hero, overview, uses, directions, side effects and safety cards.
part of '../medicine_details_screen.dart';

class _MedicineHero extends StatelessWidget {
  const _MedicineHero({
    required this.medicine,
    required this.result,
    required this.knowledge,
    required this.medicineType,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final VerifiedMedicineResult? result;
  final MedicineKnowledge? knowledge;
  final MedicineTypeInfo? medicineType;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final isDark =
    PharmaLensTheme.isDark(context);

    final title = _displayMedicineName(
      medicine,
      result,
    );

    final identity = _identityLine(
      medicine,
      result,
      knowledge,
    );

    final family = medicineType
        ?.localizedLabel(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: PharmaLensDecorations.heroCard(
        borderRadius: BorderRadius.circular(26),
        isDark: isDark,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -42,
            top: -55,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.045,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          PositionedDirectional(
            end: 24,
            bottom: -80,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.035,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius:
                      BorderRadius.circular(19),
                    ),
                    child: Icon(
                      _medicineIcon(
                        medicine.dosageForm,
                      ),
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          textDirection:
                          _textDirectionFor(title),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (identity.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            identity,
                            textDirection:
                            _textDirectionFor(identity),
                            style: TextStyle(
                              color:
                              Colors.white.withValues(
                                alpha: 0.78,
                              ),
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_usable(family))
                    _HeroBadge(
                      icon: Icons.category_outlined,
                      label: family,
                    ),

                  if (_usable(
                    medicine.formattedPrice,
                  ))
                    _HeroBadge(
                      icon: Icons.payments_outlined,
                      label: medicine.formattedPrice,
                    ),

                  if (result != null)
                    _HeroBadge(
                      icon: result!
                          .hasVerifiedPrescriptionMatch
                          ? Icons.verified_rounded
                          : Icons.touch_app_rounded,
                      label: result!
                          .hasVerifiedPrescriptionMatch
                          ? appText(isArabic).prescriptionMatch
                          : appText(isArabic).selectedProduct,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.medicine,
    required this.result,
    required this.knowledge,
    required this.medicineType,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final VerifiedMedicineResult? result;
  final MedicineKnowledge? knowledge;
  final MedicineTypeInfo? medicineType;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final resolvedFamily = medicineType
        ?.localizedLabel(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final therapeuticClass = knowledge
        ?.localizedTherapeuticClass(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final family = _usable(resolvedFamily)
        ? resolvedFamily
        : therapeuticClass;

    final composition = _composition(
      medicine,
      knowledge,
    );

    return _InfoCard(
      icon: Icons.science_outlined,
      title: appText(isArabic).medicineOverview,
      color: PharmaLensColors.teal,
      child: Column(
        children: [
          _InfoRow(
            label: appText(isArabic).drugFamily,
            value: family,
          ),
          _InfoRow(
            label: appText(isArabic).composition,
            value: composition,
          ),
          _InfoRow(
            label: appText(isArabic).strength,
            value: _strength(
              medicine,
              result,
              knowledge,
            ),
          ),
          _InfoRow(
            label: appText(isArabic).dosageForm,
            value: _dosageForm(
              medicine,
              result,
              knowledge,
            ),
          ),
          _InfoRow(
            label: appText(isArabic).route,
            value: _route(
              medicine,
              knowledge,
              isArabic: isArabic,
            ),
          ),
          _InfoRow(
            label: appText(isArabic).price,
            value: medicine.formattedPrice,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _UsesSection extends StatelessWidget {
  const _UsesSection({
    required this.knowledge,
    required this.hadError,
    required this.loading,
    required this.isArabic,
  });

  final MedicineKnowledge? knowledge;
  final bool hadError;
  final bool loading;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final uses = knowledge
        ?.localizedUses(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    return _ExpandableCard(
      icon: Icons.medical_services_outlined,
      title: appText(isArabic).whyIsThisMedicineUsed,
      color: PharmaLensColors.info,
      initiallyExpanded: true,
      child: loading && uses.isEmpty
          ? _InfoLoading(isArabic: isArabic)
          : _ReviewedText(
        value: uses,
        hadError: hadError,
        isArabic: isArabic,
        emptyEn:
        'Information on the uses of this medicine is not available yet. Ask your pharmacist.',
        emptyAr:
        'معلومات استعمالات هذا الدواء غير متوفرة بعد. اسأل الصيدلي.',
      ),
    );
  }
}

class _HowToUseSection extends StatelessWidget {
  const _HowToUseSection({
    required this.result,
    required this.knowledge,
    required this.hadError,
    required this.loading,
    required this.isArabic,
  });

  final VerifiedMedicineResult? result;
  final MedicineKnowledge? knowledge;
  final bool hadError;
  final bool loading;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final howToTake = knowledge
        ?.localizedHowToTake(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final food = knowledge
        ?.localizedFoodInstructions(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final prescriptionDirections =
        result?.prescriptionDirections.trim() ?? '';

    // Opened from a scanned prescription.
    final fromPrescription =
        result != null;

    final usual = <Widget>[
      if (howToTake.isNotEmpty)
        _TextBlock(
          title: fromPrescription
              ? appText(isArabic).howItIsUsuallyTaken
              : appText(isArabic).usualUse,
          text: howToTake,
        ),
      if (food.isNotEmpty) ...[
        if (howToTake.isNotEmpty)
          const SizedBox(height: 13),
        _TextBlock(
          title: appText(isArabic).foodInstructions,
          text: food,
        ),
      ],
    ];

    final children = <Widget>[
      if (prescriptionDirections.isNotEmpty)
        _PrescriptionBox(
          value: prescriptionDirections,
          isArabic: isArabic,
        )
      else if (fromPrescription)
        _MessageBox(
          warning: true,
          text: appText(isArabic).noDirectionsAreWrittenOnThe,
        ),
      if (usual.isNotEmpty) ...[
        if (fromPrescription)
          const SizedBox(height: 13),
        ...usual,
      ] else if (loading)
        Padding(
          padding: EdgeInsets.only(top: fromPrescription ? 13 : 0),
          child: _InfoLoading(isArabic: isArabic),
        )
      else if (!fromPrescription)
        _ReviewedText(
          value: '',
          hadError: hadError,
          isArabic: isArabic,
          emptyEn:
          "Directions are not available for this medicine yet. Follow your doctor's or pharmacist's directions.",
          emptyAr:
          'طريقة الاستعمال غير متوفرة لهذا الدواء بعد. اتبع تعليمات الطبيب أو الصيدلي.',
        ),
    ];

    return _ExpandableCard(
      icon: Icons.schedule_rounded,
      title: appText(isArabic).howToUse,
      color: PharmaLensColors.accentPurple,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SideEffectsSection extends StatelessWidget {
  const _SideEffectsSection({
    required this.knowledge,
    required this.hadError,
    required this.loading,
    required this.isArabic,
  });

  final MedicineKnowledge? knowledge;
  final bool hadError;
  final bool loading;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final common = knowledge
        ?.localizedCommonSideEffects(
      isArabic: isArabic,
    ) ??
        const <String>[];

    final serious = knowledge
        ?.localizedSeriousWarnings(
      isArabic: isArabic,
    ) ??
        const <String>[];

    return _ExpandableCard(
      icon: Icons.sick_outlined,
      title: appText(isArabic).sideEffects,
      color: PharmaLensColors.warning,
      child: loading && common.isEmpty && serious.isEmpty
          ? _InfoLoading(isArabic: isArabic)
          : common.isEmpty && serious.isEmpty
          ? _ReviewedText(
        value: '',
        hadError: hadError,
        isArabic: isArabic,
        emptyEn:
        'Side-effect information is not available for this medicine yet. Read the leaflet in the box.',
        emptyAr:
        'معلومات الأعراض الجانبية غير متوفرة لهذا الدواء بعد. اقرأ النشرة داخل العلبة.',
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (common.isNotEmpty)
            _BulletList(
              title: appText(isArabic).commonSideEffects2,
              values: common,
              color: PharmaLensColors.warning,
            ),

          if (serious.isNotEmpty) ...[
            if (common.isNotEmpty)
              const SizedBox(height: 15),
            _BulletList(
              title: appText(isArabic).seriousWarnings,
              values: serious,
              color: PharmaLensColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({
    required this.knowledge,
    required this.hadError,
    required this.loading,
    required this.isArabic,
  });

  final MedicineKnowledge? knowledge;
  final bool hadError;
  final bool loading;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final contraindications = knowledge
        ?.localizedContraindications(
      isArabic: isArabic,
    ) ??
        const <String>[];

    final interactions = knowledge
        ?.localizedInteractions(
      isArabic: isArabic,
    ) ??
        const <String>[];

    final pregnancy = knowledge
        ?.localizedPregnancyWarning(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final storage = knowledge
        ?.localizedStorage(
      isArabic: isArabic,
    )
        .trim() ??
        '';

    final hasAny = contraindications.isNotEmpty ||
        interactions.isNotEmpty ||
        pregnancy.isNotEmpty ||
        storage.isNotEmpty;

    return _ExpandableCard(
      icon: Icons.health_and_safety_outlined,
      title: appText(isArabic).warningsSafety,
      color: PharmaLensColors.danger,
      child: loading && !hasAny
          ? _InfoLoading(isArabic: isArabic)
          : !hasAny
          ? _ReviewedText(
        value: '',
        hadError: hadError,
        isArabic: isArabic,
        emptyEn:
        'Warning information is not available for this medicine yet. Ask your pharmacist.',
        emptyAr:
        'معلومات التحذيرات غير متوفرة لهذا الدواء بعد. اسأل الصيدلي.',
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (contraindications.isNotEmpty)
            _BulletList(
              title: appText(isArabic).contraindications,
              values: contraindications,
              color: PharmaLensColors.danger,
            ),

          if (interactions.isNotEmpty) ...[
            if (contraindications.isNotEmpty)
              const SizedBox(height: 15),
            _BulletList(
              title: appText(isArabic).interactions,
              values: interactions,
              color: PharmaLensColors.warning,
            ),
          ],

          if (pregnancy.isNotEmpty) ...[
            if (contraindications.isNotEmpty ||
                interactions.isNotEmpty)
              const SizedBox(height: 15),
            _TextBlock(
              title: appText(isArabic).pregnancyBreastfeeding,
              text: pregnancy,
            ),
          ],

          if (storage.isNotEmpty) ...[
            if (contraindications.isNotEmpty ||
                interactions.isNotEmpty ||
                pregnancy.isNotEmpty)
              const SizedBox(height: 15),
            _TextBlock(
              title: appText(isArabic).storage,
              text: storage,
            ),
          ],
        ],
      ),
    );
  }
}
