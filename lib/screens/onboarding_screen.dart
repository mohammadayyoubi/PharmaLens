import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_settings_scope.dart';
import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/reminder_setup_sheet.dart';

/// First launch: what the app does, how data is handled (the prescription
/// photo is read by Google's Gemini AI), and the reminder permissions.
/// Every step can be skipped; reminder setup is offered again later.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const String seenKey = 'pharmalens_onboarding_v1';

  static Future<bool> seen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(seenKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.seenKey, true);
    } catch (_) {}
    widget.onDone();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = PharmaLensAppScope.maybeOf(context);

    final pages = <Widget>[
      _Page(
        image: 'assets/branding/app_icon.png',
        imageSize: 132,
        title: appText(_isArabic).welcomeToPharmalens,
        body: appText(_isArabic).yourMedicineSafetyAssistantForLebanon,
        points: [
          (Icons.document_scanner_outlined, appText(_isArabic).readHandwrittenPrescriptions),
          (Icons.price_check_rounded, appText(_isArabic).officialMophPricesAndCheaperEquivalents),
          (Icons.health_and_safety_outlined, appText(_isArabic).allergyAndDuplicateChecks),
          (Icons.alarm_rounded, appText(_isArabic).remindersAndAlarmsForEveryDose),
        ],
      ),
      _Page(
        image: 'assets/images/scan_illustration.png',
        imageSize: 220,
        title: appText(_isArabic).yourDataYourPhone,
        body: appText(_isArabic).toReadAPrescriptionItsPhoto,
        points: [
          (Icons.verified_outlined, appText(_isArabic).medicinesAreCheckedAgainstTheOfficial),
          (Icons.smart_toy_outlined, appText(_isArabic).aiCanMakeMistakesAlwaysConfirm),
          (Icons.delete_outline_rounded, appText(_isArabic).deleteAnyScanAtAnyTime),
        ],
      ),
      _Page(
        image: 'assets/images/reminder_illustration.png',
        imageSize: 190,
        title: appText(_isArabic).neverMissADose,
        body: appText(_isArabic).remindersCanRingLikeAnAlarm,
        action: FilledButton.icon(
          onPressed: () => showReminderSetupSheet(context),
          icon: const Icon(Icons.settings_suggest_rounded),
          label: Text(appText(_isArabic).setUpReminders),
        ),
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: PharmaLensColors.brandGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    if (scope != null)
                      TextButton.icon(
                        onPressed: () => scope.onLocaleChanged(Locale(_isArabic ? 'en' : 'ar')),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.translate_rounded, size: 18),
                        label: Text(_isArabic ? 'English' : 'العربية'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: Text(appText(_isArabic).skip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Row(
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          width: i == _page ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? PharmaLensColors.brightCyan : Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: PharmaLensColors.deepNavy,
                          minimumSize: const Size(140, 52),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        child: Text(
                          _page == 1
                              ? appText(_isArabic).iUnderstand
                              : _page == 2
                                  ? appText(_isArabic).start
                                  : appText(_isArabic).next,
                        ),
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

class _Page extends StatelessWidget {
  const _Page({
    required this.image,
    required this.imageSize,
    required this.title,
    required this.body,
    this.points = const [],
    this.action,
  });

  final String image;
  final double imageSize;
  final String title;
  final String body;
  final List<(IconData, String)> points;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 560;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Image.asset(image, width: short ? imageSize * 0.7 : imageSize, height: short ? imageSize * 0.7 : imageSize, fit: BoxFit.contain),
                  ),
                  SizedBox(height: short ? 16 : 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 15, height: 1.55, fontWeight: FontWeight.w600),
                  ),
                  if (points.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                              child: Icon(point.$1, color: PharmaLensColors.brightCyan, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(point.$2, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 22),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
