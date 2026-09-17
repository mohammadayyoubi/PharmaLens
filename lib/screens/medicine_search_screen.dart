import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/medicine_price.dart';
import '../screens/medicine_details_screen.dart';
import '../services/moph_medicine_service.dart';
import '../services/supabase_medicine_service.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/chatbot_view.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({
    super.key,
    this.initialQuery = '',
    this.selectionMode = false,
  });

  final String initialQuery;

  /// When true, the screen returns a selected MedicinePrice.
  ///
  /// Manual selection identifies a database product only.
  /// It does not verify that the product matches a prescription.
  final bool selectionMode;

  @override
  State<MedicineSearchScreen> createState() {
    return _MedicineSearchScreenState();
  }
}

class _MedicineSearchScreenState
    extends State<MedicineSearchScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final SupabaseMedicineService _medicineService =
  SupabaseMedicineService();

  List<MedicinePrice> _results =
  const <MedicinePrice>[];

  bool _isLoading = false;
  bool _hasSearched = false;

  String _lastQuery = '';
  String? _errorMessage;

  int _searchRequestId = 0;

  bool get _isArabic {
    return Localizations.localeOf(context)
        .languageCode
        .toLowerCase() ==
        'ar';
  }

  String _t({
    required String en,
    required String ar,
  }) {
    return _isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();

    final initialQuery =
    widget.initialQuery.trim();

    if (initialQuery.isEmpty) {
      return;
    }

    _searchController.text =
        initialQuery;

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (mounted) {
          _search();
        }
      },
    );
  }

  Future<void> _search({
    bool forceRefresh = false,
  }) async {
    final query =
    _searchController.text.trim();

    if (query.isEmpty) {
      _searchFocusNode.requestFocus();

      setState(() {
        _results =
        const <MedicinePrice>[];

        _lastQuery = '';
        _hasSearched = false;
        _isLoading = false;

        _errorMessage = _t(
          en:
          'Enter a medicine name to search.',
          ar:
          'أدخل اسم الدواء للبحث.',
        );
      });

      return;
    }

    _searchFocusNode.unfocus();

    final requestId =
    ++_searchRequestId;

    setState(() {
      _isLoading = true;
      _hasSearched = true;

      _lastQuery = query;

      _errorMessage = null;
    });

    try {
      final results = await MophMedicineService().searchMedicines(
        query,
        limit: 40,
        forceRefresh: forceRefresh,
      );

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _results = List<MedicinePrice>.unmodifiable(results);
        _isLoading = false;

        if (_results.isEmpty) {
          _errorMessage = _t(
            en: 'No matching medicines were found in the MOPH Lebanon database.',
            ar: 'لم يتم العثور على أدوية مطابقة في قاعدة بيانات وزارة الصحة.',
          );
        }
      });
    } catch (error, stackTrace) {
      _debugLog(
        'MOPH Medicine search failed.',
        error,
        stackTrace,
      );

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _results = const <MedicinePrice>[];
        _isLoading = false;
        _errorMessage = _t(
          en: 'Search service is temporarily unavailable.',
          ar: 'خدمة البحث غير متاحة حالياً.',
        );
      });
    }
  }

  void _clearSearch() {
    ++_searchRequestId;

    _searchController.clear();

    _searchFocusNode.requestFocus();

    setState(() {
      _results =
      const <MedicinePrice>[];

      _lastQuery = '';
      _errorMessage = null;

      _hasSearched = false;
      _isLoading = false;
    });
  }

  Future<void> _syncMophPrices() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            en: 'Syncing with Ministry of Public Health (MOPH) website...',
            ar: 'جاري التحديث مع موقع وزارة الصحة العامة...',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await MophMedicineService().updateFromMophWebsite();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? PharmaLensColors.teal : PharmaLensColors.danger,
      ),
    );

    if (_searchController.text.trim().isNotEmpty) {
      _search(forceRefresh: true);
    }
  }

  Future<void> _openMedicineDetails(
      MedicinePrice medicine,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MedicineDetailsScreen(
              medicine: medicine
            ),
      ),
    );
  }

  Future<void> _selectMedicine(
      MedicinePrice medicine,
      ) async {
    if (!widget.selectionMode) {
      return;
    }

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (
          dialogContext,
          ) {
        final palette =
        PharmaLensTheme
            .paletteOf(
          dialogContext,
        );

        return Directionality(
          textDirection:
          _isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor:
            palette.surface,
            surfaceTintColor:
            Colors.transparent,
            title: Row(
              children: [
                const Icon(
                  Icons
                      .fact_check_outlined,
                  color:
                  PharmaLensColors
                      .teal,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    _t(
                      en:
                      'Select medicine',
                      ar:
                      'اختيار الدواء',
                    ),
                    style:
                    TextStyle(
                      color:
                      palette
                          .textPrimary,
                      fontWeight:
                      FontWeight
                          .w900,
                    ),
                  ),
                ),
              ],
            ),
            content:
            SingleChildScrollView(
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    _t(
                      en:
                      'Confirm that this is the exact database product you want to select.',
                      ar:
                      'تأكد أن هذا هو المنتج الدوائي الدقيق الذي تريد اختياره من قاعدة البيانات.',
                    ),
                    style:
                    TextStyle(
                      color:
                      palette
                          .textSecondary,
                      height:
                      1.45,
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _SelectionProductCard(
                    medicine:
                    medicine,
                    isArabic:
                    _isArabic,
                  ),

                  const SizedBox(
                    height: 13,
                  ),

                  _SafetyMessage(
                    message: _t(
                      en:
                      'Manual selection identifies this database product only. It does not verify that it is the same medicine written on a prescription and does not authorize substitution.',
                      ar:
                      'الاختيار اليدوي يحدد هذا المنتج من قاعدة البيانات فقط. لا يؤكد أنه نفس الدواء المكتوب في الوصفة ولا يسمح بالاستبدال تلقائيًا.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: Text(
                  _t(
                    en: 'Cancel',
                    ar: 'إلغاء',
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                icon: const Icon(
                  Icons.check_rounded,
                ),
                label: Text(
                  _t(
                    en: 'Select',
                    ar: 'اختيار',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    Navigator.of(context).pop(
      medicine,
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
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Directionality(
      textDirection:
      _isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: palette.background,
        floatingActionButton: const FloatingChatbotButton(),
        appBar: AppBar(
          title: Text(
            widget.selectionMode
                ? _t(
              en:
              'Select Medicine',
              ar:
              'اختيار الدواء',
            )
                : _t(
              en:
              'Medicine Search',
              ar:
              'البحث عن دواء',
            ),
            style:
            const TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: _t(
                en: 'Sync MOPH Lebanon Prices',
                ar: 'تحديث أسعار وزارة الصحة',
              ),
              icon: const Icon(Icons.sync_rounded),
              onPressed: _syncMophPrices,
            ),
          ],
          backgroundColor:
          palette.surface,
          surfaceTintColor:
          Colors.transparent,
          foregroundColor:
          palette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient:
            palette.pageGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildSearchArea(),

                if (_isLoading)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    color:
                    PharmaLensColors
                        .teal,
                  ),

                Expanded(
                  child:
                  _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchArea() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        15,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          bottom: BorderSide(
            color:
            palette.border,
          ),
        ),
        boxShadow:
        palette.cardShadow,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 820,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              if (widget
                  .selectionMode) ...[
                Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    12,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    palette.tealSurface,
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                    border:
                    Border.all(
                      color:
                      PharmaLensColors
                          .teal
                          .withValues(
                        alpha:
                        isDark
                            ? 0.42
                            : 0.25,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Icon(
                        Icons
                            .manage_search_rounded,
                        color:
                        PharmaLensColors
                            .teal,
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Expanded(
                        child: Text(
                          _t(
                            en:
                            'Search the database and select the exact product after checking its strength, form, pack and manufacturer.',
                            ar:
                            'ابحث في قاعدة البيانات واختر المنتج الدقيق بعد التأكد من التركيز والشكل والعبوة والشركة المصنعة.',
                          ),
                          style:
                          TextStyle(
                            color:
                            palette
                                .textSecondary,
                            height:
                            1.4,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),
              ],

              Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          widget.selectionMode
                              ? _t(
                            en:
                            'Find the exact product',
                            ar:
                            'ابحث عن المنتج الدقيق',
                          )
                              : _t(
                            en:
                            'Lebanese medicine database',
                            ar:
                            'قاعدة بيانات الأدوية في لبنان',
                          ),
                          style:
                          TextStyle(
                            color:
                            palette
                                .textPrimary,
                            fontSize:
                            21,
                            height:
                            1.2,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          _t(
                            en:
                            'Search by brand or active ingredient. Add strength or dosage form to narrow the results.',
                            ar:
                            'ابحث باسم العلامة التجارية أو المادة الفعالة. أضف التركيز أو الشكل الدوائي لتضييق النتائج.',
                          ),
                          style:
                          TextStyle(
                            color:
                            palette
                                .textSecondary,
                            height:
                            1.35,
                            fontWeight:
                            FontWeight
                                .w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!widget
                      .selectionMode) ...[
                    const SizedBox(
                      width: 10,
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        PharmaLensColors
                            .teal
                            .withValues(
                          alpha:
                          isDark
                              ? 0.17
                              : 0.10,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons
                                .storage_rounded,
                            size: 16,
                            color:
                            PharmaLensColors
                                .teal,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            _t(
                              en:
                              'Database',
                              ar:
                              'قاعدة البيانات',
                            ),
                            style:
                            const TextStyle(
                              color:
                              PharmaLensColors
                                  .teal,
                              fontSize:
                              12,
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final horizontal =
                      constraints.maxWidth >=
                          620;

                  final searchField =
                  TextField(
                    controller:
                    _searchController,
                    focusNode:
                    _searchFocusNode,
                    textInputAction:
                    TextInputAction
                        .search,
                    autocorrect: false,
                    enableSuggestions:
                    false,
                    style:
                    TextStyle(
                      color:
                      palette
                          .textPrimary,
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                    onSubmitted: (_) {
                      if (!_isLoading) {
                        _search();
                      }
                    },
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration:
                    InputDecoration(
                      hintText: _t(
                        en:
                        'Example: Augmentin 625 mg',
                        ar:
                        'مثال: Augmentin 625 mg',
                      ),
                      prefixIcon:
                      const Icon(
                        Icons
                            .search_rounded,
                      ),
                      suffixIcon:
                      _searchController
                          .text
                          .isEmpty
                          ? null
                          : IconButton(
                        tooltip:
                        _t(
                          en:
                          'Clear search',
                          ar:
                          'مسح البحث',
                        ),
                        onPressed:
                        _clearSearch,
                        icon:
                        const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ),
                  );

                  final searchButton =
                  SizedBox(
                    height: 50,
                    child:
                    FilledButton.icon(
                      onPressed:
                      _isLoading
                          ? null
                          : () {
                        _search();
                      },
                      icon:
                      const Icon(
                        Icons
                            .medication_outlined,
                      ),
                      label: Text(
                        _isLoading
                            ? _t(
                          en:
                          'Searching...',
                          ar:
                          'جارٍ البحث...',
                        )
                            : _t(
                          en:
                          'Search medicines',
                          ar:
                          'بحث عن الأدوية',
                        ),
                      ),
                    ),
                  );

                  if (horizontal) {
                    return Row(
                      children: [
                        Expanded(
                          child:
                          searchField,
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        SizedBox(
                          width: 190,
                          child:
                          searchButton,
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      searchField,
                      const SizedBox(
                        height: 10,
                      ),
                      SizedBox(
                        width:
                        double.infinity,
                        child:
                        searchButton,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      final canRetry =
          _hasSearched &&
              _searchController.text
                  .trim()
                  .isNotEmpty;

      return _MessageState(
        icon:
        Icons.info_outline_rounded,
        title:
        _errorMessage!,
        subtitle: canRetry
            ? _t(
          en:
          'Check the spelling or try a shorter medicine name.',
          ar:
          'تحقق من كتابة الاسم أو جرّب جزءًا أقصر من اسم الدواء.',
        )
            : _t(
          en:
          'Enter a brand or active ingredient.',
          ar:
          'أدخل اسم العلامة التجارية أو المادة الفعالة.',
        ),
        buttonText: canRetry
            ? _t(
          en: 'Try again',
          ar:
          'إعادة المحاولة',
        )
            : null,
        onPressed: canRetry
            ? () {
          _search(
            forceRefresh:
            true,
          );
        }
            : null,
      );
    }

    if (!_hasSearched) {
      return _MessageState(
        icon: widget.selectionMode
            ? Icons
            .fact_check_outlined
            : Icons
            .medication_liquid_outlined,
        title: widget.selectionMode
            ? _t(
          en:
          'Search and select the exact product',
          ar:
          'ابحث واختر المنتج الدقيق',
        )
            : _t(
          en:
          'Find medicine information',
          ar:
          'ابحث عن معلومات الدواء',
        ),
        subtitle: widget.selectionMode
            ? _t(
          en:
          'Review the exact product record before selecting it.',
          ar:
          'راجع سجل المنتج الدقيق قبل اختياره.',
        )
            : _t(
          en:
          'Search product records, prices, reviewed information and verified-composition alternatives.',
          ar:
          'ابحث في سجلات المنتجات والأسعار والمعلومات المراجعة والبدائل ذات التركيبة المتحقّق منها.',
        ),
      );
    }

    if (_isLoading &&
        _results.isEmpty) {
      return _MessageState(
        icon:
        Icons.manage_search_rounded,
        title: _t(
          en:
          'Searching the medicine database...',
          ar:
          'جارٍ البحث في قاعدة بيانات الأدوية...',
        ),
        subtitle: _t(
          en:
          'Please wait a moment.',
          ar:
          'يرجى الانتظار قليلًا.',
        ),
      );
    }

    if (_results.isEmpty) {
      return _MessageState(
        icon:
        Icons.search_off_rounded,
        title: _t(
          en:
          'No medicines found',
          ar:
          'لم يتم العثور على أدوية',
        ),
        subtitle: _t(
          en:
          'Try using only part of the medicine name.',
          ar:
          'جرّب استخدام جزء من اسم الدواء.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return _search(
          forceRefresh: true,
        );
      },
      child:
      ListView.separated(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          28,
        ),
        itemCount:
        _results.length + 1,
        separatorBuilder: (
            context,
            index,
            ) {
          return SizedBox(
            height:
            index == 0 ? 12 : 14,
          );
        },
        itemBuilder: (
            context,
            index,
            ) {
          if (index == 0) {
            return Center(
              child:
              ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 820,
                ),
                child:
                _ResultsSummary(
                  query:
                  _lastQuery,
                  resultCount:
                  _results.length,
                  isArabic:
                  _isArabic,
                ),
              ),
            );
          }

          final resultIndex =
              index - 1;

          final medicine =
          _results[resultIndex];

          return Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 820,
              ),
              child:
              _MedicineCard(
                medicine:
                medicine,
                resultNumber:
                resultIndex + 1,
                selectionMode:
                widget.selectionMode,
                isArabic:
                _isArabic,
                onOpenDetails: () {
                  _openMedicineDetails(
                    medicine,
                  );
                },
                onSelect:
                widget.selectionMode
                    ? () {
                  _selectMedicine(
                    medicine,
                  );
                }
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    ++_searchRequestId;

    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }
}

class _ResultsSummary
    extends StatelessWidget {
  const _ResultsSummary({
    required this.query,
    required this.resultCount,
    required this.isArabic,
  });

  final String query;
  final int resultCount;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                isArabic
                    ? '$resultCount نتيجة'
                    : '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
                style:
                TextStyle(
                  color:
                  palette
                      .textPrimary,
                  fontSize: 17,
                  fontWeight:
                  FontWeight
                      .w900,
                ),
              ),
              if (query
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 3,
                ),
                Text(
                  isArabic
                      ? 'البحث عن “$query”'
                      : 'For “$query”',
                  textDirection:
                  TextDirection.ltr,
                  style:
                  TextStyle(
                    color:
                    palette
                        .textSecondary,
                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Text(
          isArabic
              ? 'اضغط للتفاصيل'
              : 'Tap for details',
          style:
          TextStyle(
            color:
            palette.textMuted,
            fontSize: 12,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MedicineCard
    extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.resultNumber,
    required this.selectionMode,
    required this.isArabic,
    required this.onOpenDetails,
    required this.onSelect,
  });

  final MedicinePrice medicine;

  final int resultNumber;

  final bool selectionMode;
  final bool isArabic;

  final VoidCallback onOpenDetails;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final borderRadius =
    BorderRadius.circular(
      20,
    );

    final genericName =
        medicine
            .genericName
            ?.trim() ??
            '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: palette.surface,
      surfaceTintColor:
      Colors.transparent,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        borderRadius,
        side: BorderSide(
          color:
          palette.border,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap:
        onOpenDetails,
        borderRadius:
        borderRadius,
        child: Padding(
          padding:
          const EdgeInsets.all(
            17,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      color:
                      palette
                          .tealSurface,
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      _medicineIcon(
                        medicine
                            .dosageForm,
                      ),
                      color:
                      PharmaLensColors
                          .teal,
                    ),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          medicine
                              .brandName,
                          textDirection:
                          TextDirection
                              .ltr,
                          style:
                          TextStyle(
                            color:
                            palette
                                .textPrimary,
                            fontSize:
                            19,
                            height:
                            1.2,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),

                        if (genericName
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            genericName,
                            textDirection:
                            TextDirection
                                .ltr,
                            style:
                            TextStyle(
                              color:
                              palette
                                  .textSecondary,
                              height:
                              1.3,
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      palette
                          .surfaceSoft,
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                      border:
                      Border.all(
                        color:
                        palette
                            .borderSoft,
                      ),
                    ),
                    child: Text(
                      '#$resultNumber',
                      style:
                      TextStyle(
                        color:
                        palette
                            .textSecondary,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (medicine
                      .hasStrength)
                    _MedicineTag(
                      icon: Icons
                          .science_outlined,
                      text: medicine
                          .displayStrength,
                    ),

                  if (medicine
                      .hasDosageForm)
                    _MedicineTag(
                      icon: Icons
                          .medication_liquid_outlined,
                      text: medicine
                          .displayDosageForm,
                    ),

                  if (medicine
                      .hasPackSize)
                    _MedicineTag(
                      icon: Icons
                          .inventory_2_outlined,
                      text: medicine
                          .displayPackSize,
                    ),

                  if (medicine
                      .isOfficialSource)
                    _MedicineTag(
                      icon: Icons
                          .verified_outlined,
                      text: isArabic
                          ? 'مصدر رسمي'
                          : 'Official source',
                      accent:
                      PharmaLensColors
                          .teal,
                    ),
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              _PriceSummary(
                medicine:
                medicine,
                isArabic:
                isArabic,
              ),

              if (medicine
                  .hasManufacturer) ...[
                const SizedBox(
                  height: 11,
                ),
                _DetailLine(
                  icon: Icons
                      .factory_outlined,
                  label: isArabic
                      ? 'الشركة'
                      : 'Manufacturer',
                  value: medicine
                      .displayManufacturer,
                ),
              ],

              const SizedBox(
                height: 14,
              ),

              LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final narrow =
                      constraints.maxWidth <
                          350;

                  final details =
                  OutlinedButton.icon(
                    onPressed:
                    onOpenDetails,
                    icon:
                    const Icon(
                      Icons
                          .receipt_long_outlined,
                    ),
                    label: Text(
                      isArabic
                          ? 'التفاصيل'
                          : 'Details',
                    ),
                  );

                  final select =
                  selectionMode
                      ? FilledButton.icon(
                    onPressed:
                    onSelect,
                    icon:
                    const Icon(
                      Icons
                          .touch_app_rounded,
                    ),
                    label:
                    Text(
                      isArabic
                          ? 'اختيار هذا الدواء'
                          : 'Select medicine',
                    ),
                  )
                      : null;

                  if (select == null) {
                    return SizedBox(
                      width:
                      double.infinity,
                      child:
                      details,
                    );
                  }

                  if (narrow) {
                    return Column(
                      children: [
                        SizedBox(
                          width:
                          double.infinity,
                          child:
                          details,
                        ),
                        const SizedBox(
                          height: 9,
                        ),
                        SizedBox(
                          width:
                          double.infinity,
                          child:
                          select,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child:
                        details,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child:
                        select,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceSummary
    extends StatelessWidget {
  const _PriceSummary({
    required this.medicine,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
        PharmaLensColors.teal
            .withValues(
          alpha:
          isDark
              ? 0.16
              : 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            color:
            PharmaLensColors
                .teal,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'السعر المسجل'
                      : 'Recorded price',
                  style:
                  TextStyle(
                    color:
                    palette
                        .textSecondary,
                    fontSize: 11,
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),

                if (medicine
                    .hasEffectiveDate)
                  Text(
                    medicine
                        .formattedEffectiveDate,
                    textDirection:
                    TextDirection
                        .ltr,
                    style:
                    TextStyle(
                      color:
                      palette
                          .textMuted,
                      fontSize:
                      10.5,
                    ),
                  ),
              ],
            ),
          ),

          Text(
            medicine
                .formattedPrice,
            textDirection:
            TextDirection.ltr,
            style:
            const TextStyle(
              color:
              PharmaLensColors
                  .teal,
              fontSize: 18,
              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionProductCard
    extends StatelessWidget {
  const _SelectionProductCard({
    required this.medicine,
    required this.isArabic,
  });

  final MedicinePrice medicine;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color:
        palette.surfaceSoft,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
          palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            medicine.brandName,
            textDirection:
            TextDirection.ltr,
            style:
            TextStyle(
              color:
              palette.textPrimary,
              fontSize: 19,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          if (medicine
              .hasGenericName) ...[
            const SizedBox(
              height: 4,
            ),
            Text(
              medicine
                  .displayGenericName,
              textDirection:
              TextDirection.ltr,
              style:
              TextStyle(
                color:
                palette
                    .textSecondary,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          _ConfirmationRow(
            label: isArabic
                ? 'التركيز'
                : 'Strength',
            value:
            medicine
                .displayStrength,
          ),

          _ConfirmationRow(
            label: isArabic
                ? 'الشكل'
                : 'Form',
            value:
            medicine
                .displayDosageForm,
          ),

          _ConfirmationRow(
            label: isArabic
                ? 'العبوة'
                : 'Pack',
            value:
            medicine
                .displayPackSize,
          ),

          _ConfirmationRow(
            label: isArabic
                ? 'الشركة'
                : 'Manufacturer',
            value:
            medicine
                .displayManufacturer,
          ),

          _ConfirmationRow(
            label: isArabic
                ? 'السعر'
                : 'Price',
            value:
            medicine
                .formattedPrice,
          ),
        ],
      ),
    );
  }
}

class _ConfirmationRow
    extends StatelessWidget {
  const _ConfirmationRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style:
              TextStyle(
                color:
                palette.textMuted,
                fontSize: 11,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textDirection:
              TextDirection.ltr,
              style:
              TextStyle(
                color:
                palette
                    .textPrimary,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineTag
    extends StatelessWidget {
  const _MedicineTag({
    required this.icon,
    required this.text,
    this.accent,
  });

  final IconData icon;
  final String text;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final color =
        accent ??
            palette.textSecondary;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
        palette.surfaceSoft,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
        border: Border.all(
          color:
          palette.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
            textDirection:
            TextDirection.ltr,
            style:
            TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine
    extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color:
          palette.textMuted,
        ),
        const SizedBox(
          width: 8,
        ),
        Text(
          '$label: ',
          style:
          TextStyle(
            color:
            palette
                .textSecondary,
            fontSize: 11.5,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection:
            TextDirection.ltr,
            style:
            TextStyle(
              color:
              palette.textPrimary,
              fontSize: 11.5,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SafetyMessage
    extends StatelessWidget {
  const _SafetyMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        11,
      ),
      decoration: BoxDecoration(
        color:
        PharmaLensColors.warning
            .withValues(
          alpha:
          PharmaLensTheme.isDark(
            context,
          )
              ? 0.15
              : 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons
                .warning_amber_rounded,
            size: 19,
            color:
            PharmaLensColors
                .warning,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              message,
              style:
              TextStyle(
                color:
                palette
                    .textSecondary,
                height: 1.45,
                fontSize: 11.5,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState
    extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration:
                BoxDecoration(
                  color:
                  palette.tealSurface,
                  borderRadius:
                  BorderRadius.circular(
                    23,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                  PharmaLensColors
                      .teal,
                  size: 38,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              Text(
                title,
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  palette.textPrimary,
                  fontSize: 19,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 7,
              ),
              Text(
                subtitle,
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  palette
                      .textSecondary,
                  height: 1.45,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
              if (buttonText != null &&
                  onPressed !=
                      null) ...[
                const SizedBox(
                  height: 15,
                ),
                FilledButton.icon(
                  onPressed:
                  onPressed,
                  icon:
                  const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label: Text(
                    buttonText!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _medicineIcon(
    String? dosageForm,
    ) {
  final form =
      dosageForm
          ?.trim()
          .toLowerCase() ??
          '';

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