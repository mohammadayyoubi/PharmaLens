class GeminiPrivateConfig {
  static const List<String> geminiApiKeys = [
    'AQ.Ab8RN6K4T47WRKGops6HEmHxzCV5dBZ26MRGq4TzEgjrZTg0uQ',
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
