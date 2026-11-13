import 'package:flutter/material.dart';

/// Claimly Material 3 Design Tokens and Color Palette.
class AppColors {
  AppColors._();

  // Brand Primary & Secondary
  static const Color primary = Color(0xFF1E40AF); // Deep Indigo
  static const Color primaryLight = Color(0xFF3B82F6); // Blue
  static const Color primaryDark = Color(0xFF1E3A8A); // Darker Indigo
  static const Color onPrimary = Colors.white;

  static const Color secondary = Color(0xFF0D9488); // Teal
  static const Color secondaryLight = Color(0xFF14B8A6);
  static const Color secondaryDark = Color(0xFF0F766E);
  static const Color onSecondary = Colors.white;

  static const Color tertiary = Color(0xFFD97706); // Amber / Warm Accent
  static const Color onTertiary = Colors.white;

  // Background & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF0F172A); // Slate 900
  static const Color onSurfaceLight = Color(0xFF1E293B); // Slate 800
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Background & Surfaces (Dark)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color cardDark = Color(0xFF334155); // Slate 700
  static const Color onBackgroundDark = Color(0xFFF8FAFC); // Slate 50
  static const Color onSurfaceDark = Color(0xFFF1F5F9); // Slate 100
  static const Color borderDark = Color(0xFF475569); // Slate 600

  // Status & Feedback Colors
  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color onSuccess = Colors.white;
  static const Color successLight = Color(0xFFDCFCE7); // Green 100
  static const Color successDark = Color(0xFF14532D);

  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color onWarning = Colors.white;
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningDark = Color(0xFF78350F);

  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color onError = Colors.white;
  static const Color errorLight = Color(0xFFFEE2E2); // Red 100
  static const Color errorDark = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF2563EB); // Blue 600
  static const Color onInfo = Colors.white;
  static const Color infoLight = Color(0xFFDBEAFE); // Blue 100

  // Warranty & Claim Status Colors
  static const Color statusActive = Color(0xFF16A34A);
  static const Color statusExpiring = Color(0xFFD97706);
  static const Color statusExpired = Color(0xFFDC2626);

  static const Color claimDraft = Color(0xFF64748B); // Slate 500
  static const Color claimSubmitted = Color(0xFF2563EB); // Blue 600
  static const Color claimUnderReview = Color(0xFF7C3AED); // Purple 600
  static const Color claimInfoRequested = Color(0xFFD97706); // Amber 600
  static const Color claimApproved = Color(0xFF16A34A); // Green 600
  static const Color claimRejected = Color(0xFFDC2626); // Red 600
  static const Color claimCompleted = Color(0xFF0D9488); // Teal 600
  static const Color claimCancelled = Color(0xFF64748B); // Slate 500

  // Neutral Grays
  static const Color gray50 = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);
}
