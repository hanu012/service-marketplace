import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_portfolio_controller.dart';

/// Vendor dashboard, Portfolio tab (SPEC section 3 item 5, task 4.5) —
/// the third destination on the bottom bar.
class VendorPortfolioView extends StatelessWidget {
  const VendorPortfolioView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPortfolioController>(
      init: VendorPortfolioController(),
      dispose: (_) => Get.delete<VendorPortfolioController>(),
      builder: (controller) {
        if (controller.isLoading && controller.media.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: ServiceTokens.accentBright),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchPortfolioAPI,
          color: ServiceTokens.accentBright,
          backgroundColor: ServiceTokens.card,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              hero(controller),
              Transform.translate(
                offset: Offset(0, -34.getSize),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.getSize, 0, 16.getSize, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      quotaRow(controller),
                      18.heightSpacer,
                      if (controller.subcategories.isNotEmpty) ...[
                        BaseTextDMSans(
                          text: tr(StringRes.vendorTagUploads),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ServiceTokens.muted,
                          textAlign: TextAlign.start,
                        ),
                        11.heightSpacer,
                        subcategoryPicker(controller),
                        18.heightSpacer,
                      ],
                      if (controller.isUploading) ...[
                        uploadProgressCard(controller),
                        16.heightSpacer,
                      ],
                      if (controller.visibleMedia.isEmpty)
                        emptyState(controller)
                      else
                        mediaGrid(controller),
                      20.heightSpacer,
                      uploadButtons(controller),
                      24.heightSpacer,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget hero(VendorPortfolioController controller) {
    return VendorHero(
      bottomPadding: 56.getSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VendorBrandRow(
            initials: controller.initials,
            businessName: controller.businessName,
          ),
          18.heightSpacer,
          VendorHeroTitle(
            title: tr(StringRes.vendorPortfolioTitle),
            subtitle: tr(StringRes.vendorPortfolioDesc),
          ),
        ],
      ),
    );
  }

  Widget quotaRow(VendorPortfolioController controller) {
    return Row(
      children: [
        Expanded(
          child: VendorStatTile(
            icon: Icons.photo_outlined,
            label: tr(StringRes.photosLabel),
            used: controller.photosQuota?.used ?? 0,
            max: controller.photosQuota?.max ?? 0,
          ),
        ),
        12.widthSpacer,
        Expanded(
          child: VendorStatTile(
            icon: Icons.videocam_outlined,
            label: tr(StringRes.videosLabel),
            used: controller.videosQuota?.used ?? 0,
            max: controller.videosQuota?.max ?? 0,
          ),
        ),
      ],
    );
  }

  /// Horizontally scrolling rather than wrapping: a vendor on a large plan
  /// can have forty subcategories, and a wrap of those would push the
  /// uploads themselves off the screen.
  Widget subcategoryPicker(VendorPortfolioController controller) {
    return SizedBox(
      height: 42.getSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.subcategories.length,
        separatorBuilder: (_, _) => 9.widthSpacer,
        itemBuilder: (_, index) =>
            subcategoryChip(controller, controller.subcategories[index]),
      ),
    );
  }

