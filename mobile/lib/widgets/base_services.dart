import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/constant.dart';
import '../constants/string_res.dart';
import 'base_text.dart';

/// The shared visual system for the salesman/vendor "what does this vendor
/// sell, and where" steps — Services & zones, then Coverage zones.
///
/// Those two screens plus their vendor self-service twins are four views over
/// one selection model, so the chrome lives here rather than being pasted four
/// times and then drifting. Same reasoning as [base_auth.dart], which does
/// this for the sign-in/sign-up pair.
///
/// PALETTE NOTE: these tokens are the redesign's own, not [ColorRes]. The two
/// palettes are close but not identical (the redesign runs a touch warmer and
/// flatter — #0C0A16 vs #0B0716 ground, #7C3AED vs #8B5CF6 accent), and
/// pulling the redesign's values into [ColorRes] would restyle every other
/// screen in all three apps as a side effect. Keeping them local means this
/// flow can match its spec exactly without that blast radius. If the rest of
/// the app is ever moved onto the same palette, these should collapse back
/// into [ColorRes].
class ServiceTokens {
  const ServiceTokens._();

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBright = Color(0xFF8B5CF6);
  static const Color purpleDeep = Color(0xFF5B21B6);
  static const Color bg = Color(0xFF0C0A16);
  static const Color card = Color(0xFF171426);
  static const Color card2 = Color(0xFF1E1A30);
  static const Color stroke = Color(0xFF2A2540);
  static const Color stroke2 = Color(0xFF332D4D);
  static const Color text = Color(0xFFF5F3FF);
  static const Color muted = Color(0xFF9E97BE);
  static const Color muted2 = Color(0xFF7C7599);
  static const Color green = Color(0xFF34D399);

  /// Header gradient stops (CSS `linear-gradient(160deg, ...)`).
  static const Color heroTop = Color(0xFF7C3AED);
  static const Color heroMid = Color(0xFF6D28D9);
  static const Color heroBottom = Color(0xFF3B1D74);

  /// How far the search row lifts into the header's bottom edge. The header
  /// pads itself by the same amount so the overlap costs no layout height.
  static double get searchLift => 18.getSize;
}

// ── Header ────────────────────────────────────────────────────────────────

/// The violet gradient page header: back chip, step pill, headline, and the
/// segmented progress bar.
class ServicesHeader extends StatelessWidget {
  const ServicesHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  /// Translation key for the headline.
  final String title;

  /// Translation key for the line under it.
  final String subtitle;

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ServiceTokens.heroTop, ServiceTokens.heroMid, ServiceTokens.heroBottom],
          stops: [0.0, 0.46, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // The warm highlight the CSS puts at 85% -10% — decorative only.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -1.2),
                    radius: 1.2,
                    colors: [
                      ServiceTokens.purpleBright.withValues(alpha: 0.55),
                      ServiceTokens.purple.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              // Bottom padding carries the search row's overlap, so lifting
              // it costs no height and nothing below it shifts.
              padding: EdgeInsets.fromLTRB(
                22.getSize,
                14.getSize,
                22.getSize,
                22.getSize + ServiceTokens.searchLift,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BackChip(onTap: onBack),
                      Flexible(child: _StepPill(step: step, totalSteps: totalSteps)),
                    ],
                  ),
                  16.heightSpacer,
                  BaseTextDMSans(
                    text: title,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    lineHeight: 1.12,
                    color: Colors.white,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                  ).tr(),
                  7.heightSpacer,
                  BaseTextDMSans(
                    text: subtitle,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    lineHeight: 1.45,
                    color: const Color(0xFFDCD2FF),
                    textAlign: TextAlign.start,
                    maxLines: 3,
                  ).tr(),
                  16.heightSpacer,
                  _ProgressSegments(step: step, totalSteps: totalSteps),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Get.back(),
        borderRadius: BorderRadius.circular(12.getSize),
        child: Container(
          height: 38.getSize,
          width: 38.getSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12.getSize),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(Icons.chevron_left, size: 22.getSize, color: Colors.white),
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 6.getSize),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: BaseTextDMSans(
        text: '${tr(StringRes.stepLabel)} $step ${tr(StringRes.of)} $totalSteps',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFD9CFFF),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          Expanded(
            child: Container(
              height: 4.getSize,
              decoration: BoxDecoration(
                color: i <= step ? Colors.white : Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(4.getSize),
              ),
            ),
          ),
          if (i != totalSteps) 6.widthSpacer,
        ],
      ],
    );
  }
}

