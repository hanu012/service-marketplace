import 'package:flutter/material.dart';

import '../constants/color_res.dart';
import '../constants/constant.dart';

/// Extends [TextFormField], matching the demo-app pattern.
///
/// The demo-app declared ~45 constructor parameters. The ones actually used
/// across its screens are kept here; the rest are omitted rather than carried
/// as dead API surface. Add a parameter when a screen genuinely needs it.
///
/// Colours default to the dark palette in [ColorRes] — the demo-app's light
/// theme would render as white-on-white here.
class BaseTextField extends TextFormField {
  BaseTextField({
    super.key,
    required super.controller,
    String? hintText,
    String? labelText,
    bool isSecure = false,
    super.enabled,
    super.autofocus,
    super.readOnly,
    bool isShowBorder = false,
    super.validator,
    super.onChanged,
    super.onTap,
    super.onEditingComplete,
    super.onFieldSubmitted,
    Widget? suffixIcon,
    Widget? prefixIcon,
    Color? fillColor,
    Color? borderColor,
    Color? textColor,
    Color? hintTextColor,
    Color? cursorColor,
    Color? errorBorderColor,
    Color? focusBorderColor,
    super.textAlign,
    FontWeight? fontWeight,
    TextInputType? textInputType,
    super.textInputAction,
    super.textCapitalization,
    super.inputFormatters,
    AutovalidateMode? validateMode,
    super.focusNode,
    EdgeInsets? contentPadding,
    double? borderRadius,
    double? borderWidth,
    int? maxLines,
    super.minLines,
    super.maxLength,
    int? errorMaxLines,
    int? hintMaxLines,
    String? fontFamily,
  }) : super(
          autovalidateMode: validateMode,
          obscureText: isSecure,
          keyboardType: textInputType,
          maxLines: isSecure ? 1 : (maxLines ?? 1),
          cursorColor: cursorColor ?? ColorRes.primaryColor,
          style: TextStyle(
            color: textColor ?? ColorRes.secondaryColor,
            fontSize: (14 + 4).getFontSize,
            fontWeight: fontWeight ?? FontWeight.w400,
            fontFamily: fontFamily ?? FontFamily.dmSans,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            labelText: labelText,
            errorMaxLines: errorMaxLines ?? 2,
            hintMaxLines: hintMaxLines,
            filled: true,
            fillColor: fillColor ?? ColorRes.surfaceElevatedColor,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            counterText: '',
            contentPadding: contentPadding ??
                EdgeInsets.symmetric(
                  horizontal: 16.getSize,
                  vertical: 14.getSize,
                ),
            hintStyle: TextStyle(
              color: hintTextColor ?? ColorRes.grayColor,
              fontSize: (14 + 4).getFontSize,
              fontWeight: FontWeight.w400,
              fontFamily: fontFamily ?? FontFamily.dmSans,
            ),
            labelStyle: TextStyle(
              color: hintTextColor ?? ColorRes.grayColor,
              fontFamily: fontFamily ?? FontFamily.dmSans,
            ),
            errorStyle: TextStyle(
              color: ColorRes.errorColor,
              fontSize: (12 + 4).getFontSize,
              fontFamily: fontFamily ?? FontFamily.dmSans,
            ),
            enabledBorder: _border(
              isShowBorder ? (borderColor ?? ColorRes.borderColor) : Colors.transparent,
              borderRadius,
              borderWidth,
            ),
            focusedBorder: _border(
              focusBorderColor ?? ColorRes.primaryColor,
              borderRadius,
              borderWidth,
            ),
            errorBorder: _border(
              errorBorderColor ?? ColorRes.errorColor,
              borderRadius,
              borderWidth,
            ),
            focusedErrorBorder: _border(
              errorBorderColor ?? ColorRes.errorColor,
              borderRadius,
              borderWidth,
            ),
            disabledBorder: _border(
              Colors.transparent,
              borderRadius,
              borderWidth,
            ),
          ),
        );

  static OutlineInputBorder _border(Color color, double? radius, double? width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius ?? 10.getSize),
      borderSide: BorderSide(color: color, width: width ?? 1.getSize),
    );
  }
}
