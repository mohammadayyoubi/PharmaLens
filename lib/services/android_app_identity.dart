import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Headers for Google API calls from the Android app.
///
/// The Gemini and Places keys ship inside the app, so anyone can extract
/// them. In Google Cloud each key can be restricted to "Android apps"
/// (package `com.techwraplb.pharmalens` and the Play app signing SHA-1);
/// for direct HTTPS calls Google checks these two headers to accept them.
/// Empty on other platforms, and if they cannot be read.
class AndroidAppIdentity {
  const AndroidAppIdentity._();

  static const MethodChannel _channel = MethodChannel('pharmalens/system');

  static Map<String, String>? _headers;

  static Future<Map<String, String>> headers() async {
    final known = _headers;
    if (known != null) return known;
    // The real OS, not defaultTargetPlatform: widget tests report Android,
    // and a channel call there never answers inside the fake clock.
    if (kIsWeb || !Platform.isAndroid) return _headers = const <String, String>{};
    try {
      final info = await _channel.invokeMapMethod<String, String>('appIdentity');
      final package = info?['package'] ?? '';
      final sha1 = info?['sha1'] ?? '';
      return _headers = package.isEmpty || sha1.isEmpty
          ? const <String, String>{}
          : <String, String>{'X-Android-Package': package, 'X-Android-Cert': sha1};
    } catch (_) {
      // Tests and background isolates have no channel; try again next time.
      return const <String, String>{};
    }
  }
}
