import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_info.dart';
import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/markdown_text.dart';
import '../widgets/responsive.dart';

/// The privacy policy, readable offline (assets/legal/privacy_policy_*.md).
/// docs/web/pharmalens/privacy-policy.html is the same text for the web address Google
/// Play links to (AppInfo.privacyPolicyUrl).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<String> _load(bool isArabic) =>
      rootBundle.loadString('assets/legal/privacy_policy_${isArabic ? 'ar' : 'en'}.md');

  Future<void> _openOnline(BuildContext context) async {
    try {
      await launchUrl(Uri.parse(AppInfo.privacyPolicyUrl), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (kDebugMode) debugPrint('Could not open the privacy policy: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(isArabic);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _load(isArabic),
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: PageFrame(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPageHeader(
                      icon: Icons.privacy_tip_rounded,
                      title: text.privacyPolicy,
                      subtitle: text.privacyPolicySubtitle,
                      actions: [
                        GradientPageHeader.action(
                          icon: Icons.open_in_new_rounded,
                          tooltip: text.readOnline,
                          onPressed: () => _openOnline(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!snapshot.hasData)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      SurfaceCard(
                        child: MarkdownText(
                          snapshot.data!,
                          accentColor: PharmaLensColors.teal,
                          style: TextStyle(color: palette.textPrimary, fontSize: 14, height: 1.55),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
