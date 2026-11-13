import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';

/// "AI can make mistakes" notice, shown wherever the app shows something an
/// AI produced (prescription readings, directions, summaries).
///
/// [message] defaults to the short notice; pass a longer one where the AI
/// did more (e.g. reading a whole prescription).
class AiNotice extends StatelessWidget {
  const AiNotice({super.key, required this.isArabic, this.message, this.onDark = false, this.compact = false});

  final bool isArabic;
  final String? message;

  /// Light text for gradient or dark cards.
  final bool onDark;

  /// One quiet line instead of a tinted box.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = message ?? appText(isArabic).aiCanMakeMistakesAskYourPharmacist;
    final color = onDark ? Colors.white.withValues(alpha: 0.78) : palette.textSecondary;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.smart_toy_outlined, size: compact ? 15 : 18, color: onDark ? PharmaLensColors.brightCyan : PharmaLensColors.info),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: compact ? 11.5 : 12.5, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    if (compact) return Semantics(container: true, child: row);

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.08) : PharmaLensColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onDark ? Colors.white.withValues(alpha: 0.16) : PharmaLensColors.info.withValues(alpha: 0.28),
          ),
        ),
        child: row,
      ),
    );
  }
}
