import 'package:flutter/material.dart';

class Gf44DataHubPage extends StatelessWidget {
  const Gf44DataHubPage({
    super.key,
    required this.pageController,
    required this.pageIndex,
  });

  final PageController pageController;
  final int pageIndex;

  static const List<_FeatureIconData> _items = <_FeatureIconData>[
    _FeatureIconData('assets/videos/page_3_icons/icon_1.webp', 'Şirkət və Partnyorlar', -1, -1, Icons.business_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_2.webp', 'Əməkdaşlar', 1, -1, Icons.groups_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_3.webp', 'Tapşırıqlar', -1, 1, Icons.checklist_rtl_rounded),
    _FeatureIconData('assets/videos/page_3_icons/icon_4.webp', 'Baza inteqrasiyası', 1, 1, Icons.hub_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: pageController,
        builder: (context, _) {
          final double swipe = (_page - (pageIndex - 1)).clamp(0.0, 1.0).toDouble();
          final double iconsT = _interval(swipe, 0.18, 1);

          return LayoutBuilder(
            builder: (context, constraints) {
              final Size screen = MediaQuery.sizeOf(context);
              final double bottom = 132 + MediaQuery.paddingOf(context).bottom;
              final double horizontalPadding = (screen.width * 0.055).clamp(18.0, 24.0).toDouble();
              final double contentWidth = constraints.maxWidth - horizontalPadding * 2;
              final double gapX = (screen.width * 0.075).clamp(24.0, 38.0).toDouble();
              final double cellWidth = ((contentWidth - gapX) / 2).clamp(118.0, 160.0).toDouble();
              final double iconSize = (screen.width * 0.15).clamp(50.0, 66.0).toDouble();
              final double labelSize = (screen.width * 0.034).clamp(12.0, 15.0).toDouble();
              final double gapY = (screen.height * 0.078).clamp(54.0, 76.0).toDouble();

              return Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottom),
                child: Align(
                  alignment: const Alignment(0, 0.68),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _FeatureIcon(item: _items[0], progress: iconsT, screen: screen, cellWidth: cellWidth, iconSize: iconSize, labelSize: labelSize),
                          SizedBox(width: gapX),
                          _FeatureIcon(item: _items[1], progress: iconsT, screen: screen, cellWidth: cellWidth, iconSize: iconSize, labelSize: labelSize),
                        ],
                      ),
                      SizedBox(height: gapY),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _FeatureIcon(item: _items[2], progress: iconsT, screen: screen, cellWidth: cellWidth, iconSize: iconSize, labelSize: labelSize),
                          SizedBox(width: gapX),
                          _FeatureIcon(item: _items[3], progress: iconsT, screen: screen, cellWidth: cellWidth, iconSize: iconSize, labelSize: labelSize),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  double get _page {
    if (pageController.hasClients && pageController.position.haveDimensions) {
      return pageController.page ?? pageController.initialPage.toDouble();
    }
    return pageController.initialPage.toDouble();
  }

  static double _interval(double value, double start, double end) {
    final double raw = ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
    return Curves.easeOutCubic.transform(raw);
  }
}

class _FeatureIconData {
  const _FeatureIconData(this.imagePath, this.label, this.xSign, this.ySign, this.fallbackIcon);
  final String imagePath;
  final String label;
  final double xSign;
  final double ySign;
  final IconData fallbackIcon;
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.item, required this.progress, required this.screen, required this.cellWidth, required this.iconSize, required this.labelSize});
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
          offset: Offset(item.xSign * screen.width * 0.68 * (1 - t), item.ySign * 54 * (1 - t)),
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
                const SizedBox(height: 12),
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
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: labelSize, height: 1.15, letterSpacing: -0.1, shadows: _shadows),
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
  const _AnimatedIconImage({required this.imagePath, required this.fallbackIcon});

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

const List<Shadow> _shadows = <Shadow>[
  Shadow(color: Color(0x30000000), blurRadius: 18, offset: Offset(0, 6)),
];
