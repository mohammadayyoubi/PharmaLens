import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../screens/medicine_details_screen.dart';
import '../services/moph_medicine_service.dart';

import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/responsive.dart';
import '../widgets/sync_progress.dart';

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



  List<MedicinePrice> _results =
  const <MedicinePrice>[];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _hasSearched = false;

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 30;

  String _lastQuery = '';
  String? _errorMessage;

  /// All matches of the current search (or the whole list when browsing),
  /// while [_results] holds only the pages loaded so far.
  int? _totalMatches;

  Timer? _typingDebounce;
  static const Duration _typingDelay = Duration(milliseconds: 350);

  int _searchRequestId = 0;

  bool get _isArabic {
    return Localizations.localeOf(context)
        .languageCode
        .toLowerCase() ==
        'ar';
  }

  @override
  void initState() {
    super.initState();

    final initialQuery =
    widget.initialQuery.trim();

    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted) {
          _search(reset: true);
        }
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    final requestId = _searchRequestId;
    final query = _searchController.text.trim();

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreResults = await MophMedicineService().searchMedicines(
        query,
        limit: _pageSize,
        offset: _results.length,
      );

      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _results = <MedicinePrice>[..._results, ...moreResults];
        _hasMore = moreResults.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _search({
    bool reset = true,
    bool forceRefresh = false,
  }) async {
    final query =
    _searchController.text.trim();

    final requestId =
    ++_searchRequestId;

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasSearched = true;
      _lastQuery = query;
      _errorMessage = null;
      if (reset) {
        _results = const <MedicinePrice>[];
      }
    });

    try {
      final results = await MophMedicineService().searchMedicines(
        query,
        limit: _pageSize,
        offset: 0,
        forceRefresh: forceRefresh,
      );

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      final total = await MophMedicineService().countMatches(query);
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _results = List<MedicinePrice>.unmodifiable(results);
        _totalMatches = total;
        _hasMore = results.length == _pageSize;
        _isLoading = false;

        if (_results.isEmpty) {
          _errorMessage = query.isEmpty
              ? appText(_isArabic).noMedicinesFoundInTheDatabase
              : appText(_isArabic).noMatchingMedicinesWereFoundIn;
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
        _hasMore = false;
        _isLoading = false;
        _errorMessage = appText(_isArabic).searchServiceIsTemporarilyUnavailable;
      });
    }
  }



  /// Back to the whole list, the same as opening the page.
  void _clearSearch() {
    _typingDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.requestFocus();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _search(reset: true);
  }

  Future<void> _syncMophPrices() async {
    // The app bar button shows the progress and can't be pressed meanwhile.
    if (MophMedicineService().isSyncing) return;

    final result = await MophMedicineService().updateFromMophWebsite();

    if (!mounted) return;

    final message = result.describe(isArabic: _isArabic);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
                    appText(_isArabic).selectMedicine,
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
                    appText(_isArabic).confirmThatThisIsTheExact,
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
                    message: appText(_isArabic).manualSelectionIdentifiesThisDatabaseProduct,
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
                  appText(_isArabic).cancel,
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
                  appText(_isArabic).select,
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
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient:
            palette.pageGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildSearchArea(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MophSyncProgressLine(isArabic: _isArabic),
                ),

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 1180,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
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
                          appText(_isArabic).searchTheDatabaseAndSelectThe,
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

              GradientPageHeader(
                icon: Icons.medication_rounded,
                title: widget.selectionMode
                    ? appText(_isArabic).findTheExactProduct
                    : appText(_isArabic).lebaneseMedicineDatabase,
                subtitle: appText(_isArabic).searchByBrandOrActiveIngredient,
                actions: [
                  // White on the gradient instead of the theme's white button.
                  IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                    ),
                    child: MophSyncButton(
                      tooltip: appText(_isArabic).syncMophLebanonPrices,
                      color: Colors.white,
                      onPressed: _syncMophPrices,
                    ),
                  ),
                ],
                bottom: _buildSearchRow(palette),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(PharmaLensPalette palette) {
    return Builder(
                builder: (context) {
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
                      // Search as the user types, once they pause.
                      _typingDebounce?.cancel();
                      _typingDebounce = Timer(_typingDelay, () {
                        if (mounted && _searchController.text.trim() != _lastQuery) {
                          _search(reset: true);
                        }
                      });
                    },
                    decoration:
                    InputDecoration(
                      hintText: appText(_isArabic).exampleAugmentin625Mg,
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
                        appText(_isArabic).clearSearch,
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

                  // A square button beside the field (results also update
                  // as the user types).
                  final searchButton = SizedBox.square(
                    dimension: 48,
                    child: IconButton.filled(
                      tooltip: appText(_isArabic).searchMedicines,
                      onPressed: _isLoading ? null : () => _search(),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  );

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 8),
                      searchButton,
                    ],
                  );
                },
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
            ? appText(_isArabic).checkTheSpellingOrTryA
            : appText(_isArabic).enterABrandOrActiveIngredient,
        buttonText: canRetry
            ? appText(_isArabic).tryAgain
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
            ? appText(_isArabic).searchAndSelectTheExactProduct
            : appText(_isArabic).findMedicineInformation,
        subtitle: widget.selectionMode
            ? appText(_isArabic).reviewTheExactProductRecordBefore
            : appText(_isArabic).searchProductRecordsPricesReviewedInformation,
      );
    }

    if (_isLoading &&
        _results.isEmpty) {
      return _MessageState(
        icon:
        Icons.manage_search_rounded,
        title: appText(_isArabic).searchingTheMedicineDatabase,
        subtitle: appText(_isArabic).pleaseWaitAMoment,
      );
    }

    if (_results.isEmpty) {
      return _MessageState(
        icon:
        Icons.search_off_rounded,
        title: appText(_isArabic).noMedicinesFound,
        subtitle: appText(_isArabic).tryUsingOnlyPartOfThe,
      );
    }

    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final columns =
        constraints.maxWidth >= 1000 ? 2 : 1;

        final rowCount =
            (_results.length + columns - 1) ~/ columns;

        Widget card(int resultIndex) {
          final medicine =
          _results[resultIndex];

          return _MedicineCard(
            medicine:
            medicine,
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
          );
        }

        return RefreshIndicator(
          onRefresh: () {
            return _search(
              reset: true,
              forceRefresh: true,
            );
          },
          child:
          ListView.separated(
            controller: _scrollController,
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              96,
            ),
            itemCount:
            rowCount + 1 + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (
                context,
                index,
                ) {
              return SizedBox(
                height:
                index == 0 ? 12 : 10,
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
                      maxWidth: 1180,
                    ),
                    child:
                    _ResultsSummary(
                      query:
                      _lastQuery,
                      resultCount:
                      _totalMatches ?? _results.length,
                      isBrowsing:
                      _lastQuery.isEmpty,
                      isArabic:
                      _isArabic,
                    ),
                  ),
                );
              }

              if (index == rowCount + 1) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final first =
                  (index - 1) * columns;

              return Center(
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(
                    maxWidth: columns == 1 ? 820 : 1180,
                  ),
                  child: columns == 1
                      ? card(first)
                      : Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: card(first),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: first + 1 < _results.length
                              ? card(first + 1)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ++_searchRequestId;
    _typingDebounce?.cancel();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    this.isBrowsing = false,
  });

  final String query;

  /// Total matches (not just the loaded page).
  final int resultCount;
  final bool isArabic;
  final bool isBrowsing;

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
                isBrowsing
                    ? (appText(isArabic).medicinesInTheMophList(formatCount(resultCount)))
                    : (isArabic
                    ? '${formatCount(resultCount)} نتيجة مطابقة'
                    : '${formatCount(resultCount)} ${resultCount == 1 ? 'match' : 'matches'}'),
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
                  appText(isArabic).forText(query),
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
          appText(isArabic).tapForDetails,
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

