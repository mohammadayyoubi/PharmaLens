/// Consonant "skeletons" that let a brand typed in Arabic letters find its
/// Latin MOPH name: "بنادول" and "Panadol" both become "bndl", "اوغمنتين"
/// and "Augmentin" both "gmntn".
///
/// Vowels are dropped (Arabic usually does not write them), and letters that
/// Arabic writes with one character are merged: p/b, v/f, c/k/q, g/j, x/ks.
class PhoneticSkeleton {
  const PhoneticSkeleton._();

  static final RegExp _arabic = RegExp(r'[؀-ۿ]');

  static bool hasArabic(String text) => _arabic.hasMatch(text);

  static const Map<String, String> _arabicLetters = <String, String>{
    'ب': 'b', 'پ': 'b', 'ت': 't', 'ث': 't', 'ج': 'g', 'ح': 'h', 'خ': 'k',
    'د': 'd', 'ذ': 'd', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 's', 'ص': 's',
    'ض': 'd', 'ط': 't', 'ظ': 'z', 'غ': 'g', 'ف': 'f', 'ڤ': 'f', 'ق': 'k',
    'ك': 'k', 'گ': 'g', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h',
  };

  /// Skeleton of Arabic-script text.
  static String ofArabic(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final letter = _arabicLetters[String.fromCharCode(rune)];
      if (letter != null) out.write(letter);
      // Long vowels, hamza, ta marbuta and diacritics carry no consonant.
    }
    return _collapse(out.toString());
  }

  /// Skeleton of Latin-script text.
  static String ofLatin(String text) {
    var value = text.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    value = value
        .replaceAll('ph', 'f')
        .replaceAll('ch', 'k')
        .replaceAll('sh', 's')
        .replaceAll('th', 't')
        .replaceAll('kh', 'k')
        .replaceAll('gh', 'g')
        .replaceAll('qu', 'k')
        .replaceAll('x', 'ks')
        .replaceAllMapped(RegExp('c(?=[eiy])'), (_) => 's')
        .replaceAll('c', 'k')
        .replaceAll('q', 'k')
        .replaceAll('p', 'b')
        .replaceAll('v', 'f')
        .replaceAll('j', 'g')
        .replaceAll(RegExp('[aeiouwy]'), '');
    return _collapse(value);
  }

  static String _collapse(String value) => value.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
}
