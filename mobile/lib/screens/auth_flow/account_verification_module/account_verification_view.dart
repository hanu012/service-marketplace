import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'account_verification_controller.dart';

/// "Your account is in verification" (SPEC section 3.1).
///
/// Deliberately a dead end apart from two controls. Nothing links back
/// into the app from here — the account cannot use any of it until an
/// admin decides, and offering a way in that the API then refuses reads
/// as a broken app rather than a waiting one.
///
/// The three-step tracker exists because "we are reviewing you" with no
/// sense of where that sits is the kind of screen people reinstall the app
/// over. It shows what has happened, what is happening, and what is next.
class AccountVerificationView extends StatelessWidget {
  const AccountVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AccountVerificationController>(
      init: AccountVerificationController(),
      dispose: (_) => Get.delete<AccountVerificationController>(),
      builder: (controller) {
        final rejected = controller.isRejected;

        return PopScope(
          // The back gesture must not escape this screen: on the vendor
          // and customer flavours it would pop straight back onto the
          // registration form behind it.
          canPop: false,
          child: Scaffold(
            backgroundColor: ColorRes.backgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24.getSize,
                      10.getSize,
                      24.getSize,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: signOutPill(controller),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        24.getSize,
                        24.getSize,
                        24.getSize,
                        24.getSize,
                      ),
                      children: [
                        Center(child: statusBadge(rejected)),
                        22.heightSpacer,
                        BaseTextDMSans(
                          text: rejected
                              ? tr(StringRes.accountRejectedTitle)
                              : tr(StringRes.accountVerificationTitle),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: ColorRes.secondaryColor,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                        10.heightSpacer,
                        BaseTextDMSans(
                          text: rejected
                              ? tr(StringRes.accountRejectedDesc)
                              : tr(StringRes.accountVerificationDesc),
                          fontSize: 13.5,
                          color: ColorRes.grayColor,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                        ),
                        24.heightSpacer,
                        tracker(rejected),

                        // The admin's reason, where there is one. Shown
                        // verbatim — it is the only thing that tells the
                        // user what to do next.
                        if (rejected && (controller.note ?? '').isNotEmpty) ...[
                          16.heightSpacer,
                          reasonBox(controller.note!),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24.getSize,
                      0,
                      24.getSize,
                      20.getSize,
                    ),
                    // Hidden once rejected: re-checking a decision that
                    // has already gone against them only invites tapping
                    // at a button that will never change.
                    child: rejected
                        ? const SizedBox.shrink()
                        : AuthPrimaryButton(
                            label: StringRes.checkVerificationStatus,
                            onPressed: controller.isChecking
                                ? () {}
                                : controller.checkStatusAPI,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget signOutPill(AccountVerificationController controller) {
    return Material(
      color: ColorRes.transparent,
      child: InkWell(
        onTap: controller.logoutAPI,
        borderRadius: BorderRadius.circular(24.getSize),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.getSize,
            vertical: 10.getSize,
          ),
          decoration: BoxDecoration(
            color: ColorRes.surfaceColor,
            borderRadius: BorderRadius.circular(24.getSize),
            border: Border.all(color: ColorRes.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout,
                size: 15.getSize,
                color: ColorRes.secondaryColor,
              ),
              8.widthSpacer,
              BaseTextDMSans(
                text: StringRes.logout,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: ColorRes.secondaryColor,
              ).tr(),
            ],
          ),
        ),
      ),
    );
  }

  /// The violet (or red) rounded tile the screen opens with.
  Widget statusBadge(bool rejected) {
    return Container(
      height: 76.getSize,
      width: 76.getSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: rejected
            ? null
            : LinearGradient(
                colors: [ColorRes.primaryColorLight, ColorRes.primaryColorDark],
              ),
        color: rejected ? ColorRes.errorColor.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(24.getSize),
        border: rejected
            ? Border.all(color: ColorRes.errorColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Icon(
        rejected ? Icons.cancel_outlined : Icons.hourglass_empty,
        size: 34.getSize,
        color: rejected ? ColorRes.errorColor : ColorRes.whiteColor,
      ),
    );
  }

  /// Created → under review → decided.
  Widget tracker(bool rejected) {
    return Container(
      padding: EdgeInsets.all(18.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceColor,
        borderRadius: BorderRadius.circular(18.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: Column(
        children: [
          _TrackerStep(
            state: _StepState.done,
            title: tr(StringRes.verifyStepCreated),
            subtitle: tr(StringRes.verifyStepCreatedSub),
          ),
          _TrackerStep(
            state: rejected ? _StepState.done : _StepState.current,
            title: tr(StringRes.verifyStepReview),
            subtitle: rejected
                ? tr(StringRes.verifyStepReviewDoneSub)
                : tr(StringRes.verifyStepReviewSub),
          ),
          _TrackerStep(
            // A rejection is still an outcome, so the last step is
            // reached rather than left pending — it just is not a good
            // one.
            state: rejected ? _StepState.failed : _StepState.pending,
            title: rejected
                ? tr(StringRes.verifyStepRejected)
                : tr(StringRes.verifyStepApproved),
            subtitle: rejected
                ? tr(StringRes.verifyStepRejectedSub)
                : tr(StringRes.verifyStepApprovedSub),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget reasonBox(String note) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.getSize),
        border: Border.all(color: ColorRes.errorColor.withValues(alpha: 0.35)),
      ),
      child: BaseTextDMSans(
        text: note,
        fontSize: 13,
        color: ColorRes.secondaryColor,
        textAlign: TextAlign.center,
        maxLines: 6,
      ),
    );
  }
}

enum _StepState { done, current, pending, failed }

/// One row of the tracker: a status dot, the connecting rail, and the
/// label pair.
class _TrackerStep extends StatelessWidget {
  const _TrackerStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final _StepState state;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = state != _StepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              dot(),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.getSize,
                    margin: EdgeInsets.symmetric(vertical: 4.getSize),
                    color: state == _StepState.done
                        ? ColorRes.primaryColor.withValues(alpha: 0.55)
                        : ColorRes.borderColor,
                  ),
                ),
            ],
          ),
          14.widthSpacer,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.getSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BaseTextDMSans(
                    text: title,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                        reached ? ColorRes.secondaryColor : ColorRes.grayColor,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  3.heightSpacer,
                  BaseTextDMSans(
                    text: subtitle,
                    fontSize: 12.5,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget dot() {
    final (Color background, Color border, IconData? icon, Color iconColor) =
        switch (state) {
      _StepState.done => (
          ColorRes.successColor.withValues(alpha: 0.18),
          ColorRes.successColor,
          Icons.check,
          ColorRes.successColor,
        ),
      _StepState.current => (
          ColorRes.primaryColor,
          ColorRes.primaryColor,
          Icons.schedule,
          ColorRes.whiteColor,
        ),
      _StepState.failed => (
          ColorRes.errorColor.withValues(alpha: 0.18),
          ColorRes.errorColor,
          Icons.close,
          ColorRes.errorColor,
        ),
      _StepState.pending => (
          ColorRes.transparent,
          ColorRes.borderColor,
          null,
          ColorRes.grayColor,
        ),
    };

    return Container(
      height: 28.getSize,
      width: 28.getSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.6),
      ),
      child:
          icon == null ? null : Icon(icon, size: 15.getSize, color: iconColor),
    );
  }
}
