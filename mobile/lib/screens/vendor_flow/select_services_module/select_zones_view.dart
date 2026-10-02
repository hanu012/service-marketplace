import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'select_services_controller.dart';

/// Add Vendor, step 3 of 3 — coverage zones (SPEC 2.2, section 8).
///
/// Reads the SAME [SelectServicesController] the services step created
/// rather than owning one: the two steps are halves of a single selection
/// that is submitted in one call, so splitting the state would mean
/// stitching it back together at submit time. `Get.find` is safe here
/// because this screen is only ever pushed from the services step, which
/// stays alive underneath it in the navigator stack.
class SelectZonesView extends StatelessWidget {
  const SelectZonesView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SelectServicesController>(
      init: Get.find<SelectServicesController>(),
      // The flow ends here, so this is where the shared controller goes.
      dispose: (_) => Get.delete<SelectServicesController>(),
      builder: (controller) {
        final picked = controller.selectedZoneIds.length;

        return ServicesPage(
          header: const ServicesHeader(
            title: StringRes.coverageZonesTitle,
            subtitle: StringRes.coverageZonesDesc,
            step: 3,
            totalSteps: 3,
          ),
          footer: ServicesFooter(
            hint: tr(StringRes.zonesCountTowardLimit),
            label: StringRes.continueLabel,
            countLabel: picked > 0 ? '$picked ${tr(StringRes.zonesUnit)}' : null,
            onPressed: () => onContinueTap(controller),
          ),
          children: bodyChildren(controller),
        );
      },
    );
  }

  List<Widget> bodyChildren(SelectServicesController controller) {
    final searchBar = ServicesSearchBar(
      controller: controller.zoneSearchController,
      hintText: tr(StringRes.searchAnAreaHint),
      onChanged: controller.onZoneSearchChanged,
      filterActive: controller.zoneSearchQuery.isNotEmpty,
      onFilterTap: () {
        controller.zoneSearchController.clear();
        controller.onZoneSearchChanged('');
      },
    );

    if (controller.isLoading && controller.zones.isEmpty) {
      return [
        searchBar,
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60.getSize),
          child: Center(
            child: CupertinoActivityIndicator(color: ServiceTokens.purpleBright),
          ),
        ),
      ];
    }

    final cities = controller.filteredZoneCities;
    final loose = controller.visibleStandaloneZones;

    return [
      searchBar,
      14.heightSpacer,
      ServicesStatRow(
        left: ServicesStatTile(
          value: '${controller.selectedZoneIds.length}',
          suffix: '/ ${controller.maxZones}',
          label: tr(StringRes.zonesInThisPlan),
        ),
        right: ServicesStatTile(
          value: '${controller.zonesRemaining}',
          suffix: tr(StringRes.leftLabel),
          label: tr(StringRes.stillAvailableLabel),
        ),
      ),
      16.heightSpacer,
      if (cities.isEmpty && loose.isEmpty)
        ServicesEmptyState(message: tr(StringRes.noMatchingZones))
      else ...[
        for (final city in cities) cityCard(controller, city),
        if (loose.isNotEmpty) looseZonesCard(controller, loose),
      ],
    ];
  }

  Widget cityCard(SelectServicesController controller, ZoneModel city) {
    final visible = controller.visibleZonesIn(city);
    final picked = controller.selectedCountInCity(city);
    final total = city.children.length;
    final allPicked = total > 0 && picked == total;

    return ServicesGroupCard(
      header: ServicesGroupHead(
        title: city.name ?? '',
        countLine: '$total ${tr(StringRes.areasAvailable)}',
        fallbackIcon: Icons.place_outlined,
        badge: picked > 0
            ? ServicesBadge(
                label: allPicked
                    ? tr(StringRes.allLabel)
                    : '$picked ${tr(StringRes.pickedSuffix)}',
              )
            : const ServicesBadge(label: '0', muted: true),
      ),
      rows: [
        for (final zone in visible) zoneRow(controller, zone),
      ],
      footer: visible.isNotEmpty
          ? ServicesCardFooter(
              actionLabel: tr(StringRes.selectAllLabel),
              actionEnabled: !allPicked && !controller.zoneQuotaReached,
              onAction: () => controller.selectAllZonesIn(city),
              trailing: '$picked ${tr(StringRes.of)} $total '
                  '${tr(StringRes.selectedSuffix)}',
            )
          : null,
    );
  }

  /// Top-level zones with no children are leaves in their own right
  /// (SPEC section 8), so they are selectable directly rather than being
  /// dropped for having no city to sit under.
  Widget looseZonesCard(SelectServicesController controller, List<ZoneModel> loose) {
    final picked =
        loose.where((zone) => controller.isZoneSelected(zone.id ?? -1)).length;

    return ServicesGroupCard(
      header: ServicesGroupHead(
        title: tr(StringRes.zonesSection),
        countLine: '${loose.length} ${tr(StringRes.areasAvailable)}',
        fallbackIcon: Icons.place_outlined,
        badge: picked > 0
            ? ServicesBadge(label: '$picked ${tr(StringRes.pickedSuffix)}')
            : const ServicesBadge(label: '0', muted: true),
      ),
      rows: [
        for (final zone in loose) zoneRow(controller, zone),
      ],
    );
  }

  Widget zoneRow(SelectServicesController controller, ZoneModel zone) {
    final selected = controller.isZoneSelected(zone.id ?? -1);

    return ServicesRow(
      label: zone.name ?? '',
      selected: selected,
      enabled: selected || !controller.zoneQuotaReached,
      onTap: () => controller.toggleZone(zone),
    );
  }

  // ── Payment dialog (logic unchanged) ───────────────────────────────────

  void onContinueTap(SelectServicesController controller) {
    if (!controller.validateSelections()) {
      return;
    }

    Get.dialog(paymentModeDialog(controller));
  }

  /// SPEC section 2.2: "choose payment mode -> confirmation dialog -> single
  /// API call." Wrapped in its own GetBuilder so a tap updates the radio
  /// selection live without closing the dialog.
  Widget paymentModeDialog(SelectServicesController controller) {
    return GetBuilder<SelectServicesController>(
      builder: (controller) {
        return AlertDialog(
          backgroundColor: ServiceTokens.card,
          title: BaseTextDMSans(
            text: StringRes.choosePaymentMode,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ServiceTokens.text,
          ).tr(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              paymentModeOption(controller, 'cash', StringRes.paymentModeCash),
              paymentModeOption(controller, 'online', StringRes.paymentModeOnline),
              paymentModeOption(controller, 'free', StringRes.paymentModeFree),
              if (controller.selectedPaymentMode == 'free') ...[
                8.heightSpacer,
                freeTrialDurationPicker(controller),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: BaseTextDMSans(
                text: StringRes.cancel,
                color: ServiceTokens.muted,
              ).tr(),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                controller.subscribeAPI();
              },
              child: BaseTextDMSans(
                text: StringRes.confirmSubscribe,
                color: ServiceTokens.purpleBright,
                fontWeight: FontWeight.w700,
              ).tr(),
            ),
          ],
        );
      },
    );
  }

  Widget freeTrialDurationPicker(SelectServicesController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 8.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.bg,
        borderRadius: BorderRadius.circular(10.getSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextDMSans(
            text: StringRes.freeTrialDurationLabel,
            fontSize: 12,
            color: ServiceTokens.muted,
          ).tr(),
          6.heightSpacer,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: controller.freeTrialDays > 1
                    ? () => controller.setFreeTrialDays(controller.freeTrialDays - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline,
                    color: ServiceTokens.purpleBright),
              ),
              BaseTextDMSans(
                text: '${controller.freeTrialDays} ${tr(StringRes.daysUnit)}',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ServiceTokens.text,
              ),
              IconButton(
                onPressed: controller.freeTrialDays < controller.freeTrialMaxDays
                    ? () => controller.setFreeTrialDays(controller.freeTrialDays + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline,
                    color: ServiceTokens.purpleBright),
              ),
            ],
          ),
          BaseTextDMSans(
            text: '${tr(StringRes.freeTrialCappedAt)} '
                '${controller.freeTrialMaxDays} ${tr(StringRes.daysUnit)}',
            fontSize: 11,
            color: ServiceTokens.muted2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget paymentModeOption(
    SelectServicesController controller,
    String mode,
    String labelKey,
  ) {
    final selected = controller.selectedPaymentMode == mode;

    return InkWell(
      onTap: () => controller.selectPaymentMode(mode),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.getSize),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20.getSize,
              color: selected ? ServiceTokens.purpleBright : ServiceTokens.muted,
            ),
            10.widthSpacer,
            BaseTextDMSans(
              text: labelKey,
              fontSize: 14,
              color: ServiceTokens.text,
            ).tr(),
          ],
        ),
      ),
    );
  }
}
