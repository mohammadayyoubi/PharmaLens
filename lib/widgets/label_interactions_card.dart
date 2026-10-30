import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../services/label_interaction_service.dart';
import '../theme/pharmalens_theme.dart';

/// On request, reads the labels of the confirmed medicines and lists where
/// one label names another prescribed medicine. Loading a label can take a
/// few seconds the first time, so it does not start on its own.
class LabelInteractionsCard extends StatefulWidget {
  const LabelInteractionsCard({super.key, required this.products, required this.isArabic});

  final List<MedicinePrice> products;
  final bool isArabic;

  @override
  State<LabelInteractionsCard> createState() => _LabelInteractionsCardState();
}

class _LabelInteractionsCardState extends State<LabelInteractionsCard> {
  Future<List<LabelInteraction>>? _future;

  @override
  void didUpdateWidget(covariant LabelInteractionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.products.map((p) => p.medicineId).toSet();
    final after = widget.products.map((p) => p.medicineId).toSet();
    if (before.length != after.length || !before.containsAll(after)) _future = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.length < 2) return const SizedBox.shrink();
    final palette = PharmaLensTheme.paletteOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: _future == null
          ? Row(
              children: [
                const Icon(Icons.compare_arrows_rounded, color: PharmaLensColors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    appText(widget.isArabic).checkWhatTheMedicineLabelsSay,
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => setState(() {
                    _future = const LabelInteractionService().check(widget.products, isArabic: widget.isArabic);
                  }),
                  child: Text(appText(widget.isArabic).check),
                ),
              ],
            )
          : FutureBuilder<List<LabelInteraction>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Row(
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appText(widget.isArabic).readingTheMedicineLabels,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  );
                }
                final found = snapshot.data ?? const <LabelInteraction>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          found.isEmpty ? Icons.fact_check_outlined : Icons.warning_amber_rounded,
                          color: found.isEmpty ? PharmaLensColors.teal : PharmaLensColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            found.isEmpty
                                ? appText(widget.isArabic).theLabelsDoNotMentionEach
                                : appText(widget.isArabic).theLabelsMentionEachOther,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    for (final item in found) ...[
                      const SizedBox(height: 10),
                      Text(
                        appText(widget.isArabic).labelAbout(item.labelOf, item.mentions),
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(item.line, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45)),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      appText(widget.isArabic).fromUSFdaLabelsFor,
                      style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
