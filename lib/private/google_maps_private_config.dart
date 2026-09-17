class GoogleMapsPrivateConfig {
  const GoogleMapsPrivateConfig._();

  /*
   * ضع هنا مفتاح:
   * PharmaLens Places Development Key
   *
   * يجب أن يكون مفعّلًا له:
   * Places API (New)
   *
   * لا تضع هنا مفتاح Maps SDK for Android.
   */
  static const String googlePlacesApiKey =
      'PASTE_YOUR_NEW_PLACES_API_KEY_HERE';

  /*
   * أسماء إضافية لدعم أي ملفات قديمة داخل المشروع
   * ما زالت تستخدم googleMapsApiKey.
   */
  static const String googleMapsApiKey = googlePlacesApiKey;

  /*
   * الكود الحالي لا يحتاج Directions API.
   * زر الاتجاهات يفتح Google Maps بواسطة رابط.
   * أبقينا الاسم فقط لتجنب أخطاء الملفات القديمة.
   */
  static const String googleDirectionsApiKey = googlePlacesApiKey;

  static bool get hasValidPlacesApiKey {
    final key = googlePlacesApiKey.trim();

    return key.isNotEmpty &&
        key != 'PASTE_YOUR_NEW_PLACES_API_KEY_HERE' &&
        key != 'PASTE_YOUR_EXISTING_PLACES_API_KEY_HERE' &&
        key != 'YOUR_PLACES_API_KEY' &&
        key != 'YOUR_API_KEY_HERE';
  }

  static bool get hasValidDirectionsApiKey {
    return hasValidPlacesApiKey;
  }
}
