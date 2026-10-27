import 'package:flutter/material.dart';

import '../services/medication_safety_service.dart';
import '../theme/pharmalens_theme.dart';

/// One medication-safety warning, styled by priority.
class SafetyAlertCard extends StatelessWidget {
  const SafetyAlertCard({super.key, required this.alert, required this.isArabic});

  final SafetyAlert alert;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final color = alert.isHighPriority ? PharmaLensColors.danger : PharmaLensColors.warning;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: alert.isHighPriority ? palette.dangerSurface : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              alert.type == SafetyAlertType.allergy ? Icons.no_food_rounded : Icons.warning_amber_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title(isArabic: isArabic), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    alert.message(isArabic: isArabic),
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
