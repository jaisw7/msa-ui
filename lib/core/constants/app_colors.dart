/// App color palette - Robinhood-inspired with dark mode focus.
library;

import 'package:flutter/material.dart';

/// Brand and UI colors for the MSA app.
abstract final class AppColors {
  // Primary - Robinhood green
  static const Color primary = Color(0xFF00C805);
  static const Color primaryLight = Color(0xFF4ADE80);
  static const Color primaryDark = Color(0xFF16A34A);

  // Semantic colors
  static const Color profit = Color(0xFF00C805);  // Green for gains
  static const Color loss = Color(0xFFFF5252);    // Red for losses
  static const Color neutral = Color(0xFF9CA3AF); // Gray for unchanged

  // Background colors (dark mode first)
  static const Color backgroundDark = Color(0xFF0D0D0D);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color cardDark = Color(0xFF242424);

  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF3F4F6);

  // Text colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Chart colors
  static const Color chartLine = primary;
  static const Color chartFill = Color(0x3300C805);
  static const Color chartGrid = Color(0xFF374151);

  // Accent colors for signals
  static const Color buySignal = Color(0xFF00C805);
  static const Color sellSignal = Color(0xFFFF5252);
  static const Color holdSignal = Color(0xFFFBBF24);
}