// ── Page body ─────────────────────────────────────────────────────────────

/// The page: header, then the scrolling board, then the pinned footer.
///
/// The header scrolls with the content rather than being pinned above an
/// [Expanded]. Pinning looks right until the viewport is short — a small
/// phone, or any phone with the keyboard up — and then the header plus the
/// footer exceed the height, the Expanded collapses to zero, and the body
/// renders as a blank gap under a perfectly healthy-looking header. That
/// failure reads as "the API returned nothing" rather than as a layout bug,
/// which makes it expensive to diagnose; scrolling everything cannot overflow
/// at any size. `base_auth.dart` reached the same conclusion for the auth
/// screens.
class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.header,
    required this.children,
    required this.footer,
  });

  final ServicesHeader header;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ServiceTokens.bg,
      bottomNavigationBar: footer,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Transform.translate(
              // Lifts the board so the search row sits across the header's
              // bottom edge. The header already reserved this height, so
              // nothing below it moves.
              offset: Offset(0, -ServiceTokens.searchLift),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.getSize, 0, 18.getSize, 20.getSize),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search row ────────────────────────────────────────────────────────────

/// Search field plus the filter button beside it.
///
/// The button clears the active narrowing (search text, and the chip filter
/// when the screen has one) — it lights up only when there is something to
/// clear, so it never looks tappable while it would be a no-op.
class ServicesSearchBar extends StatelessWidget {
  const ServicesSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.filterActive,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool filterActive;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.getSize, vertical: 4.getSize),
            decoration: BoxDecoration(
              color: ServiceTokens.card,
              borderRadius: BorderRadius.circular(14.getSize),
              border: Border.all(color: ServiceTokens.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24.getSize,
                  offset: Offset(0, 10.getSize),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 17.getSize, color: ServiceTokens.muted),
                9.widthSpacer,
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    cursorColor: ServiceTokens.purple,
                    style: TextStyle(
                      fontFamily: FontFamily.dmSans,
                      fontSize: 13.getFontSize,
                      color: ServiceTokens.text,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.getSize),
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontFamily: FontFamily.dmSans,
                        fontSize: 13.getFontSize,
                        color: ServiceTokens.muted2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        10.widthSpacer,
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: filterActive ? onFilterTap : null,
            borderRadius: BorderRadius.circular(14.getSize),
            child: Container(
              height: 46.getSize,
              width: 46.getSize,
              decoration: BoxDecoration(
                color: filterActive ? ServiceTokens.purple : ServiceTokens.card,
                borderRadius: BorderRadius.circular(14.getSize),
                border: Border.all(
                  color: filterActive ? ServiceTokens.purple : ServiceTokens.stroke,
                ),
                boxShadow: [
                  BoxShadow(
                    color: filterActive
                        ? ServiceTokens.purple.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24.getSize,
                    offset: Offset(0, 10.getSize),
                  ),
                ],
              ),
              child: Icon(
                filterActive ? Icons.filter_alt_off_outlined : Icons.tune,
                size: 19.getSize,
                color: filterActive ? Colors.white : ServiceTokens.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────

class ServicesChip extends StatelessWidget {
  const ServicesChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.getSize),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 17.getSize, vertical: 9.getSize),
          decoration: BoxDecoration(
            color: selected ? ServiceTokens.purple : ServiceTokens.card,
            borderRadius: BorderRadius.circular(22.getSize),
            border: Border.all(
              color: selected ? ServiceTokens.purple : ServiceTokens.stroke,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ServiceTokens.purple.withValues(alpha: 0.42),
                      blurRadius: 16.getSize,
                      offset: Offset(0, 6.getSize),
                    ),
                  ]
                : null,
          ),
          child: BaseTextDMSans(
            text: label,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : ServiceTokens.muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── Stat tiles ────────────────────────────────────────────────────────────

/// One of the two counters above a section — "7 / 40 Subcategories".
class ServicesStatTile extends StatelessWidget {
  const ServicesStatTile({
    super.key,
    required this.value,
    required this.label,
    this.suffix = '',
    this.valueColor,
  });

  /// The emphasised number.
  final String value;

  /// The dimmer part after it — "/ 40", "left", "city".
  final String suffix;

  /// The caption under both.
  final String label;

  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.getSize, vertical: 12.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(14.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: FontFamily.dmSans,
                    fontSize: 19.getFontSize,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? Colors.white,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      fontFamily: FontFamily.dmSans,
                      fontSize: 13.getFontSize,
                      fontWeight: FontWeight.w600,
                      color: ServiceTokens.muted2,
                    ),
                  ),
              ],
            ),
          ),
          3.heightSpacer,
          BaseTextDMSans(
            text: label,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ServiceTokens.muted,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The two tiles side by side.
class ServicesStatRow extends StatelessWidget {
  const ServicesStatRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight, not a bare `crossAxisAlignment: stretch`: this Row
    // lives inside a scroll view, so its incoming height is unbounded, and
    // stretch against an unbounded constraint throws ("forces an infinite
    // height") rather than merely looking wrong. IntrinsicHeight gives the
    // Row a real height to stretch into, so the tiles match even when one
    // caption wraps and the other does not.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          8.widthSpacer,
          Expanded(child: right),
        ],
      ),
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────

