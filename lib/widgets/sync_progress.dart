import 'package:flutter/material.dart';

import '../services/moph_medicine_service.dart';
import '../theme/pharmalens_theme.dart';

/// "Checking for new data… 42%" with a thin bar, while the MOPH list loads
/// or syncs. Takes no space when nothing is happening.
class MophSyncProgressLine extends StatelessWidget {
  const MophSyncProgressLine({super.key, required this.isArabic, this.color});

  final bool isArabic;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final accent = color ?? PharmaLensColors.teal;

    return ValueListenableBuilder<MophSyncProgress>(
      valueListenable: MophMedicineService().progress,
      builder: (context, progress, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: AlignmentDirectional.topStart,
          child: !progress.busy
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              progress.label(isArabic: isArabic),
                              maxLines: 2,
                              style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${progress.percent}%',
                            style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        // Determinate on purpose: an endless animation would
                        // keep the page from settling.
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: progress.fraction),
                          duration: const Duration(milliseconds: 250),
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            color: accent,
                            backgroundColor: accent.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Sync icon that turns into a small percentage ring while a sync runs and
/// can't be pressed again until it finishes.
class MophSyncButton extends StatelessWidget {
  const MophSyncButton({super.key, required this.onPressed, required this.tooltip, this.color});

  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final moph = MophMedicineService();
    final accent = color ?? PharmaLensColors.teal;

    return ValueListenableBuilder<MophSyncProgress>(
      valueListenable: moph.progress,
      builder: (context, progress, _) {
        final busy = progress.busy || moph.isSyncing;
        if (!busy) {
          return IconButton(
            tooltip: tooltip,
            icon: Icon(Icons.sync_rounded, color: accent),
            onPressed: onPressed,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.fraction == 0 ? 0.02 : progress.fraction,
                  strokeWidth: 2.5,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.15),
                ),
                Text(
                  '${progress.percent}',
                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small "Checking for new data… 35%" pill for the top of the home page,
/// so the background check is visible without scrolling. Takes no space
/// when nothing is happening.
class MophSyncChip extends StatelessWidget {
  const MophSyncChip({super.key, required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return ValueListenableBuilder<MophSyncProgress>(
      valueListenable: MophMedicineService().progress,
      builder: (context, progress, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !progress.busy
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey<String>('sync-chip'),
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 10, 5),
                  decoration: BoxDecoration(
                    color: palette.tealSurface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: PharmaLensColors.teal.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          value: progress.fraction == 0 ? 0.02 : progress.fraction,
                          strokeWidth: 2,
                          color: PharmaLensColors.teal,
                          backgroundColor: PharmaLensColors.teal.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${progress.label(isArabic: isArabic)} ${progress.percent}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
