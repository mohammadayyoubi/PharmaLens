// Copy to api_keys.dart (git-ignored). Keys can also be passed at build time
// with --dart-define=GEMINI_API_KEY=... (or GEMINI_API_KEYS=a,b).
// Restrict the key to the Generative Language API in Google Cloud.
class GeminiPrivateConfig {
  static const List<String> geminiApiKeys = [
    // 'YOUR_API_KEY_HERE',
  ];

  static const List<String> geminiModels = [
    // Fastest first (measured 2-4 s per prescription).
    'gemini-3.5-flash-lite',

    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-flash-latest',
  ];
}
