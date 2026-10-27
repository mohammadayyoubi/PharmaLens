import 'package:intl/intl.dart';

final NumberFormat _countFormat = NumberFormat.decimalPattern('en');

/// 18692 -> "18,692". Western digits in both languages, as used in Lebanon.
String formatCount(num value) => _countFormat.format(value);
