
// Alternatives (with equivalent prices), official registry, sources and actions.
part of '../medicine_details_screen.dart';

/// Other MOPH products with the same active ingredients, in one place:
/// "Same dose" (same strength and form, i.e. the same medicine at another
/// price) and "Other strengths & forms". Cheapest first, with the saving
/// against the opened product.
class _AlternativesSection extends StatelessWidget {
  const _AlternativesSection({
    required this.original,
    required this.alternatives,
    required this.hadError,
    required this.isArabic,
    required this.onMedicineTap,
  });

  final MedicinePrice original;
  final List<MedicinePrice> alternatives;
  final bool hadError;
  final bool isArabic;
  final ValueChanged<MedicinePrice> onMedicineTap;

  @override
  Widget build(BuildContext context) {
    final text = appText(isArabic);

    return _ExpandableCard(
      storageId: 'alternatives',
      icon: Icons.swap_horiz_rounded,
      title: text.alternatives(alternatives.length),
      color: PharmaLensColors.teal,
      initiallyExpanded: alternatives.isNotEmpty,
      child: hadError
          ? _MessageBox(text: text.alternativesAreTemporarilyUnavailableTryRefreshing)
          : alternatives.isEmpty
              ? _MessageBox(text: text.noVerifiedAlternativesWereFoundIn)
              : _AlternativesBody(
                  original: original,
                  alternatives: alternatives,
                  isArabic: isArabic,
                  onMedicineTap: onMedicineTap,
                ),
    );
  }
}

class _AlternativesBody extends StatefulWidget {
  const _AlternativesBody({
    required this.original,
    required this.alternatives,
    required this.isArabic,
    required this.onMedicineTap,
  });

  final MedicinePrice original;
  final List<MedicinePrice> alternatives;
  final bool isArabic;
  final ValueChanged<MedicinePrice> onMedicineTap;

  @override
  State<_AlternativesBody> createState() => _AlternativesBodyState();
}

class _AlternativesBodyState extends State<_AlternativesBody> {
  static const int _collapsedCount = 4;

  // Kept in the page's storage: the phone layout is a lazy list, which
  // rebuilds this card each time it scrolls back into view.
  bool? _sameDose;
  bool _showAll = false;

  late List<MedicinePrice> _same;
  late List<MedicinePrice> _other;

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(covariant _AlternativesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alternatives != widget.alternatives) _split();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storage = PageStorage.maybeOf(context);
    _sameDose ??= storage?.readState(context, identifier: _filterKey) as bool?;
    _showAll = storage?.readState(context, identifier: _showAllKey) as bool? ?? _showAll;
  }

  String get _filterKey => 'alternatives-filter-${widget.original.medicineId}';
  String get _showAllKey => 'alternatives-all-${widget.original.medicineId}';

  void _split() {
    _same = <MedicinePrice>[];
    _other = <MedicinePrice>[];
    for (final alternative in widget.alternatives) {
      (MedicineEquivalence.isEquivalent(widget.original, alternative) ? _same : _other).add(alternative);
    }
    _same.sort(MedicineEquivalence.comparePrice);
    _other.sort(MedicineEquivalence.comparePrice);
  }

  void _setFilter(bool sameDose) {
    setState(() {
      _sameDose = sameDose;
      _showAll = false;
    });
    PageStorage.maybeOf(context)
      ?..writeState(context, sameDose, identifier: _filterKey)
      ..writeState(context, false, identifier: _showAllKey);
  }

  void _expand() {
    setState(() => _showAll = true);
    PageStorage.maybeOf(context)?.writeState(context, true, identifier: _showAllKey);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(widget.isArabic);
    final original = widget.original;

    // Same dose first when there is one.
    final sameDose = _sameDose ?? _same.isNotEmpty;
    final list = sameDose ? _same : _other;
    final shown = _showAll ? list : list.take(_collapsedCount).toList();

    final cheapest = _same.isEmpty ? null : _same.first;
    final saving = cheapest == null ? null : MedicineEquivalence.savingPercent(original, cheapest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What the prices below are compared with.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.tealSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication_rounded, color: PharmaLensColors.teal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.yourMedicine,
                      style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [original.brandName, original.displayStrength].where(_usable).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (original.priceLbp != null)
                Text(
                  '${original.formattedPriceLbp} ${text.lbp}',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(text.sameDoseCount(_same.length)),
              selected: sameDose,
              onSelected: _same.isEmpty ? null : (_) => _setFilter(true),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: Text(text.otherStrengthsFormsCount(_other.length)),
              selected: !sameDose,
              onSelected: _other.isEmpty ? null : (_) => _setFilter(false),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sameDose && cheapest != null && saving != null && saving > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PharmaLensColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: PharmaLensColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.cheapestSameDoseSaves(cheapest.brandName, saving),
                    style: TextStyle(color: palette.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.35),
                  ),
                ),
              ],
            ),
          )
        else if (!sameDose)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              text.theseHaveTheSameIngredientBut,
              style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final alternative in shown)
                _AlternativeOption(
                  original: original,
                  medicine: alternative,
                  sameDose: sameDose,
                  isArabic: widget.isArabic,
                  onTap: () => widget.onMedicineTap(alternative),
                ),
            ],
          ),
        ),
        if (list.length > shown.length)
          TextButton.icon(
            onPressed: _expand,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(text.showAllCount(list.length)),
          ),
        const SizedBox(height: 4),
        Text(
          text.doNotSwitchBeforeAskingYour,
          style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }
}

