import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/color_res.dart';
import '../constants/constant.dart';
import 'base_button.dart';
import 'base_text.dart';
import 'base_textfield.dart';

/// The shared visual system for the sign-in / sign-up screens.
///
/// Every auth screen is assembled from these five pieces, so Login and Register
/// cannot drift apart: change a radius or a spacing here and all five screens
/// move together.
///
/// Deliberately separate from [Utils.authLayout], which is still used by
/// add_vendor, select_plan, select_services and change_password. Those are not
/// auth screens and were not in scope, so they keep the old chrome rather than
/// being restyled by a side effect.
///
/// Sizing constants live in [_AuthTokens] rather than being sprinkled through
/// the widgets — the design language is a handful of numbers, and they should
/// be readable in one place.
class _AuthTokens {
  /// Horizontal gutter for everything on the screen.
  static double get gutter => 24.getSize;

  /// Between a field and the next label.
  static double get fieldGap => 18.getSize;

  /// Corner radius on inputs.
  static double get fieldRadius => 14.getSize;

  /// Corner radius on the primary button and the back chip's square-ish kin.
  static double get buttonRadius => 16.getSize;

  /// Vertical padding inside an input — this is what gives the tall,
  /// comfortable touch target the reference design uses.
  static double get fieldPadding => 18.getSize;

  /// Minimum tap target for the back chip and the password eye.
  static double get tapTarget => 46.getSize;
}

/// Page chrome: ambient glow, back chip, title block, then the caller's form.
///
/// The whole page scrolls as one column with no [Expanded] or [Spacer]
/// anywhere, which is what makes it overflow-proof: content taller than the
/// viewport scrolls instead of asserting, on a small phone and with the
/// keyboard open alike.
///
/// The primary button sits inside the scroll flow rather than in the
/// Scaffold's `bottomNavigationBar` (where these screens previously kept it).
/// A bottom bar has to be manually padded by `viewInsets.bottom` to dodge the
/// keyboard and still ends up pinned over the fields it belongs to; in the
/// flow it simply follows the last field, which is also where the reference
/// design puts it.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
    required this.primaryAction,
    this.showBack = false,
    this.footer,
  });

  /// Translation key for the screen's headline.
  final String title;

  /// Translation key for the line under it.
  final String subtitle;

  final GlobalKey<FormState> formKey;

  /// The screen's inputs, in order. Usually [AuthTextField]s.
  final List<Widget> fields;

  /// The submit button — [AuthPrimaryButton].
  final Widget primaryAction;

  /// Shows the circular back chip. Off for a flavour's first screen, where
  /// there is nothing behind it to return to.
  final bool showBack;

  /// The "Don't have an account? Register" line, when the screen has one.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorRes.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _AmbientGlow(),
          SafeArea(
            child: SingleChildScrollView(
              // No viewInsets padding here on purpose. `resizeToAvoidBottomInset`
              // already shrinks the body by the keyboard's height, and this
              // build context sits *above* the Scaffold — so reading
              // MediaQuery.viewInsets here would count the keyboard a second
              // time and leave a keyboard-sized void under the form.
              padding: EdgeInsets.only(
                left: _AuthTokens.gutter,
                right: _AuthTokens.gutter,
                top: 8.getSize,
                bottom: 32.getSize,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack) ...[
                    const AuthBackChip(),
                    24.heightSpacer,
                  ] else
                    16.heightSpacer,
                  BaseTextDMSans(
                    text: title,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                  ).tr(),
                  10.heightSpacer,
                  BaseTextDMSans(
                    text: subtitle,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.start,
                    lineHeight: 1.45,
                    maxLines: 3,
                  ).tr(),
                  32.heightSpacer,
                  Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields,
                    ),
                  ),
                  28.heightSpacer,
                  primaryAction,
                  if (footer != null) ...[
                    24.heightSpacer,
                    Center(child: footer!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft brand-coloured wash behind the title block.
///
/// This is the reference design's ambient glow, in teal rather than violet so
/// the apps still read as the same product as the Filament admin panel. Purely
/// decorative, so it is wrapped in [IgnorePointer] — it must never eat a tap
/// meant for the field underneath it.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 320.getSize,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.9),
            radius: 1.1,
            colors: [
              ColorRes.primaryColor.withValues(alpha: 0.16),
              ColorRes.backgroundColor.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular back button, sized to a comfortable 46pt tap target.
class AuthBackChip extends StatelessWidget {
  const AuthBackChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorRes.transparent,
      child: InkWell(
        onTap: onTap ?? () => Get.back(),
        borderRadius: BorderRadius.circular(_AuthTokens.tapTarget),
        child: Container(
          height: _AuthTokens.tapTarget,
          width: _AuthTokens.tapTarget,
          decoration: BoxDecoration(
            color: ColorRes.surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(color: ColorRes.borderColor, width: 1.getSize),
          ),
          child: Icon(
            Icons.arrow_back,
            size: 20.getSize,
            color: ColorRes.secondaryColor,
          ),
        ),
      ),
    );
  }
}

/// Label + input, the only field widget these screens use.
///
/// Every parameter that the previous [BaseTextField] call sites passed is
/// carried through unchanged — controller, validator, autovalidate mode,
/// keyboard type, input action, capitalisation, submit handler — so validation
/// and error text behave exactly as before. Only the presentation is new.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.validator,
    this.validateMode,
    this.textInputType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
    this.isSecure = false,
    this.suffixIcon,
    this.isLast = false,
  });

  /// Translation key shown above the field.
  final String label;

  /// Already-translated placeholder text.
  final String hint;

  final TextEditingController controller;

  /// Leading glyph inside the field.
  final IconData icon;

  final String? Function(String?)? validator;
  final AutovalidateMode? validateMode;
  final TextInputType? textInputType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final void Function(String)? onFieldSubmitted;
  final bool isSecure;
  final Widget? suffixIcon;

  /// Suppresses the trailing gap on the final field so the spacing before the
  /// button is controlled by [AuthScaffold] alone.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BaseTextDMSans(
          text: label,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ColorRes.secondaryColor,
          textAlign: TextAlign.start,
        ).tr(),
        8.heightSpacer,
        BaseTextField(
          controller: controller,
          hintText: hint,
          isShowBorder: true,
          isSecure: isSecure,
          validator: validator,
          validateMode: validateMode,
          textInputType: textInputType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onFieldSubmitted: onFieldSubmitted,
          fillColor: ColorRes.surfaceColor,
          borderColor: ColorRes.borderColor,
          focusBorderColor: ColorRes.primaryColor,
          borderRadius: _AuthTokens.fieldRadius,
          borderWidth: 1.2,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.getSize,
            vertical: _AuthTokens.fieldPadding,
          ),
          prefixIcon: Icon(
            icon,
            size: 20.getSize,
            color: ColorRes.grayColor,
          ),
          suffixIcon: suffixIcon,
        ),
        if (!isLast) SizedBox(height: _AuthTokens.fieldGap),
      ],
    );
  }
}