  Widget subcategoryChip(
    VendorPortfolioController controller,
    SelectedServiceItemModel subcategory,
  ) {
    final selected = controller.selectedSubcategoryId == subcategory.id;
    final count = controller.mediaCountBySubcategory[subcategory.id] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: subcategory.id == null
            ? null
            : () => controller.selectSubcategory(subcategory.id!),
        borderRadius: BorderRadius.circular(22.getSize),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 16.getSize),
          decoration: BoxDecoration(
            color: selected ? ServiceTokens.accent : ServiceTokens.card,
            borderRadius: BorderRadius.circular(22.getSize),
            border: Border.all(
              color: selected ? ServiceTokens.accent : ServiceTokens.stroke2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BaseTextDMSans(
                text: subcategory.name ?? '',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : ServiceTokens.text,
              ),
              // How much work is filed here, so the vendor can see where
              // their uploads are without tapping through every chip.
              if (count > 0) ...[
                7.widthSpacer,
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 7.getSize,
                    vertical: 2.getSize,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : ServiceTokens.stroke2,
                    borderRadius: BorderRadius.circular(10.getSize),
                  ),
                  child: BaseTextDMSans(
                    text: '$count',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : ServiceTokens.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Live progress for the upload in flight.
  ///
  /// Sits above the grid rather than over it as a blocking overlay: the
  /// vendor can still see what is already there, and a video that takes
  /// half a minute to send does not lock the screen for the duration.
  ///
  /// The bar is determinate while bytes are going out and indeterminate
  /// once they have all been sent — see the controller for why.
  Widget uploadProgressCard(VendorPortfolioController controller) {
    final progress = controller.uploadProgress;
    final isVideo = controller.uploadingType == 'video';

    return Container(
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(14.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VendorIconTile(
                icon: isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
                size: 36,
              ),
              12.widthSpacer,
              Expanded(
                child: BaseTextDMSans(
                  text: tr(
                    isVideo
                        ? StringRes.vendorUploadingVideo
                        : StringRes.vendorUploadingPhoto,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ServiceTokens.text,
                  textAlign: TextAlign.start,
                ),
              ),
              8.widthSpacer,
              BaseTextDMSans(
                // Percent only while it means something; "Finishing" for
                // the server-side stretch after the last byte.
                text: progress == null
                    ? tr(StringRes.vendorUploadFinishing)
                    : '${(progress * 100).round()}%',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ServiceTokens.accentBright,
              ),
            ],
          ),
          12.heightSpacer,
          ClipRRect(
            borderRadius: BorderRadius.circular(6.getSize),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.getSize,
              backgroundColor: ServiceTokens.stroke2,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ServiceTokens.accentBright,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dashed outline rather than a solid card: it reads as a slot waiting
  /// to be filled rather than as content that failed to load.
  Widget emptyState(VendorPortfolioController controller) {
    // Nothing anywhere versus nothing under this one service are
    // different situations, and telling a vendor "No portfolio yet" when
    // they have thirty photos filed elsewhere would just read as a bug.
    final filtered = controller.media.isNotEmpty;
    final serviceName = controller.selectedSubcategoryName;

    return DottedBorderBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VendorIconTile(icon: Icons.photo_outlined, size: 62),
          16.heightSpacer,
          BaseTextDMSans(
            text: filtered
                ? tr(StringRes.vendorNoPortfolioForService)
                : tr(StringRes.vendorNoPortfolio),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ServiceTokens.text,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          8.heightSpacer,
          BaseTextDMSans(
            text: filtered && serviceName != null
                ? tr(
                    StringRes.vendorNoPortfolioForServiceDesc,
                    args: [serviceName],
                  )
                : tr(StringRes.vendorNoPortfolioDesc),
            fontSize: 13.5,
            color: ServiceTokens.muted,
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget mediaGrid(VendorPortfolioController controller) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10.getSize,
        crossAxisSpacing: 10.getSize,
      ),
      itemCount: controller.visibleMedia.length,
      itemBuilder: (_, index) => mediaCard(controller.visibleMedia[index]),
    );
  }

  Widget mediaCard(PortfolioMediaModel item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.getSize),
      child: Material(
        color: ServiceTokens.card2,
        child: InkWell(
          onTap: item.url == null ? null : () => openPreview(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.type == 'video' && item.url != null)
                VendorVideoThumbnail(url: item.url!)
              else if (item.type == 'video')
                Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: ServiceTokens.muted,
                    size: 36.getSize,
                  ),
                )
              else if (item.url != null)
                Image.network(
                  item.url!,
                  fit: BoxFit.cover,
                  // A tile is small, so a spinner here would be more
                  // noise than information — the frame just stays the
                  // card colour until the bytes land.
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 22.getSize,
                      color: ServiceTokens.muted2,
                    ),
                  ),
                ),
              Positioned(
                left: 6.getSize,
                bottom: 6.getSize,
                right: 6.getSize,
                child: statusBadge(item.moderationStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-size view of one upload.
  ///
  /// A tile is a thumbnail — too small to tell whether a photo is the
  /// right one, let alone whether it is any good. Tapping fills the
  /// screen with it: the photo gets every pixel, and the chrome (close,
  /// status) floats over it rather than taking height from it.
  ///
  /// Opened as a full-screen dialog rather than a pushed route, so
  /// dismissing returns to the exact scroll position.
  void openPreview(PortfolioMediaModel item) {
    Get.dialog(
      Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: item.type == 'video'
                  ? VendorVideoPlayer(url: item.url!)
                  : InteractiveViewer(
                      // Pinch-to-zoom: a vendor checking their own
                      // work wants to see the detail, and a fixed
                      // fit-to-width image cannot show it.
                      maxScale: 4,
                      child: Image.network(
                        item.url!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Center(child: previewError()),
                      ),
                    ),
            ),
            // Top bar: close on the left, status on the right, both on a
            // scrim so they stay legible over a bright photo.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12.getSize,
                    8.getSize,
                    12.getSize,
                    0,
                  ),
                  child: Row(
                    children: [
                      VendorIconButton(
                        icon: Icons.close,
                        onTap: Get.back,
                        tooltip: tr(StringRes.cancel),
                      ),
                      const Spacer(),
                      statusBadge(item.moderationStatus),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Videos are not played in-app: there is no player dependency, and
  /// adding one for a preview is not worth the weight. The tile says so
  /// rather than opening a black rectangle.
  Widget previewError() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24.getSize,
        vertical: 48.getSize,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 44.getSize,
            color: ServiceTokens.muted2,
          ),
          12.heightSpacer,
          BaseTextDMSans(
            text: tr(StringRes.imageLoadFailed),
            fontSize: 13.5,
            color: ServiceTokens.muted,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget statusBadge(String? status) {
    final labelKey = switch (status) {
      'approved' => StringRes.moderationApproved,
      'rejected' => StringRes.moderationRejected,
      _ => StringRes.moderationPending,
    };

    final color = switch (status) {
      'approved' => ServiceTokens.green,
      'rejected' => ColorRes.errorColor,
      _ => ServiceTokens.muted,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.getSize, vertical: 4.getSize),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(7.getSize),
      ),
      child: BaseTextDMSans(
        text: labelKey,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ServiceTokens.bg,
        textAlign: TextAlign.center,
      ).tr(),
    );
  }

  Widget uploadButtons(VendorPortfolioController controller) {
    return Row(
      children: [
        Expanded(
          child: VendorPrimaryButton(
            label: tr(StringRes.vendorAddPhoto),
            icon: Icons.photo_camera_outlined,
            enabled: !controller.isUploading,
            onTap: controller.pickAndUploadPhoto,
          ),
        ),
        12.widthSpacer,
        Expanded(
          child: VendorSecondaryButton(
            label: tr(StringRes.vendorAddVideo),
            icon: Icons.videocam_outlined,
            onTap: controller.isUploading ? () {} : controller.pickAndUploadVideo,
          ),
        ),
      ],
    );
  }
}

/// A dashed-outline container. Painted rather than pulled from a package —
/// one empty state does not justify a dependency.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: ServiceTokens.stroke2,
        radius: 18.getSize,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 24.getSize,
          vertical: 38.getSize,
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    // Walk the rounded-rect outline and draw every other segment.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;

      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Plays one portfolio video inside the full-screen preview.
///
/// Stateful because a player owns a platform resource that must be
/// disposed — the rest of this screen is stateless by the project's
/// convention, and this is the one piece that genuinely cannot be.
///
/// Deliberately minimal controls: tap to play/pause, a scrub bar, and a
/// elapsed/total readout. A vendor is checking their own clip, not
/// watching a film, so fullscreen toggles and playback speed would be
/// chrome with nothing behind it.
class VendorVideoPlayer extends StatefulWidget {
  const VendorVideoPlayer({super.key, required this.url});

  final String url;

  @override
  State<VendorVideoPlayer> createState() => _VendorVideoPlayerState();
}

class _VendorVideoPlayerState extends State<VendorVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    try {
      await controller.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Video init error $e');
      }
      await controller.dispose();

      if (mounted) {
        setState(() => _failed = true);
      }
      return;
    }

    // The preview was opened by tapping the clip, so the vendor has
    // already said they want to watch it — waiting for a second tap
    // would just be a step in the way.
    await controller.setLooping(true);
    await controller.play();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(child: videoError());
    }

    final controller = _controller;

    if (controller == null) {
      return const Center(
        child: CupertinoActivityIndicator(color: ServiceTokens.accentBright),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        // Only shown while paused: an overlay sitting on top of a playing
        // video is just something in the way of the video.
        if (!controller.value.isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(14.getSize),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.46),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 44.getSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16.getSize,
                0,
                16.getSize,
                16.getSize,
              ),
              child: controls(controller),
            ),
          ),
        ),
      ],
    );
  }

  Widget controls(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.symmetric(vertical: 10.getSize),
              colors: const VideoProgressColors(
                playedColor: ServiceTokens.accentBright,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
            Row(
              children: [
                BaseTextDMSans(
                  text: formatDuration(value.position),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                const Spacer(),
                BaseTextDMSans(
                  text: formatDuration(value.duration),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// m:ss — portfolio clips are capped at 60 seconds by the picker, so
  /// an hours component would never be anything but zero.
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Widget videoError() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.getSize),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 44.getSize,
            color: ServiceTokens.muted2,
          ),
          12.heightSpacer,
          BaseTextDMSans(
            text: tr(StringRes.videoLoadFailed),
            fontSize: 13.5,
            color: ServiceTokens.muted,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// Poster frame for a video tile in the portfolio grid.
///
/// Decoded on the device: nothing generates a poster server-side at
/// upload time, so the alternative is every video tile looking the same
/// as every other one.
///
/// Results are memoised in [_cache] keyed by URL. The grid rebuilds on
/// every controller [update] — an upload's progress ticks are enough to
/// do it several times a second — and re-decoding a frame out of a
/// multi-megabyte clip each time would make scrolling stutter. The cache
/// is small (one JPEG per video, and a plan caps videos in the single
/// digits) and lives only as long as the process.
class VendorVideoThumbnail extends StatefulWidget {
  const VendorVideoThumbnail({super.key, required this.url});

  final String url;

  @override
  State<VendorVideoThumbnail> createState() => _VendorVideoThumbnailState();
}

class _VendorVideoThumbnailState extends State<VendorVideoThumbnail> {
  static final Map<String, Uint8List?> _cache = {};

  Uint8List? _bytes;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.url)) {
      _bytes = _cache[widget.url];
      _done = true;
      return;
    }

    Uint8List? bytes;

    try {
      bytes = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        // Generous for a grid tile, but the same frame is reused on a
        // high-density screen where the tile is ~360 physical pixels.
        maxWidth: 400,
        quality: 60,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Video thumbnail error $e');
      }
    }

    // Cached even when null: a clip whose frame cannot be decoded should
    // not be retried on every rebuild.
    _cache[widget.url] = bytes;

    if (!mounted) {
      return;
    }

    setState(() {
      _bytes = bytes;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes, fit: BoxFit.cover)
        else if (!_done)
          const Center(
            child: CupertinoActivityIndicator(color: ServiceTokens.muted),
          ),
        // Always drawn: it is what tells a tile apart as a video, and
        // over a real frame it also needs to stay legible, hence the
        // scrim behind it.
        Center(
          child: Container(
            padding: EdgeInsets.all(5.getSize),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: bytes == null ? 0.0 : 0.42),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: bytes == null ? ServiceTokens.muted : Colors.white,
              size: 26.getSize,
            ),
          ),
        ),
      ],
    );
  }
}
