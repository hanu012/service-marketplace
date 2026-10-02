import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_select_services_controller.dart';

/// Vendor self-service, step 3 of 3 — coverage zones (SPEC section 3.2).
///
/// Reads the SAME [VendorSelectServicesController] the services step
/// created rather than owning one: the two steps are halves of a single
/// selection submitted in one call. `Get.find` is safe because this screen
/// is only ever pushed from the services step, which stays alive beneath it.
class VendorSelectZonesView extends StatelessWidget {
  const VendorSelectZonesView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorSelectServicesController>(
      init: Get.find<VendorSelectServicesController>(),
      dispose: (_) => Get.delete<VendorSelectServicesController>(),
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
            label: controller.isAddingMore
                ? StringRes.addMoreServices
                : StringRes.confirmSubscribe,
            countLabel: picked > 0 ? '$picked ${tr(StringRes.zonesUnit)}' : null,
            onPressed: controller.isAddingMore
                ? controller.addServicesAPI
                : controller.subscribeAPI,
          ),
          children: bodyChildren(controller),
        );
      },
    );
  }

  List<Widget> bodyChildren(VendorSelectServicesController controller) {
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

  Widget cityCard(VendorSelectServicesController controller, ZoneModel city) {
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

  Widget looseZonesCard(
    VendorSelectServicesController controller,
    List<ZoneModel> loose,
  ) {
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

  Widget zoneRow(VendorSelectServicesController controller, ZoneModel zone) {
    final id = zone.id ?? -1;
    final selected = controller.isZoneSelected(id);
    final locked = controller.isZoneLocked(id);

    return ServicesRow(
      label: zone.name ?? '',
      selected: selected,
      enabled: !locked && (selected || !controller.zoneQuotaReached),
      onTap: () => controller.toggleZone(zone),
    );
  }
}