/// The eye toggle used by every password field, so the three screens that have
/// one cannot end up with three slightly different icons.
class AuthVisibilityToggle extends StatelessWidget {
  const AuthVisibilityToggle({
    super.key,
    required this.isObscured,
    required this.onPressed,
  });

  final bool isObscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      splashRadius: 22.getSize,
      icon: Icon(
        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: ColorRes.grayColor,
        size: 20.getSize,
      ),
    );
  }
}

/// Full-width gradient submit button.
///
/// Wraps [BaseRaisedButton] rather than replacing it — the gradient lives on
/// the container, the button itself is transparent, so the existing label
/// styling, tap feedback and `onPressed` contract are untouched.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// Translation key for the button text.
  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_AuthTokens.buttonRadius),
        // primaryColor → primaryColorDark, never starting at
        // primaryColorLight: white text on violet-400 is 2.7:1 and fails AA.
        // This sweep keeps the label between 4.2:1 and 7.0:1 end to end.
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ColorRes.primaryColor,
            ColorRes.primaryColorDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorRes.primaryColor.withValues(alpha: 0.28),
            blurRadius: 20.getSize,
            offset: Offset(0, 8.getSize),
          ),
        ],
      ),
      child: BaseRaisedButton(
        onPressed: onPressed,
        buttonText: label,
        buttonColor: ColorRes.transparent,
        textColor: ColorRes.whiteColor,
        borderRadius: _AuthTokens.buttonRadius,
        buttonVerticalPadding: 18.getSize,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The "Don't have an account? Register" line.
///
/// Kept as a single tappable row so the whole line is a comfortable target,
/// with only the action half carrying brand colour and weight.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.promptKey,
    required this.actionKey,
    required this.onTap,
  });

  /// Translation key for the muted lead-in text.
  final String promptKey;

  /// Translation key for the emphasised action word.
  final String actionKey;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorRes.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.getSize),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8.getSize,
            vertical: 10.getSize,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: BaseTextDMSans(
                  text: promptKey,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: ColorRes.grayColor,
                ).tr(),
              ),
              6.widthSpacer,
              Flexible(
                child: BaseTextDMSans(
                  // primaryColorLight, not primaryColor: at 13pt this is body
                  // text, so it needs 4.5:1. violet-500 lands at 4.4:1 on the
                  // canvas; violet-400 clears it at 7.0:1.
                  text: actionKey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorRes.primaryColorLight,
                ).tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
