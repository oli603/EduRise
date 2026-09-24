import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../auth/role_service.dart';
import '../offline/connectivity_service.dart';

/// Centralized service managing system-wide Maintenance Mode.
///
/// Listens to live Firestore updates on `system_settings/general` and exposes
/// change notifications for [GoRouter] and the application shell.
/// Strictly distinguishes between students (blocked when active) and
/// authorized administrators/founders (bypassed so they can configure system).
class MaintenanceService extends ChangeNotifier {
  static final MaintenanceService _instance = MaintenanceService._internal();
  factory MaintenanceService() => _instance;
  static MaintenanceService get instance => _instance;

  MaintenanceService._internal() {
    _initListener();
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  bool _isMaintenanceActive = false;
  String _maintenanceMessage = '';
  bool _isInitialized = false;
  bool _isMocked = false;

  /// Whether maintenance mode is globally enabled in system settings.
  /// If device is completely offline, stale cached maintenance state will not lock out students.
  bool get isMaintenanceActive {
    if (_isMocked) return _isMaintenanceActive;
    try {
      if (!ConnectivityService().isOnline) {
        return false;
      }
    } catch (_) {}
    return _isMaintenanceActive;
  }

  /// Custom maintenance announcement message configured by administrators.
  String get maintenanceMessage => _maintenanceMessage;

  /// Whether the initial read from Firestore has completed.
  bool get isInitialized => _isInitialized;

  bool get _hasFirebase {
    if (kIsWeb == false && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _initListener() {
    if (!_hasFirebase) {
      _isInitialized = true;
      return;
    }

    try {
      _subscription = _firestore
          .collection('system_settings')
          .doc('general')
          .snapshots()
          .listen(
        (doc) {
          if (!doc.exists || doc.data() == null) {
            _updateState(active: false, message: '');
            return;
          }

          final data = doc.data()!;
          final active = data['maintenanceMode'] as bool? ?? false;
          final banner = data['announcementBanner'] as String? ?? '';
          _updateState(active: active, message: banner);
        },
        onError: (e) {
          debugPrint('MaintenanceService stream error: $e');
          // In offline mode or network errors, default to false so students are not locked out
          _updateState(active: false, message: '');
        },
      );
    } catch (e) {
      debugPrint('Error initializing MaintenanceService listener: $e');
      _isInitialized = true;
    }
  }

  void _updateState({required bool active, required String message}) {
    final changed = _isMaintenanceActive != active || _maintenanceMessage != message;
    _isMaintenanceActive = active;
    _maintenanceMessage = message;
    _isInitialized = true;
    if (changed) {
      notifyListeners();
    }
  }

  /// Manually re-checks the live Firestore document and returns true if maintenance is active.
  Future<bool> checkMaintenanceNow() async {
    if (!_hasFirebase) {
      return _isMaintenanceActive;
    }

    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('general')
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists && doc.data() != null) {
        final active = doc.data()!['maintenanceMode'] as bool? ?? false;
        final banner = doc.data()!['announcementBanner'] as String? ?? '';
        _updateState(active: active, message: banner);
        return active;
      }
    } catch (e) {
      debugPrint('Error checking maintenance mode directly: $e');
    }
    return _isMaintenanceActive;
  }

  /// Determines whether the current authenticated user should be blocked by maintenance mode.
  /// Administrators and founders are always bypassed.
  Future<bool> shouldBlockCurrentUser() async {
    if (!_isMaintenanceActive) return false;

    try {
      final isAuthorizedAdmin = await RoleService.isCurrentAuthorizedAdmin();
      if (isAuthorizedAdmin) {
        return false; // Admin bypass!
      }
    } catch (_) {}

    return true; // Student / unauthenticated blocked!
  }

  /// Test-only injection helper to simulate maintenance state during automated tests.
  @visibleForTesting
  void setMockState({required bool active, String message = ''}) {
    _isMocked = true;
    _updateState(active: active, message: message);
  }

  /// Resets mock testing state back to real environment behavior.
  @visibleForTesting
  void resetMockState() {
    _isMocked = false;
    _updateState(active: false, message: '');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