/// One alternative: name and details, its price, and how that price
/// compares with the opened product.
class _AlternativeOption extends StatelessWidget {
  const _AlternativeOption({
    required this.original,
    required this.medicine,
    required this.sameDose,
    required this.isArabic,
    required this.onTap,
  });

  final MedicinePrice original;
  final MedicinePrice medicine;
  final bool sameDose;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);

    final details = <String>[medicine.displayGenericName, medicine.displayStrength, medicine.displayDosageForm]
        .where(_usable)
        .map((value) => value.trim())
        .toSet()
        .join(' • ');
    final pack = [medicine.displayPackSize, medicine.displayManufacturer].where(_usable).join(' · ');

    final saving = sameDose ? MedicineEquivalence.savingPercent(original, medicine) : null;
    final perUnit = MedicineEquivalence.unitPrice(medicine);
    final unit = MedicineEquivalence.packQuantity(medicine.packSize)?.$2;

    final differences = <(String, Color)>[
      if (!sameDose && _usable(original.displayStrength) && _usable(medicine.displayStrength) && !original.hasSameStrengthAs(medicine))
        (text.differentStrength, PharmaLensColors.warning),
      if (!sameDose && _usable(original.displayDosageForm) && _usable(medicine.displayDosageForm) && !original.hasSameDosageFormAs(medicine))
        (text.differentForm, PharmaLensColors.warning),
      if (_usable(original.displayRoute) && _usable(medicine.displayRoute) && !original.hasCompatibleRouteWith(medicine))
        (text.differentRoute, PharmaLensColors.danger),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: palette.tealSurface, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_medicineIcon(medicine.dosageForm), color: PharmaLensColors.teal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.brandName,
                        textDirection: _textDirectionFor(medicine.brandName),
                        style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          details,
                          textDirection: _textDirectionFor(details),
                          style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (pack.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          pack,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textMuted, fontSize: 11),
                        ),
                      ],
                      if (differences.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [for (final d in differences) _SmallBadge(text: d.$1, color: d.$2)],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      medicine.priceLbp == null ? '—' : medicine.formattedPriceLbp,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    Text(text.lbp, style: TextStyle(color: palette.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    if (perUnit != null && unit == 'unit')
                      Text(
                        text.lbpEach(formatCount(perUnit.round())),
                        style: TextStyle(color: palette.textMuted, fontSize: 10.5),
                      ),
                    if (saving != null && saving != 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (saving > 0 ? PharmaLensColors.success : palette.textMuted).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          saving > 0 ? text.savePercent(saving) : text.morePercent(-saving),
                          style: TextStyle(
                            color: saving > 0 ? PharmaLensColors.success : palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailsSection extends StatelessWidget {
  const _ProductDetailsSection({
    required this.medicine,
    required this.knowledge,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final MedicineKnowledge? knowledge;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    return _ExpandableCard(
      icon: Icons.inventory_2_outlined,
      title: appText(isArabic).productInformation,
      color: PharmaLensColors.info,
      child: Column(
        children: [
          _InfoRow(
            label: appText(isArabic).brand,
            value: medicine.brandName,
          ),
          _InfoRow(
            label: appText(isArabic).activeIngredient,
            value: _composition(
              medicine,
              knowledge,
            ),
          ),
          _InfoRow(
            label: appText(isArabic).manufacturer2,
            value: medicine.displayManufacturer,
          ),
          _InfoRow(
            label: appText(isArabic).pack,
            value: medicine.displayPackSize,
          ),
          _InfoRow(
            label: 'ATC',
            value: medicine.displayAtcCode,
          ),
          _InfoRow(
            label: appText(isArabic).registration,
            value: medicine.registrationNumber ?? '',
          ),
          _InfoRow(
            label: appText(isArabic).priceDate,
            value: medicine.formattedEffectiveDate,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({
    required this.medicine,
    required this.knowledge,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final MedicineKnowledge? knowledge;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final clinicalSource =
        knowledge?.displaySourceName.trim() ?? '';

    final reviewedDate =
        knowledge?.formattedReviewedDate.trim() ?? '';

    final reviewerName =
        knowledge?.reviewedBy.trim() ?? '';

    final reviewerRole =
        knowledge?.reviewedByRole.trim() ?? '';

    final reviewedBy = <String>[
      reviewerName,
      reviewerRole,
    ]
        .where(
          (value) => value.isNotEmpty,
    )
        .join(' • ');

    final rows = <_SourceValue>[
      _SourceValue(
        label: appText(isArabic).productPriceSource,
        value: medicine.sourceLabel,
      ),
      _SourceValue(
        label: appText(isArabic).priceDate,
        value: medicine.formattedEffectiveDate,
      ),
      _SourceValue(
        label: appText(isArabic).clinicalSource,
        value: clinicalSource,
      ),
      _SourceValue(
        label: appText(isArabic).lastReviewed,
        value: reviewedDate,
      ),
      _SourceValue(
        label: appText(isArabic).reviewedBy,
        value: reviewedBy,
      ),
    ].where(
          (row) => _usable(row.value),
    ).toList();

    return _ExpandableCard(
      icon: Icons.fact_check_outlined,
      title: appText(isArabic).sourcesReview,
      color: PharmaLensColors.teal,
      child: rows.isEmpty
          ? _MessageBox(
        text: appText(isArabic).noAdditionalSourceInformationIsCurrently,
      )
          : Column(
        children: [
          for (var index = 0;
          index < rows.length;
          index++)
            _InfoRow(
              label: rows[index].label,
              value: rows[index].value,
              showDivider:
              index < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _SourceValue {
  const _SourceValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

/// Read aloud and reminder shortcuts for the current medicine.
class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.medicine,
    required this.knowledge,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final MedicineKnowledge? knowledge;
  final bool isArabic;

  static String speechIdFor(MedicinePrice? medicine) => 'medicine:${medicine?.stableKey ?? ''}';

  String get _spokenText {
    final uses = knowledge?.localizedUses(isArabic: isArabic).trim() ?? '';
    final howToTake = knowledge?.localizedHowToTake(isArabic: isArabic).trim() ?? '';

    final parts = <String>[
      medicine.brandName,
      medicine.displayStrength,
      medicine.displayDosageForm,
      if (medicine.activeIngredients.isNotEmpty)
        appText(isArabic).activeIngredient2 + medicine.activeIngredients.join(', '),
      if (uses.isNotEmpty) appText(isArabic).usedFor + uses,
      if (howToTake.isNotEmpty) appText(isArabic).howToTakeIt + howToTake,
    ].where((part) => part.trim().isNotEmpty && part.trim() != '—');
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final speech = SpeechService();
    final id = speechIdFor(medicine);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ListenableBuilder(
          listenable: speech,
          builder: (context, _) {
            final active = speech.isActiveFor(id);
            final playing = active && speech.state == SpeechState.playing;
            final paused = active && speech.state == SpeechState.paused;

            final button = playing
                ? FilledButton.tonalIcon(
                    onPressed: () => speech.toggle(id, _spokenText, isArabic: isArabic),
                    icon: const Icon(Icons.pause_rounded),
                    label: Text(appText(isArabic).pause),
                  )
                : OutlinedButton.icon(
                    onPressed: () async {
                      final spoke = await speech.toggle(id, _spokenText, isArabic: isArabic);
                      if (!spoke && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              appText(isArabic).readAloudIsNotAvailableOn,
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(paused ? Icons.play_arrow_rounded : Icons.volume_up_rounded),
                    label: Text(
                      paused ? appText(isArabic).resume : appText(isArabic).readAloud,
                    ),
                  );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button,
                if (active) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: speech.stop,
                    tooltip: appText(isArabic).stop,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                ],
              ],
            );
          },
        ),
        FilledButton.icon(
          onPressed: () => showReminderEditor(
            context,
            medicineName: medicine.brandName,
            medicineId: medicine.medicineId,
          ),
          icon: const Icon(Icons.alarm_add_rounded),
          label: Text(appText(isArabic).addReminder),
        ),
      ],
    );
  }
}

/// Says where the patient information below comes from, and whether AI wrote
/// it, so nobody mistakes it for an official leaflet.
class _InfoSourceNote extends StatelessWidget {
  const _InfoSourceNote({
    required this.info,
    required this.loading,
    required this.failed,
    required this.isArabic,
    required this.onRetry,
  });

  final MedicineInfo? info;
  final bool loading;
  final bool failed;
  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final info = this.info;

    late final IconData icon;
    late final Color color;
    late final String text;
    Widget? action;

    if (loading) {
      icon = Icons.downloading_rounded;
      color = PharmaLensColors.info;
      text = appText(isArabic).loadingMedicineInformationUsesSideEffects;
    } else if (info == null) {
      icon = failed ? Icons.cloud_off_rounded : Icons.info_outline_rounded;
      color = failed ? PharmaLensColors.warning : palette.textMuted;
      text = failed
          ? appText(isArabic).couldNotLoadTheMedicineInformation
          : appText(isArabic).noFurtherInformationIsAvailableFor;
      if (failed) {
        action = TextButton(onPressed: onRetry, child: Text(appText(isArabic).tryAgain));
      }
    } else {
      switch (info.origin) {
        case MedicineInfoOrigin.fdaLabelSummary:
          icon = Icons.auto_awesome_rounded;
          color = PharmaLensColors.info;
          text = appText(isArabic).aiSummaryOfTheUS(info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})');
        case MedicineInfoOrigin.fdaLabel:
          icon = Icons.description_outlined;
          color = PharmaLensColors.teal;
          text = appText(isArabic).fromTheUSFdaLabel(info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})');
        case MedicineInfoOrigin.aiGenerated:
          icon = Icons.auto_awesome_rounded;
          color = PharmaLensColors.warning;
          text = appText(isArabic).writtenByAiBecauseNoOfficial;
      }
      final url = Uri.tryParse(info.sourceUrl);
      if (url != null && info.sourceUrl.isNotEmpty) {
        action = TextButton(
          onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
          child: Text(appText(isArabic).openLabel),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: PharmaLensTheme.isDark(context) ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.textPrimary, fontSize: 12.3, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

class _InfoLoading extends StatelessWidget {
  const _InfoLoading({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            appText(isArabic).loading,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// What the official MOPH registry says: ingredients and WHO ATC group.
class _OfficialRegistrySection extends StatelessWidget {
  const _OfficialRegistrySection({
    required this.medicine,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final group = AtcGroups.describe(medicine.atcCode);
    final anatomical = AtcGroups.anatomicalGroup(medicine.atcCode);
    final moph = MophMedicineService();

    final rows = <(String, String)>[
      if (medicine.activeIngredients.isNotEmpty)
        (appText(isArabic).activeIngredients, medicine.activeIngredients.join('\n')),
      if (group != null)
        (
          appText(isArabic).therapeuticGroup,
          [
            group.localized(isArabic: isArabic),
            if (anatomical != null && anatomical.code != group.code) anatomical.localized(isArabic: isArabic),
          ].join(' · '),
        ),
      if ((medicine.atcCode ?? '').trim().isNotEmpty) ('ATC', medicine.atcCode!.trim()),
      if (medicine.formattedPriceLbp.isNotEmpty)
        (
          appText(isArabic).officialPrice,
          '${medicine.formattedPriceLbp} ${appText(isArabic).lbp}'
              '${moph.lastUpdatedDate.isEmpty ? '' : appText(isArabic).listOf(moph.lastUpdatedDate)}',
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            icon: Icons.verified_outlined,
            title: appText(isArabic).fromTheMophRegistry,
            subtitle: appText(isArabic).officialDataNotMedicalAdvice,
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(row.$1, style: TextStyle(color: palette.textMuted, fontSize: 12)),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.$2,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (moph.isDataStale)
            Text(
              appText(isArabic).thisPriceMayBeOutOf,
              style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// Same ingredients, strength and form from other manufacturers, cheapest first.
