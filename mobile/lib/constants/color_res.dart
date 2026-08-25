import 'package:flutter/material.dart';

/// Single source of colour for the app. Screens never carry inline hex —
/// see the Flutter conventions in CLAUDE.md.
///
/// Values are the verified palette from CLAUDE.md's Theme section, shared with
/// the Filament admin panel so the two look like one product.
///
/// Member names are kept identical to the demo-app (primaryColor,
/// secondaryColor, grayColor, ...) so screens ported from it compile without
/// edits. Only the values changed: the demo-app was a light blue theme.
class ColorRes {
  // ── Brand ────────────────────────────────────────────────────────────────
  /// teal-400. Buttons, links, active states, focus rings.
  static Color primaryColor = const Color(0xFF2DD4BF);

  /// teal-300 — hover / pressed lift on top of [primaryColor].
  static Color primaryColorLight = const Color(0xFF5EEAD4);

  /// teal-600 — pressed states and dividers that need to read as brand.
  static Color primaryColorDark = const Color(0xFF0D9488);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// slate-950. App background. Deliberately not #000000.
  static Color backgroundColor = const Color(0xFF020617);

  /// slate-900. Cards, sheets, nav, raised surfaces.
  static Color surfaceColor = const Color(0xFF0F172A);

  /// slate-800. Input fills and pressed surfaces.
  static Color surfaceElevatedColor = const Color(0xFF1E293B);

  /// slate-700. Borders and dividers.
  static Color borderColor = const Color(0xFF334155);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// slate-50. Primary text on dark surfaces.
  ///
  /// In the demo-app this was near-black body text; on a dark theme the same
  /// role is near-white. The name is kept so ported screens still compile.
  static Color secondaryColor = const Color(0xFFF8FAFC);

  /// slate-400. Secondary text, hints, disabled states.
  static Color grayColor = const Color(0xFF94A3B8);

  static Color whiteColor = const Color(0xFFFFFFFF);
  static Color blackColor = const Color(0xFF020617);

  // ── Status ───────────────────────────────────────────────────────────────
  // Kept clear of teal so status never reads as brand. Mirrors the reasoning
  // in CLAUDE.md for the admin panel.
  static Color errorColor = const Color(0xFFEF4444); // red-500
  static Color warningColor = const Color(0xFFF59E0B); // amber-500
  static Color successColor = const Color(0xFF22C55E); // green-500

  static Color transparent = Colors.transparent;

  /// Swatch for ThemeData.primarySwatch.
  static MaterialColor primaryMaterialColor = MaterialColor(
    ColorRes.primaryColor.toARGB32(),
    <int, Color>{
      50: ColorRes.primaryColor.withValues(alpha: 0.1),
      100: ColorRes.primaryColor.withValues(alpha: 0.2),
      200: ColorRes.primaryColor.withValues(alpha: 0.3),
      300: ColorRes.primaryColor.withValues(alpha: 0.4),
      400: ColorRes.primaryColor.withValues(alpha: 0.5),
      500: ColorRes.primaryColor.withValues(alpha: 0.6),
      600: ColorRes.primaryColor.withValues(alpha: 0.7),
      700: ColorRes.primaryColor.withValues(alpha: 0.8),
      800: ColorRes.primaryColor.withValues(alpha: 0.9),
      900: ColorRes.primaryColor,
    },
  );
}
