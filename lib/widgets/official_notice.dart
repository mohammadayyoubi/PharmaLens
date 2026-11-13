import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';

/// PharmaLens is an individual initiative, not the Ministry of Public
/// Health's app; its prices come from the official MOPH website. Shown on
/// first launch (onboarding, or once after updating) and in About.
class OfficialNoticeCard extends StatelessWidget {
  const OfficialNoticeCard({super.key, required this.isArabic, this.onDark = false});

  final bool isArabic;

  /// White text, for the onboarding gradient.
  final bool onDark;

  static const String seenKey = 'pharmalens_official_notice_v1';

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(seenKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);
    final titleColor = onDark ? Colors.white : palette.textPrimary;
    final bodyColor = onDark ? Colors.white.withValues(alpha: 0.85) : palette.textSecondary;

    Widget point(IconData icon, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: onDark ? PharmaLensColors.brightCyan : PharmaLensColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value, style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.10) : PharmaLensColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: onDark ? Colors.white.withValues(alpha: 0.18) : PharmaLensColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: onDark ? PharmaLensColors.brightCyan : PharmaLensColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.notAnOfficialMophApp,
                  style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          point(Icons.person_outline_rounded, text.notAnOfficialMophAppBody),
          point(Icons.verified_outlined, text.pricesComeFromTheOfficialMophWebsite),
          point(Icons.smart_toy_outlined, text.aiNeverReplacesYourDoctor),
        ],
      ),
    );
  }
}

/// Whether this launch already showed its notice (see [showStartupNotice]).
/// Tests that pump the shell set it to true.
bool startupNoticeShown = false;

/// Shown once per launch, when the home page first appears: people who
/// finished onboarding before the "not the MOPH app" notice existed see that
/// notice (it includes the AI warning); everyone else acknowledges that AI
/// can make mistakes.
Future<void> showStartupNotice(BuildContext context) async {
  if (startupNoticeShown) return;
  startupNoticeShown = true;

  var officialSeen = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    officialSeen = prefs.getBool(OfficialNoticeCard.seenKey) ?? false;
  } catch (_) {}
  if (!context.mounted) return;

  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final text = appText(isArabic);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final palette = PharmaLensTheme.paletteOf(dialogContext);
      return AlertDialog(
        icon: officialSeen
            ? Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(gradient: PharmaLensGradients.primary, borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 28),
              )
            : null,
        title: Text(officialSeen ? text.beforeYouStart : text.importantNotice),
        content: SingleChildScrollView(
          child: officialSeen
              ? Text(
                  text.aiAcknowledgementBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, height: 1.5, fontWeight: FontWeight.w600),
                )
              : OfficialNoticeCard(isArabic: isArabic),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(text.iUnderstand),
          ),
        ],
      );
    },
  );
  if (!officialSeen) await OfficialNoticeCard.markSeen();
}
