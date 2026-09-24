import 'package:flutter/material.dart';

/// Centralized motion tokens for the EduRise design system.
///
/// Fast, intentional, and responsive animations designed to enhance user
/// feedback without delaying tasks or degrading performance on mid-range Android devices.
class AppMotion {
  AppMotion._();

  // ============================================================
  // DURATIONS
  // ============================================================
  /// Micro-interactions, icon state flips, button press responses
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions: cards expanding, sheets opening, tab switches
  static const Duration normal = Duration(milliseconds: 250);

  /// Moderate transitions: bottom sheet reveal, dialog appearance
  static const Duration medium = Duration(milliseconds: 350);

  /// Complex choreographed transitions: page transitions, loading states
  static const Duration slow = Duration(milliseconds: 500);

  // ============================================================
  // EASING CURVES
  // ============================================================
  /// Standard smooth cubic curve for elements remaining on screen
  static const Curve standard = Curves.easeInOutCubic;

  /// Emphasized deceleration for elements entering the screen
  static const Curve enter = Curves.easeOutCubic;

  /// Acceleration for elements exiting the screen
  static const Curve exit = Curves.easeInCubic;

  /// Snappy spring-like feedback for micro-interactions
  static const Curve bouncy = Curves.easeOutBack;
}
