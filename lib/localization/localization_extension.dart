import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this);
  }

  bool get isArabic {
    return Localizations.localeOf(this)
        .languageCode
        .toLowerCase() ==
        'ar';
  }

  bool get isRtl {
    return Directionality.of(this) == TextDirection.rtl;
  }
}

/// `tr.isArabic` for screens that hold an [AppLocalizations] instance.
///
/// All UI strings come from the generated getters (`context.l10n.settings`)
/// or from inline en/ar pairs next to the widget that shows them.
extension AppLocalizationsCompatibility on AppLocalizations {
  bool get isArabic {
    return localeName.toLowerCase().startsWith('ar');
  }
}
