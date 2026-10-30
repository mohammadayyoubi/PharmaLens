import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _arabic = lookupAppLocalizations(const Locale('ar'));

/// The app's strings in Arabic or English, for code that already knows which
/// language it shows (`appText(isArabic).alarmSound`). Works without a
/// BuildContext, so services, models and notifications use it too. Widgets
/// with a context can also use `context.l10n`.
AppLocalizations appText(bool isArabic) => isArabic ? _arabic : _english;
