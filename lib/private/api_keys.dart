class GeminiPrivateConfig {
  static const List<String> geminiApiKeys = [
    'YOUR_GEMINI_API_KEY_HERE',
  ];

  static const List<String> geminiModels = [
    // Fastest first.
    'gemini-3.1-flash-lite',

    // Stronger fallback.
    'gemini-3.5-flash',

    // Google alias for latest Flash.
    'gemini-flash-latest',
  ];
}