/// The card a category (or a city) and its rows live in.
class ServicesGroupCard extends StatelessWidget {
  const ServicesGroupCard({
    super.key,
    required this.header,
    this.rows = const [],
    this.footer,
  });

  final Widget header;
  final List<Widget> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 13.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(18.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.getSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            ...rows,
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// The card's top row: icon tile, name, count line, badge, caret.
class ServicesGroupHead extends StatelessWidget {
  const ServicesGroupHead({
    super.key,
    required this.title,
    required this.countLine,
    required this.fallbackIcon,
    this.iconUrl,
    this.badge,
    this.expanded,
    this.onTap,
  });

  final String title;

  /// "2 of 4 selected", or "Tap to choose" when nothing is picked yet.
  final String countLine;

  final IconData fallbackIcon;
  final String? iconUrl;

  /// The green/muted pill on the right.
  final Widget? badge;

  /// null hides the caret — used by groups that never collapse.
  final bool? expanded;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15.getSize, vertical: 14.getSize),
          child: Row(
            children: [
              _IconTile(iconUrl: iconUrl, fallback: fallbackIcon),
              12.widthSpacer,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BaseTextDMSans(
                      text: title,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    2.heightSpacer,
                    BaseTextDMSans(
                      text: countLine,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: ServiceTokens.muted,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[8.widthSpacer, badge!],
              if (expanded != null) ...[
                4.widthSpacer,
                Icon(
                  expanded! ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18.getSize,
                  color: ServiceTokens.muted2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({this.iconUrl, required this.fallback});

  final String? iconUrl;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.getSize,
      width: 44.getSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ServiceTokens.purpleBright.withValues(alpha: 0.28),
            ServiceTokens.purple.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(13.getSize),
        border: Border.all(color: ServiceTokens.purpleBright.withValues(alpha: 0.25)),
      ),
      child: iconUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(13.getSize),
              child: Image.network(
                iconUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, size: 21.getSize, color: ServiceTokens.purpleBright),
              ),
            )
          : Icon(fallback, size: 21.getSize, color: ServiceTokens.purpleBright),
    );
  }
}

/// Green "N picked" / "All" badge, or the muted "0" zero-state.
class ServicesBadge extends StatelessWidget {
  const ServicesBadge({super.key, required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.getSize, vertical: 5.getSize),
      decoration: BoxDecoration(
        color: muted
            ? ServiceTokens.muted.withValues(alpha: 0.10)
            : ServiceTokens.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(
          color: muted
              ? ServiceTokens.stroke2
              : ServiceTokens.green.withValues(alpha: 0.22),
        ),
      ),
      child: BaseTextDMSans(
        text: label,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: muted ? ServiceTokens.muted : ServiceTokens.green,
        maxLines: 1,
      ),
    );
  }
}

// ── Rows ──────────────────────────────────────────────────────────────────

/// One selectable line inside a card — a subcategory, or a zone.
class ServicesRow extends StatelessWidget {
  const ServicesRow({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.trailingTag,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  /// Small muted pill on the right — "Popular", a region name.
  final String? trailingTag;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Selected rows carry a left-to-right violet wash, as in the spec.
        gradient: selected
            ? LinearGradient(
                colors: [
                  ServiceTokens.purple.withValues(alpha: 0.10),
                  ServiceTokens.purple.withValues(alpha: 0.0),
                ],
              )
            : null,
        border: Border(top: BorderSide(color: ServiceTokens.stroke)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.getSize, 11.getSize, 15.getSize, 11.getSize),
            child: Row(
              children: [
                ServicesCheckbox(selected: selected, enabled: enabled, onTap: onTap),
                11.widthSpacer,
                Expanded(
                  child: BaseTextDMSans(
                    text: label,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: !enabled
                        ? ServiceTokens.muted2.withValues(alpha: 0.5)
                        : (selected ? Colors.white : ServiceTokens.text),
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingTag != null) ...[
                  8.widthSpacer,
                  _TagPill(label: trailingTag!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square checkbox — filled violet with a white tick when on, a thin
/// outline when off, dimmed when the plan quota has locked it.
class ServicesCheckbox extends StatelessWidget {
  const ServicesCheckbox({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.size,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final box = size ?? 22.getSize;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: box,
        width: box,
        decoration: BoxDecoration(
          color: selected
              ? (enabled ? ServiceTokens.purple : ServiceTokens.purple.withValues(alpha: 0.4))
              : ServiceTokens.card2,
          borderRadius: BorderRadius.circular(7.getSize),
          border: Border.all(
            color: selected
                ? ServiceTokens.purple
                : (enabled
                    ? ServiceTokens.stroke2
                    : ServiceTokens.stroke2.withValues(alpha: 0.5)),
            width: 1.6,
          ),
        ),
        child: selected
            ? Icon(Icons.check, size: box * 0.62, color: Colors.white)
            : null,
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.getSize, vertical: 3.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card2,
        borderRadius: BorderRadius.circular(8.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: BaseTextDMSans(
        text: label,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: ServiceTokens.muted2,
        maxLines: 1,
      ),
    );
  }
}

/// The card's bottom strip: a "Select all" action on the left, a running
/// count on the right.
class ServicesCardFooter extends StatelessWidget {
  const ServicesCardFooter({
    super.key,
    required this.actionLabel,
    required this.onAction,
    required this.trailing,
    this.actionEnabled = true,
  });

  final String actionLabel;
  final VoidCallback onAction;
  final String trailing;
  final bool actionEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ServiceTokens.stroke)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: actionEnabled ? onAction : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.getSize, vertical: 11.getSize),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: BaseTextDMSans(
                    text: actionLabel,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: actionEnabled
                        ? ServiceTokens.purpleBright
                        : ServiceTokens.muted2.withValues(alpha: 0.6),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                8.widthSpacer,
                Flexible(
                  child: BaseTextDMSans(
                    text: trailing,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────

/// The pinned bottom action: a dim hint line, then the gradient CTA with its
/// running count.
class ServicesFooter extends StatelessWidget {
  const ServicesFooter({
    super.key,
    required this.hint,
    required this.label,
    required this.onPressed,
    this.countLabel,
  });

  /// Already-formatted, e.g. "10 subcategories left in the Pro plan".
  final String hint;

  /// Translation key for the button.
  final String label;

  final VoidCallback onPressed;

  /// Already-formatted, e.g. "7 selected". Null hides the badge.
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 18.getSize,
        right: 18.getSize,
        top: 14.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22.getSize,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [ServiceTokens.bg, ServiceTokens.bg, Color(0x000C0A16)],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint.isNotEmpty) ...[
            BaseTextDMSans(
              text: hint,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ServiceTokens.muted2,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            10.heightSpacer,
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16.getSize),
              child: Container(
                height: 52.getSize,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ServiceTokens.purpleBright, ServiceTokens.purple],
                  ),
                  borderRadius: BorderRadius.circular(16.getSize),
                  boxShadow: [
                    BoxShadow(
                      color: ServiceTokens.purple.withValues(alpha: 0.5),
                      blurRadius: 30.getSize,
                      offset: Offset(0, 12.getSize),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: BaseTextDMSans(
                        text: label,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).tr(),
                    ),
                    if (countLabel != null) ...[
                      9.widthSpacer,
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9.getSize,
                            vertical: 3.getSize,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20.getSize),
                          ),
                          child: BaseTextDMSans(
                            text: countLabel!,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred dim message for "nothing matched your search".
class ServicesEmptyState extends StatelessWidget {
  const ServicesEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.getSize),
      child: Center(
        child: BaseTextDMSans(
          text: message,
          fontSize: 13,
          color: ServiceTokens.muted2,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
