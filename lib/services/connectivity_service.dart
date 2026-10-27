import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network connection, so the UI can explain
/// which features still work offline (medicine search, doctors, history).
class ConnectivityService extends ValueNotifier<bool> {
  ConnectivityService._internal() : super(true);

  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => value;

  Future<void> start() async {
    if (_subscription != null) return;

    final connectivity = Connectivity();

    try {
      value = _hasConnection(await connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('ConnectivityService: initial check failed: $error');
    }

    _subscription = connectivity.onConnectivityChanged.listen(
      (results) => value = _hasConnection(results),
      onError: (Object error) => debugPrint('ConnectivityService: $error'),
    );
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
