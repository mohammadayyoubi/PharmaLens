import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';

/// A Lebanese emergency or support line.
class EmergencyNumber {
  const EmergencyNumber(this.number, this.icon, this.color, this.label);

  final String number;
  final IconData icon;
  final Color color;
  final String Function(AppLocalizations text) label;
}

/// Lebanon's main emergency and health lines, the ambulance first.
final List<EmergencyNumber> emergencyNumbers = <EmergencyNumber>[
  EmergencyNumber('140', Icons.emergency_rounded, PharmaLensColors.danger, (t) => t.redCrossAmbulance),
  EmergencyNumber('125', Icons.shield_outlined, PharmaLensColors.warning, (t) => t.civilDefense),
  EmergencyNumber('112', Icons.local_police_outlined, PharmaLensColors.accentBlue, (t) => t.policeIsf),
  EmergencyNumber('175', Icons.local_fire_department_outlined, PharmaLensColors.accentCoral, (t) => t.fireBrigade),
  EmergencyNumber('1564', Icons.favorite_border_rounded, PharmaLensColors.accentViolet, (t) => t.embraceLifeline),
  EmergencyNumber('1214', Icons.local_hospital_outlined, PharmaLensColors.teal, (t) => t.mophHotline),
];

Future<void> callEmergencyNumber(BuildContext context, String number) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = appText(Localizations.localeOf(context).languageCode == 'ar').couldNotOpenThePhoneApplication;
  try {
    final opened = await launchUrl(Uri(scheme: 'tel', path: number), mode: LaunchMode.externalApplication);
    if (!opened) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  } catch (error) {
    if (kDebugMode) debugPrint('Could not call $number: $error');
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// The numbers as a bottom sheet (from Settings or the home card).
Future<void> showEmergencyNumbersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final isArabic = Localizations.localeOf(sheetContext).languageCode == 'ar';
      final palette = PharmaLensTheme.paletteOf(sheetContext);
      final text = appText(isArabic);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Text(text.emergencyNumbers, style: TextStyle(color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(text.emergencyNumbersSubtitle, style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            for (final entry in emergencyNumbers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NumberTile(entry: entry, isArabic: isArabic),
              ),
          ],
        ),
      );
    },
  );
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.entry, required this.isArabic});

  final EmergencyNumber entry;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);

    return Material(
      color: palette.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => callEmergencyNumber(context, entry.number),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: entry.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                child: Icon(entry.icon, color: entry.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label(text),
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: text.callNumber(entry.number),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: entry.color, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        entry.number,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home card: the four emergency lines, two per row, each one tap to call;
/// "All" opens the full list.
class EmergencyNumbersCard extends StatelessWidget {
  const EmergencyNumbersCard({super.key, required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);
    final shown = emergencyNumbers.take(4).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: palette.dangerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PharmaLensColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sos_rounded, color: PharmaLensColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.emergencyNumbers,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              TextButton(onPressed: () => showEmergencyNumbersSheet(context), child: Text(text.all)),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < shown.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CompactNumber(entry: shown[i], isArabic: isArabic)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < shown.length
                        ? _CompactNumber(entry: shown[i + 1], isArabic: isArabic)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line in the home card: icon, name and number; tap to call.
class _CompactNumber extends StatelessWidget {
  const _CompactNumber({required this.entry, required this.isArabic});

  final EmergencyNumber entry;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);

    return Semantics(
      button: true,
      label: '${entry.label(text)}, ${text.callNumber(entry.number)}',
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => callEmergencyNumber(context, entry.number),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: entry.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(entry.icon, color: entry.color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.number,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: entry.color, fontWeight: FontWeight.w900, fontSize: 16, height: 1.1),
                        ),
                        Text(
                          entry.label(text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
