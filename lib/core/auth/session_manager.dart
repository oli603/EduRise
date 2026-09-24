import 'package:flutter/foundation.dart';

/// Central authority for managing authenticated user session boundaries,
/// session tokens, lifecycle transitions, and memory resets across EduRise.
///
/// Ensures that when an account logs out or switches:
/// 1. In-memory caches belonging to the previous UID are immediately cleared.
/// 2. Asynchronous operations in-flight from previous sessions are safely discarded.
/// 3. All user-scoped stores are notified to reload or reset their state.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  static SessionManager get instance => _instance;

  static String? _currentUid;
  static int _sessionEpoch = 0;
  static final List<VoidCallback> _sessionResetListeners = [];

  /// The authoritative UID of the active session.
  static String? get currentUid => _currentUid;

  /// Monotonically increasing session epoch to invalidate stale async operations.
  static int get sessionEpoch => _sessionEpoch;

  /// Registers a callback to be executed whenever the session is reset on logout/switch.
  static void registerResetListener(VoidCallback listener) {
    if (!_sessionResetListeners.contains(listener)) {
      _sessionResetListeners.add(listener);
    }
  }

  /// Unregisters a previously registered reset listener.
  static void unregisterResetListener(VoidCallback listener) {
    _sessionResetListeners.remove(listener);
  }

  /// Initializes a new session for the given [uid].
  static void startSession(String uid) {
    if (_currentUid != uid) {
      _currentUid = uid;
      _sessionEpoch++;
      debugPrint('SessionManager: Started session for UID: $uid (Epoch: $_sessionEpoch)');
    }
  }

  /// Validates whether an async operation initiated under [capturedUid] and [capturedEpoch]
  /// is still valid and belongs to the currently active session.
  static bool isSessionValid({required String? capturedUid, required int capturedEpoch}) {
    if (capturedUid == null || capturedUid.isEmpty) return false;
    return _currentUid == capturedUid && _sessionEpoch == capturedEpoch;
  }

  /// Authoritative teardown of active user session on logout or account switch.
  static void resetSession() {
    debugPrint('SessionManager: Resetting active session for UID: $_currentUid (Prior Epoch: $_sessionEpoch)');
    _currentUid = null;
    _sessionEpoch++;

    // Execute all registered reset listeners
    for (final listener in List<VoidCallback>.from(_sessionResetListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('SessionManager: Error in reset listener: $e');
      }
    }
  }

  /// Visible for unit testing
  @visibleForTesting
  static void resetForTesting() {
    _currentUid = null;
    _sessionEpoch = 0;
    _sessionResetListeners.clear();
  }
}