/// One search result: name and ingredient, the official price beside them,
/// then strength, form and pack as small chips. The whole card opens the
/// medicine; "Select" appears only when picking a product for a scan.
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.selectionMode,
    required this.isArabic,
    required this.onOpenDetails,
    required this.onSelect,
  });

  final MedicinePrice medicine;
  final bool selectionMode;
  final bool isArabic;
  final VoidCallback onOpenDetails;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isDark = PharmaLensTheme.isDark(context);
    final radius = BorderRadius.circular(18);
    final generic = medicine.genericName?.trim() ?? '';
    final chips = <String>[
      if (medicine.hasStrength) medicine.displayStrength,
      if (medicine.hasDosageForm) medicine.displayDosageForm,
      if (medicine.hasPackSize) medicine.displayPackSize,
    ];

    Widget chip(String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Material(
      color: palette.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: palette.tealSurface, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_medicineIcon(medicine.dosageForm), color: PharmaLensColors.teal, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.brandName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: palette.textPrimary, fontSize: 15.5, height: 1.2, fontWeight: FontWeight.w900),
                        ),
                        if (generic.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            generic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The official price, the thing people look for first.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: PharmaLensColors.teal.withValues(alpha: isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      medicine.formattedPrice,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: PharmaLensColors.teal, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty || medicine.hasManufacturer) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [for (final value in chips) chip(value)],
                ),
              ],
              if (medicine.hasManufacturer) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.factory_outlined, size: 14, color: palette.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        medicine.displayManufacturer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(color: palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              if (selectionMode) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onOpenDetails,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(appText(isArabic).details),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onSelect,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                      icon: const Icon(Icons.touch_app_rounded, size: 18),
                      label: Text(appText(isArabic).selectMedicine3),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
            label: appText(isArabic).strength,
            value:
            medicine
                .displayStrength,
          ),

          _ConfirmationRow(
            label: appText(isArabic).form,
            value:
            medicine
                .displayDosageForm,
          ),

          _ConfirmationRow(
            label: appText(isArabic).pack,
            value:
            medicine
                .displayPackSize,
          ),

          _ConfirmationRow(
            label: appText(isArabic).manufacturer,
            value:
            medicine
                .displayManufacturer,
          ),

          _ConfirmationRow(
            label: appText(isArabic).price,
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