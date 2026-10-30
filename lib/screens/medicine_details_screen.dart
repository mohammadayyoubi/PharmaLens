import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_text.dart';
import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../models/verified_medicine_result.dart';
import '../services/medicine_alternative_service.dart';
import '../services/medicine_info_service.dart';
import '../services/medicine_type_resolver.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/for_you_card.dart';
import '../services/moph_medicine_service.dart';
import '../services/speech_service.dart';
import '../utils/atc_groups.dart';
import '../utils/formatters.dart';
import '../utils/medicine_equivalence.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/responsive.dart';

part 'medicine_details/overview_sections.dart';
part 'medicine_details/price_and_source_sections.dart';
part 'medicine_details/building_blocks.dart';
part 'medicine_details/helpers.dart';

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
        limit: 60,
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
                  appText(_isArabic).medicineInformation,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appText(_isArabic).compositionUsesSafetyAndAlternatives,
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

      ForYouCard(
        medicine: medicine,
        knowledge: knowledge,
        isArabic: _isArabic,
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
            appText(_isArabic).noMedicineProductIsAvailable,
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
