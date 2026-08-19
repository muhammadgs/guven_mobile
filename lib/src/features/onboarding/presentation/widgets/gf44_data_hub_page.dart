import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../../../shared/settled_page_controller.dart';
import '../onboarding_metrics.dart';
import 'swipe_responsive_brand_lockup.dart' show kOnboardingTextShadows;

/// The 2×2 feature grid on the third page.
///
/// Anchored to [Gf44HeadlineGeometry.bottom] — the real underside of the
/// floating "GF44" block, subtitle included — rather than aligned inside the
/// leftover space, which is what used to drop the headline onto the icons.
class Gf44DataHubPage extends StatelessWidget {
  const Gf44DataHubPage({
    super.key,
    required this.pageController,
    required this.pageIndex,
  });

  final SettledPageController pageController;
  final int pageIndex;

  static const List<_FeatureIconData> _items = <_FeatureIconData>[
    _FeatureIconData('assets/videos/page_3_icons/icon_1.webp',
        'Şirkət və Partnyorlar', -1, -1, Icons.business_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_2.webp', 'Əməkdaşlar', 1,
        -1, Icons.groups_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_3.webp', 'Tapşırıqlar',
        -1, 1, Icons.checklist_rtl_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_4.webp',
        'Baza inteqrasiyası', 1, 1, Icons.hub_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        final double swipe =
            (_page - (pageIndex - 1)).clamp(0.0, 1.0).toDouble();
        final double iconsT = _interval(swipe, 0.18, 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final Size screen = MediaQuery.sizeOf(context);
            final OnboardingMetrics metrics = OnboardingMetrics.of(context);

            final double horizontalPadding =
                responsive(context, factor: 0.055, min: 18, max: 24);
            final double contentWidth =
                constraints.maxWidth - horizontalPadding * 2;
            final double gapX =
                responsive(context, factor: 0.075, min: 24, max: 38);
            final double cellWidth = ((contentWidth - gapX) / 2)
                .clamp(metrics.px(118), metrics.px(160))
                .toDouble();
            final double iconSize =
                responsive(context, factor: 0.15, min: 50, max: 66);
            final double labelSize =
                responsive(context, factor: 0.034, min: 12, max: 15);

            final double top = metrics.dataHubBodyTop;
            final double rowHeight = iconSize +
                metrics.px(12) +
                metrics.lineHeight(labelSize, 1.15);
            // The rows sit as far apart as the room below the subtitle allows,
            // up to the gap the design asks for.
            final double slack = metrics.floor - top - rowHeight * 2;
            final double gapY =
                math.min(metrics.px(66), math.max(slack, metrics.px(16)));

            return Stack(
              children: <Widget>[
                Positioned(
                  top: top,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(0, metrics.floor - top),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _row(0, 1, iconsT, screen, cellWidth, iconSize,
                              labelSize, gapX),
                          SizedBox(height: gapY),
                          _row(2, 3, iconsT, screen, cellWidth, iconSize,
                              labelSize, gapX),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _row(
    int left,
    int right,
    double progress,
    Size screen,
    double cellWidth,
    double iconSize,
    double labelSize,
    double gapX,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _FeatureIcon(
            item: _items[left],
            progress: progress,
            screen: screen,
            cellWidth: cellWidth,
            iconSize: iconSize,
            labelSize: labelSize),
        SizedBox(width: gapX),
        _FeatureIcon(
            item: _items[right],
            progress: progress,
            screen: screen,
            cellWidth: cellWidth,
            iconSize: iconSize,
            labelSize: labelSize),
      ],
    );
  }

  double get _page => pageController.settledPage;

  static double _interval(double value, double start, double end) {
    final double raw =
        ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
    return Curves.easeOutCubic.transform(raw);
  }
}

class _FeatureIconData {
  const _FeatureIconData(
      this.imagePath, this.label, this.xSign, this.ySign, this.fallbackIcon);
  final String imagePath;
  final String label;
  final double xSign;
  final double ySign;
  final IconData fallbackIcon;
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon(
      {required this.item,
      required this.progress,
      required this.screen,
      required this.cellWidth,
      required this.iconSize,
      required this.labelSize});
  final _FeatureIconData item;
  final double progress;
  final Size screen;
  final double cellWidth;
  final double iconSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: cellWidth,
      child: Opacity(
        opacity: Curves.easeOut.transform(t),
        child: Transform.translate(
          offset: Offset(item.xSign * screen.width * 0.68 * (1 - t),
              item.ySign * 54 * (1 - t)),
          child: Transform.scale(
            scale: 0.92 + 0.08 * t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: _AnimatedIconImage(
                    imagePath: item.imagePath,
                    fallbackIcon: item.fallbackIcon,
                  ),
                ),
                SizedBox(height: scaled(context, 12)),
                SizedBox(
                  width: cellWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: labelSize,
                          height: 1.15,
                          letterSpacing: -0.1,
                          shadows: kOnboardingTextShadows),
                    ),
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

class _AnimatedIconImage extends StatelessWidget {
  const _AnimatedIconImage(
      {required this.imagePath, required this.fallbackIcon});

  final String imagePath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return _FallbackIcon(icon: fallbackIcon);
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, color: Colors.white, size: 38),
    );
  }
}
