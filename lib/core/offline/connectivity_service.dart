import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _timer;
  final StreamController<bool> _connectivityStreamController =
      StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  Stream<bool> get onConnectivityChanged => _connectivityStreamController.stream;

  /// Performs a fast DNS / TCP probe to verify actual internet reachability.
  Future<bool> checkConnectivity({String host = 'firestore.googleapis.com'}) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 4),
      );
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(connected);
      return connected;
    } on SocketException catch (_) {
      _updateStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateStatus(false);
      return false;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void _updateStatus(bool connected) {
    if (_isOnline != connected) {
      _isOnline = connected;
      _connectivityStreamController.add(_isOnline);
      debugPrint('ConnectivityService: Connection status changed -> isOnline: $_isOnline');
    }
  }

  @visibleForTesting
  void setOnlineStatusForTesting(bool connected) {
    _updateStatus(connected);
  }

  /// Start background periodic connectivity monitoring (e.g. every 15 seconds).
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    checkConnectivity();
    _timer = Timer.periodic(interval, (_) => checkConnectivity());
  }

  /// Stop background periodic monitoring.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopMonitoring();
    _connectivityStreamController.close();
  }
}
