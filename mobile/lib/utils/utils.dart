import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../constants/color_res.dart';
import '../constants/constant.dart';
import '../constants/pref_keys.dart';
import '../constants/string_res.dart';
import '../widgets/base_text.dart';
import 'injector.dart';

/// Shared helpers. Trimmed to what the app actually uses — the demo-app's
/// 2,228-line Utils also carried image picking, webview, audio and Firebase
/// helpers that this project has no use for yet. Add helpers here as screens
/// genuinely need them, rather than porting speculatively.
class Utils {
  /// Navigator key, also used by [getSize] to tell whether the widget tree is
  /// mounted yet.
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static double getScreenWidth(BuildContext context) => Get.width;

  static double getScreenHeight(BuildContext context) => Get.height;

  static String getAssetsImg(String name) => 'assets/images/$name.png';

  static String getAssetsSVGImg(String name) => 'assets/images/$name.svg';

  /// Scales a design-pixel value against a 414pt-wide reference device.
  ///
  /// Returns the raw value before the navigator is mounted, because Get.width
  /// is not available then.
  static double getSize(double px) {
    if (Utils.key.currentState != null) {
      return px * (Get.width / 414);
    }
    return px;
  }

  /// Font sizes scale more gently than layout so text stays legible on small
  /// screens without overflowing on large ones.
  static double getFontSize(double px) {
    if (Utils.key.currentState != null) {
      final scale = (Get.width / 414).clamp(0.85, 1.15);
      return px * scale;
    }
    return px;
  }

  /// Blocking progress overlay.
  ///
  /// Named for the demo-app's Lottie-based original, but that implementation
  /// also used a CupertinoActivityIndicator — no Lottie asset was ever
  /// involved. The name is kept so ported screens compile unchanged.
  ///
  /// Call with `true` before an API call and `false` after, always in a
  /// try/catch so a thrown request cannot strand the dialog on screen.
  static void showCircularProgressLottie(bool isLoading) {
    if (!isLoading) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: ColorRes.transparent,
        contentPadding: EdgeInsets.zero,
        elevation: 0.0,
        content: Center(
          child: CupertinoActivityIndicator(
            color: ColorRes.primaryColor,
            radius: 16.getSize,
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Replaces the whole navigation stack — used after sign-in and sign-out.
  static void transitionWithOffAll(
    dynamic page, {
    dynamic argument,
    Function? voidCallback,
    Transition? transition,
  }) {
    if (kDebugMode) {
      print('IN OFF ALL FUNCTION UTILS');
    }

    Get.offAll(
      page,
      transition: transition ?? Transition.fadeIn,
      duration: const Duration(milliseconds: 300),
      arguments: argument,
    )?.then((value) {
      if (voidCallback != null) {
        voidCallback(value ?? '');
      }
    });
  }

  static void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: isError ? ColorRes.errorColor : ColorRes.surfaceElevatedColor,
      textColor: ColorRes.whiteColor,
    );
  }

  /// Shared chrome for the auth screens: a coloured header carrying the title,
  /// description and optional Skip action, with the screen's own fields
  /// scrolling underneath.
  ///
  /// The demo-app painted this header with an `assets/images/blue_bg.png`
  /// bitmap. That asset is light-blue branding and does not exist here, so the
  /// header is a teal-to-slate gradient instead — same layout, no asset, and
  /// it recolours with the palette rather than needing a new export.
  static Widget authLayout({
    required Widget contentWidget,
    required String title,
    required String desc,
    required bool isLogin,
    required bool skipTap,
    required bool isForCustomer,
    required void Function()? onSkipTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 200.getSize),
          padding: EdgeInsets.only(
            left: 24.getSize,
            right: 24.getSize,
            top: 20.getSize,
            bottom: 26.getSize,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorRes.primaryColorDark,
                ColorRes.surfaceColor,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (skipTap) ...[
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(
                      Icons.arrow_back,
                      size: 24.getSize,
                      color: ColorRes.whiteColor,
                    ),
                  ),
                  10.heightSpacer,
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: BaseTextDMSans(
                        text: title,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: ColorRes.whiteColor,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                      ).tr(),
                    ),
                    if (!skipTap && onSkipTap != null)
                      Padding(
                        padding: EdgeInsets.only(top: 10.getSize),
                        child: InkWell(
                          // The demo-app hardcoded its own landing page here
                          // and ignored the onSkipTap parameter. Honouring the
                          // callback keeps this reusable across the three
                          // flavours, which land on different screens.
                          onTap: () {
                            Injector.skipTap = true;
                            Injector.prefs?.setBool(PrefKeys.skipTap, true);
                            onSkipTap();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.getSize,
                              vertical: 4.getSize,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.getSize),
                              color: ColorRes.whiteColor,
                            ),
                            child: BaseTextDMSans(
                              text: StringRes.skip,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: ColorRes.primaryColorDark,
                            ).tr(),
                          ),
                        ),
                      ),
                  ],
                ),
                8.heightSpacer,
                BaseTextDMSans(
                  text: desc,
                  fontWeight: FontWeight.w300,
                  fontSize: 14,
                  color: ColorRes.grayColor,
                  textAlign: TextAlign.start,
                  maxLines: 3,
                ).tr(),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: contentPadding ??
                EdgeInsets.only(
                  left: 24.getSize,
                  right: 24.getSize,
                  top: 40.getSize,
                  bottom: 40.getSize,
                ),
            child: contentWidget,
          ),
        ),
      ],
    );
  }
}
