import 'package:flutter/material.dart';

/// Single source of colour for the app. Screens never carry inline hex —
/// see the Flutter conventions in CLAUDE.md.
///
/// The palette is the violet/indigo scheme from the auth reference design:
/// a near-black indigo canvas, violet-tinted surfaces and borders, and a
/// violet-500 accent. Every value below was contrast-checked against the
/// surface it actually sits on (see the notes per token).
///
/// NOTE: CLAUDE.md's Theme section still documents the previous teal-400 /
/// slate palette, which the Filament admin panel continues to use. The two
/// products no longer share an accent colour. That divergence is deliberate
/// but undocumented — CLAUDE.md needs updating, or the admin panel needs
/// re-theming to match, depending on which way the product should go.
///
/// Member names are kept identical to the demo-app (primaryColor,
/// secondaryColor, grayColor, ...) so screens ported from it compile without
/// edits. Only the values changed.
class ColorRes {
  // ── Brand ────────────────────────────────────────────────────────────────
  /// violet-500. Buttons, focus rings, active states.
  ///
  /// Carries white text at 4.2:1 — fine for the 16pt semibold button label,
  /// which is why button labels default to white rather than dark ink.
  static Color primaryColor = const Color(0xFF8B5CF6);

  /// violet-400. Links and secondary accents on the dark canvas, where it
  /// reads at 7.0:1 against [backgroundColor].
  ///
  /// Deliberately NOT used as a button fill: white text on it is only 2.7:1,
  /// which fails AA. Button gradients run primaryColor → primaryColorDark.
  static Color primaryColorLight = const Color(0xFFA78BFA);

  /// violet-700. The deep end of button gradients and pressed states.
  /// White on this is 7.0:1.
  static Color primaryColorDark = const Color(0xFF6D28D9);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Near-black indigo. App background. Deliberately not #000000 — the
  /// reference design's canvas carries a faint violet cast.
  static Color backgroundColor = const Color(0xFF0B0716);

  /// Cards, sheets, nav, input fills. One step up from the canvas.
  static Color surfaceColor = const Color(0xFF16102E);

  /// Pressed surfaces and secondary buttons.
  static Color surfaceElevatedColor = const Color(0xFF221A45);

  /// Violet-tinted hairline for borders and dividers — the visible outline
  /// on the reference design's inputs.
  static Color borderColor = const Color(0xFF362B63);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// violet-50. Primary text on dark surfaces, ~18:1 on [backgroundColor].
  ///
  /// In the demo-app this was near-black body text; on a dark theme the same
  /// role is near-white. The name is kept so ported screens still compile.
  static Color secondaryColor = const Color(0xFFF5F3FF);

  /// Muted lavender-gray. Secondary text, hints, disabled states. 7.5:1 on
  /// [backgroundColor], so hint text stays readable rather than decorative.
  static Color grayColor = const Color(0xFFA29CC4);

  static Color whiteColor = const Color(0xFFFFFFFF);
  static Color blackColor = const Color(0xFF0B0716);

  // ── Status ───────────────────────────────────────────────────────────────
  // Unchanged, and now further from the accent than they were under teal —
  // violet collides with neither red nor amber nor green.
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
