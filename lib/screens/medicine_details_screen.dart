import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../models/verified_medicine_result.dart';
import '../services/medicine_alternative_service.dart';
import '../services/medicine_info_service.dart';
import '../services/medicine_type_resolver.dart';
import '../theme/pharmalens_theme.dart';
import '../services/moph_medicine_service.dart';
import '../services/speech_service.dart';
import '../utils/atc_groups.dart';
import '../utils/formatters.dart';
import '../utils/medicine_equivalence.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/responsive.dart';

class MedicineDetailsScreen extends StatefulWidget {
  const MedicineDetailsScreen({
    super.key,
    this.result,
    this.medicine,
  }) : assert(
  result != null || medicine != null,
  'Either result or medicine must be provided.',
  );

  final VerifiedMedicineResult? result;
  final MedicinePrice? medicine;

  @override
  State<MedicineDetailsScreen> createState() =>
      _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends State<MedicineDetailsScreen> {
  final MedicineAlternativeService _alternativeService =
  MedicineAlternativeService();

  final MedicineTypeResolver _typeResolver =
  const MedicineTypeResolver();

  late Future<_MedicineDetailsData> _future;

  bool _isRefreshing = false;

  /// Patient information (uses, side effects...) loads on its own so the
  /// registry data shows straight away.
  MedicineInfo? _info;
  bool _infoLoading = false;
  bool _infoFailed = false;
  int _infoRequest = 0;

  VerifiedMedicineResult? get _result => widget.result;

  MedicinePrice? get _medicine =>
      widget.result?.candidate ?? widget.medicine;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _t({
    required String en,
    required String ar,
  }) {
    return _isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _loadInfo();
  }

  @override
  void dispose() {
    _infoRequest++;
    final speech = SpeechService();
    if (speech.ownerId == _DetailActions.speechIdFor(_medicine)) {
      speech.stop();
    }
    super.dispose();
  }

  Future<void> _loadInfo({
    bool forceRefresh = false,
  }) async {
    final medicine = _medicine;
    if (medicine == null) return;

    final request = ++_infoRequest;
    setState(() {
      _infoLoading = true;
      _infoFailed = false;
      if (forceRefresh) _info = null;
    });

    MedicineInfo? info;
    var failed = false;
    try {
      info = await MedicineInfoService().load(
        medicine,
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      failed = true;
    }

    if (!mounted || request != _infoRequest) return;
    setState(() {
      _info = info;
      _infoFailed = failed;
      _infoLoading = false;
    });
  }

  @override
  void didUpdateWidget(
      covariant MedicineDetailsScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    final oldMedicine =
        oldWidget.result?.candidate ?? oldWidget.medicine;

    final newMedicine =
        widget.result?.candidate ?? widget.medicine;

    final oldKey = oldMedicine?.stableKey.trim() ?? '';
    final newKey = newMedicine?.stableKey.trim() ?? '';

    if (oldKey != newKey) {
      _isRefreshing = false;
      _future = _loadData();
      _info = null;
      _loadInfo();
    }
  }

  Future<_MedicineDetailsData> _loadData({
    bool forceRefresh = false,
  }) async {
    final medicine = _medicine;

    if (medicine == null) {
      return const _MedicineDetailsData();
    }

    final knowledge =
    _safeAttachedKnowledge(medicine);

    Object? alternativesError;

    MedicineTypeInfo? medicineType;

    try {
      medicineType = _typeResolver.resolve(
        medicine: medicine,
        knowledge: knowledge,
      );
    } catch (error, stackTrace) {
      _debugLog(
        'Medicine type resolution failed.',
        error,
        stackTrace,
      );
    }

    List<MedicinePrice> alternatives = const <MedicinePrice>[];

    try {
      final loadedAlternatives =
      await _alternativeService.findAlternatives(
        medicine,
        knowledge: knowledge,
        limit: 24,
        forceRefresh: forceRefresh,
      );

      alternatives = _sanitizeAlternatives(
        original: medicine,
        alternatives: loadedAlternatives,
      );
    } catch (error, stackTrace) {
      alternativesError = error;

      _debugLog(
        'Medicine alternatives loading failed.',
        error,
        stackTrace,
      );
    }

    return _MedicineDetailsData(
      knowledge: knowledge,
      medicineType: medicineType,
      alternatives: List<MedicinePrice>.unmodifiable(
        alternatives,
      ),
      alternativesError: alternativesError,
    );
  }

  List<MedicinePrice> _sanitizeAlternatives({
    required MedicinePrice original,
    required List<MedicinePrice> alternatives,
  }) {
    if (alternatives.isEmpty) {
      return const <MedicinePrice>[];
    }

    final originalKey = _medicineIdentityKey(original);
    final seen = <String>{originalKey};

    final cleaned = <MedicinePrice>[];

    for (final alternative in alternatives) {
      final key = _medicineIdentityKey(alternative);

      if (key.isEmpty) {
        continue;
      }

      if (seen.contains(key)) {
        continue;
      }

      seen.add(key);
      cleaned.add(alternative);
    }

    return cleaned;
  }

  String _medicineIdentityKey(
      MedicinePrice medicine,
      ) {
    final stableKey = medicine.stableKey.trim().toLowerCase();

    if (stableKey.isNotEmpty) {
      return stableKey;
    }

    return <String>[
      medicine.medicineId,
      medicine.brandName,
      medicine.displayGenericName,
      medicine.displayStrength,
      medicine.displayDosageForm,
      medicine.displayManufacturer,
    ]
        .map(
          (value) => value.trim().toLowerCase(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .join('|');
  }

  MedicineKnowledge? _safeAttachedKnowledge(
      MedicinePrice medicine,
      ) {
    final knowledge = _result?.knowledge;

    if (knowledge == null) {
      return null;
    }

    if (!knowledge.canBeDisplayedAsReviewed) {
      return null;
    }

    final medicineId = _normalizeId(
      medicine.medicineId,
    );

    final knowledgeId = _normalizeId(
      knowledge.medicineId,
    );

    if (medicineId.isEmpty ||
        knowledgeId.isEmpty ||
        medicineId != knowledgeId) {
      return null;
    }

    return knowledge;
  }

  String _normalizeId(
      String value,
      ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    final future = _loadData(
      forceRefresh: true,
    );

    _loadInfo(
      forceRefresh: true,
    );

    setState(() {
      _isRefreshing = true;
      _future = future;
    });

    try {
      await future;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _openAlternative(
      MedicinePrice medicine,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineDetailsScreen(
          medicine: medicine,
        ),
      ),
    );
  }

  void _debugLog(
      String message,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '$message\n$error',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final medicine = _medicine;

    return Directionality(
      textDirection:
      _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: palette.background,
        floatingActionButton: const FloatingChatbotButton(),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: palette.pageGradient,
          ),
          child: SafeArea(
            child: medicine == null
                ? _buildMissingMedicine()
                : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1240,
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: FutureBuilder<_MedicineDetailsData>(
                        future: _future,
                        builder: (
                            context,
                            snapshot,
                            ) {
                          return _buildPage(
                            medicine: medicine,
                            snapshot: snapshot,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8,
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    en: 'Medicine information',
                    ar: 'معلومات الدواء',
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t(
                    en:
                    'Composition, uses, safety and alternatives',
                    ar:
                    'التركيبة والاستعمالات والتحذيرات والبدائل',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HeaderButton(
            icon: Icons.refresh_rounded,
            onTap: () {
              _refresh();
            },
            loading: _isRefreshing,
          ),
        ],
      ),
    );
  }

  Widget _buildPage({
    required MedicinePrice medicine,
    required AsyncSnapshot<_MedicineDetailsData> snapshot,
  }) {
    final data = snapshot.data;

    final attachedKnowledge =
    _safeAttachedKnowledge(medicine);

    final knowledge =
        _info?.knowledge ?? data?.knowledge ?? attachedKnowledge;

    MedicineTypeInfo? type =
        data?.medicineType;

    type ??= _safeResolveType(
      medicine: medicine,
      knowledge: knowledge,
    );

    final alternatives =
        data?.alternatives ?? const <MedicinePrice>[];

    final loading =
        snapshot.connectionState ==
            ConnectionState.waiting &&
            data == null;

    final hadKnowledgeError =
        _infoFailed;

    final infoLoading =
        _infoLoading;

    final primary = <Widget>[
      _MedicineHero(
        medicine: medicine,
        result: _result,
        knowledge: knowledge,
        medicineType: type,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),
      _DetailActions(
        medicine: medicine,
        knowledge: knowledge,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),
      if (loading)
        _LoadingCard(
          isArabic: _isArabic,
        )
      else ...[
        _OverviewCard(
          medicine: medicine,
          result: _result,
          knowledge: knowledge,
          medicineType: type,
          isArabic: _isArabic,
        ),
        const SizedBox(height: 12),
        _OfficialRegistrySection(
          medicine: medicine,
          isArabic: _isArabic,
        ),
        const SizedBox(height: 12),
        _EquivalentPricesSection(
          medicine: medicine,
          isArabic: _isArabic,
          onMedicineTap: _openAlternative,
        ),
        const SizedBox(height: 12),
        _AlternativesSection(
          original: medicine,
          alternatives: alternatives,
          hadError: data?.alternativesError != null,
          isArabic: _isArabic,
          onMedicineTap: _openAlternative,
        ),
      ],
    ];

    final secondary = loading
        ? const <Widget>[]
        : <Widget>[
      _InfoSourceNote(
        info: _info,
        loading: infoLoading,
        failed: hadKnowledgeError,
        isArabic: _isArabic,
        onRetry: () => _loadInfo(forceRefresh: true),
      ),
      const SizedBox(height: 12),

      _UsesSection(
        knowledge: knowledge,
        hadError: hadKnowledgeError,
        loading: infoLoading,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),

      _HowToUseSection(
        result: _result,
        knowledge: knowledge,
        hadError: hadKnowledgeError,
        loading: infoLoading,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),

      _SideEffectsSection(
        knowledge: knowledge,
        hadError: hadKnowledgeError,
        loading: infoLoading,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),

      _SafetySection(
        knowledge: knowledge,
        hadError: hadKnowledgeError,
        loading: infoLoading,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),

      _ProductDetailsSection(
        medicine: medicine,
        knowledge: knowledge,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 12),

      _SourcesSection(
        medicine: medicine,
        knowledge: knowledge,
        isArabic: _isArabic,
      ),
      const SizedBox(height: 14),

      _SafetyFooter(
        isArabic: _isArabic,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final wide =
              constraints.maxWidth >= 1000;

          if (!wide) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                14,
                5,
                14,
                96,
              ),
              children: [
                ...primary,
                const SizedBox(height: 12),
                ...secondary,
              ],
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              5,
              16,
              96,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: primary,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: secondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  MedicineTypeInfo? _safeResolveType({
    required MedicinePrice medicine,
    required MedicineKnowledge? knowledge,
  }) {
    try {
      return _typeResolver.resolve(
        medicine: medicine,
        knowledge: knowledge,
      );
    } catch (error, stackTrace) {
      _debugLog(
        'Medicine type fallback resolution failed.',
        error,
        stackTrace,
      );

      return null;
    }
  }

  Widget _buildMissingMedicine() {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 46,
            color: palette.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              en: 'No medicine product is available.',
              ar: 'لا يوجد منتج دوائي لعرضه.',
            ),
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineDetailsData {
  const _MedicineDetailsData({
    this.knowledge,
    this.medicineType,
    this.alternatives = const <MedicinePrice>[],
    this.alternativesError,
  });

  final MedicineKnowledge? knowledge;
  final MedicineTypeInfo? medicineType;
  final List<MedicinePrice> alternatives;

  final Object? alternativesError;
}

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
                          ? (isArabic
                          ? 'مطابق للوصفة'
                          : 'Prescription match')
                          : (isArabic
                          ? 'منتج مختار'
                          : 'Selected product'),
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
      title: isArabic
          ? 'معلومات أساسية'
          : 'Medicine overview',
      color: PharmaLensColors.teal,
      child: Column(
        children: [
          _InfoRow(
            label: isArabic
                ? 'العائلة الدوائية'
                : 'Drug family',
            value: family,
          ),
          _InfoRow(
            label: isArabic
                ? 'التركيبة'
                : 'Composition',
            value: composition,
          ),
          _InfoRow(
            label: isArabic
                ? 'التركيز'
                : 'Strength',
            value: _strength(
              medicine,
              result,
              knowledge,
            ),
          ),
          _InfoRow(
            label: isArabic
                ? 'الشكل الدوائي'
                : 'Dosage form',
            value: _dosageForm(
              medicine,
              result,
              knowledge,
            ),
          ),
          _InfoRow(
            label: isArabic
                ? 'طريقة الإعطاء'
                : 'Route',
            value: _route(
              medicine,
              knowledge,
              isArabic: isArabic,
            ),
          ),
          _InfoRow(
            label: isArabic
                ? 'السعر'
                : 'Price',
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
      title: isArabic
          ? 'لماذا يُستخدم هذا الدواء؟'
          : 'Why is this medicine used?',
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
              ? (isArabic ? 'كيف يُستعمل عادةً' : 'How it is usually taken')
              : (isArabic ? 'الاستخدام المعتاد' : 'Usual use'),
          text: howToTake,
        ),
      if (food.isNotEmpty) ...[
        if (howToTake.isNotEmpty)
          const SizedBox(height: 13),
        _TextBlock(
          title: isArabic
              ? 'مع الطعام'
              : 'Food instructions',
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
          text: isArabic
              ? 'لم تُكتب طريقة الاستعمال على الوصفة. اسأل طبيبك أو الصيدلي كيف تأخذ هذا الدواء.'
              : 'No directions are written on the prescription. Ask your doctor or pharmacist how to take this medicine.',
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
      title: isArabic
          ? 'طريقة الاستخدام'
          : 'How to use',
      color: const Color(0xFF7457E8),
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
      title: isArabic
          ? 'الأعراض الجانبية'
          : 'Side effects',
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
              title: isArabic
                  ? 'أعراض شائعة'
                  : 'Common side effects',
              values: common,
              color: PharmaLensColors.warning,
            ),

          if (serious.isNotEmpty) ...[
            if (common.isNotEmpty)
              const SizedBox(height: 15),
            _BulletList(
              title: isArabic
                  ? 'تحذيرات مهمة'
                  : 'Serious warnings',
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
      title: isArabic
          ? 'التحذيرات والمعلومات المهمة'
          : 'Warnings & safety',
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
              title: isArabic
                  ? 'موانع الاستعمال'
                  : 'Contraindications',
              values: contraindications,
              color: PharmaLensColors.danger,
            ),

          if (interactions.isNotEmpty) ...[
            if (contraindications.isNotEmpty)
              const SizedBox(height: 15),
            _BulletList(
              title: isArabic
                  ? 'التداخلات الدوائية'
                  : 'Interactions',
              values: interactions,
              color: PharmaLensColors.warning,
            ),
          ],

          if (pregnancy.isNotEmpty) ...[
            if (contraindications.isNotEmpty ||
                interactions.isNotEmpty)
              const SizedBox(height: 15),
            _TextBlock(
              title: isArabic
                  ? 'الحمل والرضاعة'
                  : 'Pregnancy & breastfeeding',
              text: pregnancy,
            ),
          ],

          if (storage.isNotEmpty) ...[
            if (contraindications.isNotEmpty ||
                interactions.isNotEmpty ||
                pregnancy.isNotEmpty)
              const SizedBox(height: 15),
            _TextBlock(
              title: isArabic
                  ? 'التخزين'
                  : 'Storage',
              text: storage,
            ),
          ],
        ],
      ),
    );
  }
}

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
  Widget build(
      BuildContext context,
      ) {
    return _ExpandableCard(
      icon: Icons.swap_horiz_rounded,
      title: isArabic
          ? 'البدائل (${alternatives.length})'
          : 'Alternatives (${alternatives.length})',
      color: PharmaLensColors.teal,
      initiallyExpanded: alternatives.isNotEmpty,
      child: hadError
          ? _MessageBox(
        text: isArabic
            ? 'تعذر تحميل البدائل حاليًا. حاول التحديث مرة أخرى.'
            : 'Alternatives are temporarily unavailable. Try refreshing again.',
      )
          : alternatives.isEmpty
          ? _MessageBox(
        text: isArabic
            ? 'لم يتم العثور على بدائل مؤكدة في البيانات الحالية.'
            : 'No verified alternatives were found in the current data.',
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _MessageBox(
            text: isArabic
                ? 'يتم عرض المنتجات المرتبطة بنفس التركيبة الدوائية. قد يختلف التركيز أو الشكل الدوائي أو طريق الإعطاء، لذلك يجب التأكد قبل الاستبدال.'
                : 'Products sharing the verified medicine composition are shown here. Strength, dosage form, or route may differ, so substitution must be confirmed.',
            warning: true,
          ),
          const SizedBox(height: 10),

          ...alternatives.map(
                (alternative) {
              return _AlternativeTile(
                original: original,
                medicine: alternative,
                isArabic: isArabic,
                onTap: () {
                  onMedicineTap(
                    alternative,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.original,
    required this.medicine,
    required this.isArabic,
    required this.onTap,
  });

  final MedicinePrice original;
  final MedicinePrice medicine;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final hasStrengthComparison =
        _usable(original.displayStrength) &&
            _usable(medicine.displayStrength);

    final hasFormComparison =
        _usable(original.displayDosageForm) &&
            _usable(medicine.displayDosageForm);

    final hasRouteComparison =
        _usable(original.displayRoute) &&
            _usable(medicine.displayRoute);

    final sameStrength = hasStrengthComparison &&
        original.hasSameStrengthAs(medicine);

    final sameForm = hasFormComparison &&
        original.hasSameDosageFormAs(medicine);

    final sameRoute = hasRouteComparison &&
        original.hasCompatibleRouteWith(medicine);

    final comparedCount = <bool>[
      hasStrengthComparison,
      hasFormComparison,
      hasRouteComparison,
    ].where((value) => value).length;

    final matchedCount = <bool>[
      if (hasStrengthComparison) sameStrength,
      if (hasFormComparison) sameForm,
      if (hasRouteComparison) sameRoute,
    ].where((value) => value).length;

    final closest =
        comparedCount > 0 && matchedCount == comparedCount;

    final details = <String>[
      medicine.displayGenericName,
      medicine.displayStrength,
      medicine.displayDosageForm,
    ]
        .where(_usable)
        .map((value) => value.trim())
        .toSet()
        .join(' • ');

    final manufacturer =
    medicine.displayManufacturer.trim();

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Material(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.border,
              ),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: palette.tealSurface,
                    borderRadius:
                    BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _medicineIcon(
                      medicine.dosageForm,
                    ),
                    color: PharmaLensColors.teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.brandName,
                        textDirection:
                        _textDirectionFor(
                          medicine.brandName,
                        ),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),

                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          details,
                          textDirection:
                          _textDirectionFor(details),
                          style: TextStyle(
                            color:
                            palette.textSecondary,
                            fontSize: 10.8,
                            height: 1.35,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],

                      if (_usable(manufacturer)) ...[
                        const SizedBox(height: 3),
                        Text(
                          manufacturer,
                          textDirection:
                          _textDirectionFor(
                            manufacturer,
                          ),
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 9.8,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 7),

                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (closest)
                            _SmallBadge(
                              text: isArabic
                                  ? 'أقرب مطابقة'
                                  : 'Closest match',
                              color:
                              PharmaLensColors.teal,
                            ),

                          if (hasStrengthComparison &&
                              !sameStrength)
                            _SmallBadge(
                              text: isArabic
                                  ? 'تركيز مختلف'
                                  : 'Different strength',
                              color:
                              PharmaLensColors.warning,
                            ),

                          if (hasFormComparison &&
                              !sameForm)
                            _SmallBadge(
                              text: isArabic
                                  ? 'شكل مختلف'
                                  : 'Different form',
                              color:
                              PharmaLensColors.warning,
                            ),

                          if (hasRouteComparison &&
                              !sameRoute)
                            _SmallBadge(
                              text: isArabic
                                  ? 'طريق إعطاء مختلف'
                                  : 'Different route',
                              color:
                              PharmaLensColors.danger,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    if (_usable(
                      medicine.formattedPrice,
                    ))
                      Text(
                        medicine.formattedPrice,
                        textDirection:
                        TextDirection.ltr,
                        style: const TextStyle(
                          color:
                          PharmaLensColors.teal,
                          fontSize: 10,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textMuted,
                      size: 20,
                    ),
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
      title: isArabic
          ? 'معلومات المنتج'
          : 'Product information',
      color: PharmaLensColors.info,
      child: Column(
        children: [
          _InfoRow(
            label: isArabic
                ? 'الاسم التجاري'
                : 'Brand',
            value: medicine.brandName,
          ),
          _InfoRow(
            label: isArabic
                ? 'المادة الفعالة'
                : 'Active ingredient',
            value: _composition(
              medicine,
              knowledge,
            ),
          ),
          _InfoRow(
            label: isArabic
                ? 'الشركة المصنعة'
                : 'Manufacturer',
            value: medicine.displayManufacturer,
          ),
          _InfoRow(
            label: isArabic
                ? 'العبوة'
                : 'Pack',
            value: medicine.displayPackSize,
          ),
          _InfoRow(
            label: 'ATC',
            value: medicine.displayAtcCode,
          ),
          _InfoRow(
            label: isArabic
                ? 'رقم التسجيل'
                : 'Registration',
            value: medicine.registrationNumber ?? '',
          ),
          _InfoRow(
            label: isArabic
                ? 'تاريخ السعر'
                : 'Price date',
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
        label: isArabic
            ? 'مصدر المنتج والسعر'
            : 'Product / price source',
        value: medicine.sourceLabel,
      ),
      _SourceValue(
        label: isArabic
            ? 'تاريخ السعر'
            : 'Price date',
        value: medicine.formattedEffectiveDate,
      ),
      _SourceValue(
        label: isArabic
            ? 'المصدر الطبي'
            : 'Clinical source',
        value: clinicalSource,
      ),
      _SourceValue(
        label: isArabic
            ? 'آخر مراجعة'
            : 'Last reviewed',
        value: reviewedDate,
      ),
      _SourceValue(
        label: isArabic
            ? 'تمت المراجعة بواسطة'
            : 'Reviewed by',
        value: reviewedBy,
      ),
    ].where(
          (row) => _usable(row.value),
    ).toList();

    return _ExpandableCard(
      icon: Icons.fact_check_outlined,
      title: isArabic
          ? 'المصادر والمراجعة'
          : 'Sources & review',
      color: PharmaLensColors.teal,
      child: rows.isEmpty
          ? _MessageBox(
        text: isArabic
            ? 'لا توجد معلومات مصدر إضافية متاحة حاليًا.'
            : 'No additional source information is currently available.',
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(
                icon: icon,
                color: color,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: palette.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        // The tile paints its ink on the nearest Material; without this one
        // the card's colored box would hide it.
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          childrenPadding:
          const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            14,
          ),
          leading: _SectionIcon(
            icon: icon,
            color: color,
            isDark: isDark,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: color,
          collapsedIconColor:
          palette.textMuted,
          children: [
            Divider(
              height: 1,
              color: palette.border,
            ),
            const SizedBox(height: 12),
            child,
          ],
          ),
        ),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? 0.15 : 0.075,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (!_usable(value)) {
      return const SizedBox.shrink();
    }

    final palette =
    PharmaLensTheme.paletteOf(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11.2,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textDirection:
                  _textDirectionFor(value),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12.4,
                    height: 1.4,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: palette.border,
          ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textDirection:
          _textDirectionFor(text),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final List<String> values;
  final Color color;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final cleanedValues = values
        .map((value) => value.trim())
        .where(_usable)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...cleanedValues.map(
              (value) => Padding(
            padding: const EdgeInsets.only(
              bottom: 7,
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    textDirection:
                    _textDirectionFor(value),
                    style: TextStyle(
                      color:
                      palette.textSecondary,
                      fontSize: 12.3,
                      height: 1.45,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrescriptionBox extends StatelessWidget {
  const _PrescriptionBox({
    required this.value,
    required this.isArabic,
  });

  final String value;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    const color = Color(0xFF7457E8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.15
              : 0.07,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isArabic
                      ? 'كما كتب الطبيب على الوصفة'
                      : 'As written by your doctor',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            textDirection:
            _textDirectionFor(value),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewedText extends StatelessWidget {
  const _ReviewedText({
    required this.value,
    required this.hadError,
    required this.isArabic,
    required this.emptyEn,
    required this.emptyAr,
  });

  final String value;
  final bool hadError;
  final bool isArabic;
  final String emptyEn;
  final String emptyAr;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (value.trim().isNotEmpty) {
      return Text(
        value,
        textDirection:
        _textDirectionFor(value),
        style: TextStyle(
          color: PharmaLensTheme.paletteOf(
            context,
          ).textSecondary,
          fontSize: 12.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return _MessageBox(
      text: hadError
          ? (isArabic
          ? 'تعذر تحميل هذه المعلومات. اسحب الصفحة للأسفل لإعادة المحاولة.'
          : 'This information could not be loaded. Pull down to try again.')
          : (isArabic ? emptyAr : emptyEn),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.text,
    this.warning = false,
  });

  final String text;
  final bool warning;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: warning
            ? PharmaLensColors.warning.withValues(
          alpha:
          PharmaLensTheme.isDark(context)
              ? 0.13
              : 0.06,
        )
            : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textDirection:
        _textDirectionFor(text),
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.14
              : 0.07,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection:
              _textDirectionFor(label),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.border,
            ),
          ),
          child: loading
              ? Padding(
            padding: const EdgeInsets.all(12),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.textPrimary,
            ),
          )
              : Icon(
            icon,
            color: palette.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isArabic
                  ? 'جارٍ تحميل معلومات الدواء والبدائل...'
                  : 'Loading medicine information and alternatives...',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyFooter extends StatelessWidget {
  const _SafetyFooter({
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PharmaLensColors.warning.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.13
              : 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: PharmaLensColors.warning,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isArabic
                  ? 'لا تغيّر الجرعة أو المنتج أو الشكل الدوائي أو طريق الإعطاء اعتمادًا على هذه الصفحة وحدها. يجب تأكيد الاستبدال مع الطبيب أو الصيدلي.'
                  : 'Do not change the dose, product, dosage form, or route based on this page alone. Any substitution should be confirmed with a doctor or pharmacist.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.3,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayMedicineName(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    ) {
  final fromResult =
      result?.displayName.trim() ?? '';

  if (_usable(fromResult)) {
    return fromResult;
  }

  final brand = medicine.brandName.trim();

  if (_usable(brand)) {
    return brand;
  }

  return 'Medicine';
}

String _identityLine(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return _uniqueUsefulValues(
    <String>[
      _genericName(
        medicine,
        knowledge,
      ),
      _strength(
        medicine,
        result,
        knowledge,
      ),
      _dosageForm(
        medicine,
        result,
        knowledge,
      ),
    ],
  ).join(' • ');
}

String _genericName(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    knowledge?.genericName ?? '',
    medicine.genericName ?? '',
    medicine.displayGenericName,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _composition(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge,
    ) {
  final reviewedIngredients =
  _uniqueUsefulValues(
    knowledge?.activeIngredients ??
        const <String>[],
  );

  if (reviewedIngredients.isNotEmpty) {
    return reviewedIngredients.join(' + ');
  }

  final medicineIngredients =
  _uniqueUsefulValues(
    medicine.activeIngredients,
  );

  if (medicineIngredients.isNotEmpty) {
    return medicineIngredients.join(' + ');
  }

  return <String>[
    knowledge?.genericName ?? '',
    medicine.genericName ?? '',
    medicine.displayGenericName,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _strength(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    medicine.strength ?? '',
    knowledge?.strength ?? '',
    result?.displayStrength ?? '',
    medicine.displayStrength,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _dosageForm(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    medicine.dosageForm ?? '',
    knowledge?.dosageForm ?? '',
    result?.displayDosageForm ?? '',
    medicine.displayDosageForm,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _route(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge, {
      required bool isArabic,
    }) {
  return <String>[
    knowledge?.localizedRoute(
      isArabic: isArabic,
    ) ??
        '',
    medicine.route ?? '',
    medicine.displayRoute,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

List<String> _uniqueUsefulValues(
    Iterable<String> values,
    ) {
  final seen = <String>{};
  final result = <String>[];

  for (final rawValue in values) {
    final value = rawValue.trim();

    if (!_usable(value)) {
      continue;
    }

    final normalized = value.toLowerCase();

    if (seen.contains(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.add(value);
  }

  return result;
}

bool _usable(
    String value,
    ) {
  final normalized =
  value.trim().toLowerCase();

  return normalized.isNotEmpty &&
      !const <String>{
        '-',
        '—',
        '--',
        'null',
        'none',
        'unknown',
        'n/a',
        'na',
        'not available',
        'price unavailable',
        'route unavailable',
        'source unavailable',
        'pack unavailable',
        'manufacturer unavailable',
        'generic unavailable',
        'strength unavailable',
        'form unavailable',
      }.contains(normalized);
}

TextDirection _textDirectionFor(
    String value,
    ) {
  final arabic = RegExp(
    r'[\u0600-\u06FF]',
  ).allMatches(value).length;

  final latin = RegExp(
    r'[A-Za-z]',
  ).allMatches(value).length;

  return arabic > latin
      ? TextDirection.rtl
      : TextDirection.ltr;
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
      form.contains('suspension') ||
      form.contains('elixir')) {
    return Icons.local_drink_outlined;
  }

  if (form.contains('drop')) {
    return Icons.water_drop_outlined;
  }

  if (form.contains('cream') ||
      form.contains('ointment') ||
      form.contains('gel') ||
      form.contains('lotion')) {
    return Icons.sanitizer_outlined;
  }

  if (form.contains('spray') ||
      form.contains('inhal') ||
      form.contains('nebul')) {
    return Icons.air_rounded;
  }

  if (form.contains('suppository')) {
    return Icons.medication_liquid_outlined;
  }

  return Icons.medication_outlined;
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
        (isArabic ? 'المادة الفعالة: ' : 'Active ingredient: ') + medicine.activeIngredients.join(', '),
      if (uses.isNotEmpty) (isArabic ? 'الاستعمال: ' : 'Used for: ') + uses,
      if (howToTake.isNotEmpty) (isArabic ? 'طريقة الاستعمال: ' : 'How to take it: ') + howToTake,
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
                    label: Text(isArabic ? 'إيقاف مؤقت' : 'Pause'),
                  )
                : OutlinedButton.icon(
                    onPressed: () async {
                      final spoke = await speech.toggle(id, _spokenText, isArabic: isArabic);
                      if (!spoke && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic ? 'القراءة الصوتية غير متاحة على هذا الجهاز.' : 'Read aloud is not available on this device.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(paused ? Icons.play_arrow_rounded : Icons.volume_up_rounded),
                    label: Text(
                      paused ? (isArabic ? 'متابعة القراءة' : 'Resume') : (isArabic ? 'اقرأ بصوت عالٍ' : 'Read aloud'),
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
                    tooltip: isArabic ? 'إيقاف' : 'Stop',
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
          label: Text(isArabic ? 'تذكير بالدواء' : 'Add reminder'),
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
      text = isArabic
          ? 'جارٍ تحميل معلومات الدواء (الاستعمال، الأعراض الجانبية، التحذيرات)…'
          : 'Loading medicine information (uses, side effects, warnings)…';
    } else if (info == null) {
      icon = failed ? Icons.cloud_off_rounded : Icons.info_outline_rounded;
      color = failed ? PharmaLensColors.warning : palette.textMuted;
      text = failed
          ? (isArabic ? 'تعذر تحميل معلومات الدواء. تحقق من الاتصال بالإنترنت.' : 'Could not load the medicine information. Check your internet connection.')
          : (isArabic ? 'لا تتوفر معلومات إضافية عن هذا الدواء حاليًا.' : 'No further information is available for this medicine yet.');
      if (failed) {
        action = TextButton(onPressed: onRetry, child: Text(isArabic ? 'إعادة المحاولة' : 'Try again'));
      }
    } else {
      switch (info.origin) {
        case MedicineInfoOrigin.fdaLabelSummary:
          icon = Icons.auto_awesome_rounded;
          color = PharmaLensColors.info;
          text = isArabic
              ? 'ملخص بالذكاء الاصطناعي من نشرة إدارة الغذاء والدواء الأمريكية (FDA) لدواء بنفس المادة الفعالة${info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})'}. قد يختلف المنتج اللبناني قليلًا، وقد يحتوي الملخص على أخطاء.'
              : 'AI summary of the U.S. FDA label for the same active ingredient${info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})'}. The Lebanese product can differ slightly, and the summary can contain mistakes.';
        case MedicineInfoOrigin.fdaLabel:
          icon = Icons.description_outlined;
          color = PharmaLensColors.teal;
          text = isArabic
              ? 'من نشرة إدارة الغذاء والدواء الأمريكية (FDA) لدواء بنفس المادة الفعالة${info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})'}، باللغة الإنجليزية.'
              : 'From the U.S. FDA label for the same active ingredient${info.sourceTitle.isEmpty ? '' : ' (${info.sourceTitle})'}.';
        case MedicineInfoOrigin.aiGenerated:
          icon = Icons.auto_awesome_rounded;
          color = PharmaLensColors.warning;
          text = isArabic
              ? 'كُتبت هذه المعلومات بالذكاء الاصطناعي لعدم توفر نشرة رسمية. قد تحتوي على أخطاء، فتأكد منها مع الصيدلي أو من النشرة داخل العلبة.'
              : 'Written by AI because no official leaflet was found. It can contain mistakes: check it with your pharmacist or the leaflet in the box.';
      }
      final url = Uri.tryParse(info.sourceUrl);
      if (url != null && info.sourceUrl.isNotEmpty) {
        action = TextButton(
          onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
          child: Text(isArabic ? 'فتح النشرة' : 'Open label'),
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
            isArabic ? 'جارٍ التحميل…' : 'Loading…',
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
        (isArabic ? 'المادة الفعالة' : 'Active ingredients', medicine.activeIngredients.join('\n')),
      if (group != null)
        (
          isArabic ? 'الفئة العلاجية' : 'Therapeutic group',
          [
            group.localized(isArabic: isArabic),
            if (anatomical != null && anatomical.code != group.code) anatomical.localized(isArabic: isArabic),
          ].join(' · '),
        ),
      if ((medicine.atcCode ?? '').trim().isNotEmpty) ('ATC', medicine.atcCode!.trim()),
      if (medicine.formattedPriceLbp.isNotEmpty)
        (
          isArabic ? 'السعر الرسمي' : 'Official price',
          '${medicine.formattedPriceLbp} ${isArabic ? 'ل.ل.' : 'LBP'}'
              '${moph.lastUpdatedDate.isEmpty ? '' : isArabic ? ' (لائحة ${moph.lastUpdatedDate})' : ' (list of ${moph.lastUpdatedDate})'}',
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            icon: Icons.verified_outlined,
            title: isArabic ? 'من سجل وزارة الصحة' : 'From the MOPH registry',
            subtitle: isArabic ? 'بيانات رسمية، وليست نصيحة طبية' : 'Official data, not medical advice',
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
              isArabic
                  ? 'قد يكون هذا السعر قديمًا. تحقق منه في الصيدلية.'
                  : 'This price may be out of date. Confirm it at the pharmacy.',
              style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// Same ingredients, strength and form from other manufacturers, cheapest first.
class _EquivalentPricesSection extends StatelessWidget {
  const _EquivalentPricesSection({
    required this.medicine,
    required this.isArabic,
    required this.onMedicineTap,
  });

  final MedicinePrice medicine;
  final bool isArabic;
  final void Function(MedicinePrice medicine) onMedicineTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return FutureBuilder<List<MedicinePrice>>(
      future: MophMedicineService().findExactAlternatives(medicine, limit: 8),
      builder: (context, snapshot) {
        final equivalents = snapshot.data ?? const <MedicinePrice>[];
        if (equivalents.isEmpty) return const SizedBox.shrink();

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.savings_outlined,
                title: isArabic ? 'نفس الدواء بأسعار أخرى' : 'Same medicine, other prices',
                subtitle: isArabic
                    ? 'نفس المادة والتركيز والشكل الصيدلاني، من الأرخص إلى الأغلى'
                    : 'Same ingredient, strength and form, cheapest first',
              ),
              const SizedBox(height: 10),
              for (final equivalent in equivalents)
                _EquivalentTile(
                  medicine: equivalent,
                  original: medicine,
                  isArabic: isArabic,
                  onTap: () => onMedicineTap(equivalent),
                ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'لا تستبدل دواءك قبل استشارة الطبيب أو الصيدلي، حتى لو كانت المادة نفسها.'
                    : 'Do not switch before asking your doctor or pharmacist, even when the ingredient is the same.',
                style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EquivalentTile extends StatelessWidget {
  const _EquivalentTile({
    required this.medicine,
    required this.original,
    required this.isArabic,
    required this.onTap,
  });

  final MedicinePrice medicine;
  final MedicinePrice original;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final price = medicine.priceLbp;
    final saving = MedicineEquivalence.savingPercent(original, medicine);
    final perUnit = MedicineEquivalence.unitPrice(medicine);
    final unit = MedicineEquivalence.packQuantity(medicine.packSize)?.$2;

    // A ListTile caps the trailing area at its own height, which clips the
    // third price line; this row grows with its content instead.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.brandName,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [medicine.displayPackSize, medicine.displayManufacturer].where((v) => v.trim().isNotEmpty && v != '—').join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price == null ? '—' : '${medicine.formattedPriceLbp} ${isArabic ? 'ل.ل.' : 'LBP'}',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
                if (perUnit != null && unit == 'unit')
                  Text(
                    isArabic ? '${formatCount(perUnit.round())} ل.ل. للوحدة' : '${formatCount(perUnit.round())} LBP each',
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                if (saving != null && saving > 0)
                  Text(
                    isArabic ? 'أرخص بـ $saving٪ للكمية نفسها' : '$saving% cheaper per dose',
                    style: const TextStyle(color: PharmaLensColors.success, fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
