// Copy to api_keys.dart (git-ignored). Keys can also be passed at build time
// with --dart-define=GEMINI_API_KEY=... (or GEMINI_API_KEYS=a,b).
// Restrict the key to the Generative Language API in Google Cloud.
class GeminiPrivateConfig {
  static const List<String> geminiApiKeys = [
    // 'YOUR_API_KEY_HERE',
  ];

  static const List<String> geminiModels = [
    // Strongest first. When its quota is used up (HTTP 429) the app moves
    // on to the next model automatically, so the Flash-Lite models keep
    // scans working on the free tier (Flash allows far fewer requests a day).
    'gemini-3.5-flash',

    // Fast fallbacks with a larger free daily quota.
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',

    // Google alias for the latest Flash.
    'gemini-flash-latest',
  ];
}
