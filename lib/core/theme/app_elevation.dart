import 'package:flutter/material.dart';

/// Centralized elevation and shadow tokens for the EduRise design system.
///
/// Designed with subtle, multi-layered shadows to feel modern and premium
/// without looking muddy on Android displays.
class AppElevation {
  AppElevation._();

  /// Flat (no shadow)
  static const List<BoxShadow> none = [];

  /// Subtle elevation for hovering cards or subtle chips
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Standard card elevation in light mode
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  /// Raised interactive elements, dropdowns, floating banners
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  /// Modals, bottom sheets, and alerts
  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x1F0F172A),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 64,
      offset: Offset(0, 24),
    ),
  ];

  // Dark mode elevation tokens (lighter tint / subtle ambient glow)
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> floatingDark = [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> dialogDark = [
    BoxShadow(
      color: Color(0x77000000),
      blurRadius: 36,
      offset: Offset(0, 16),
    ),
  ];
}
