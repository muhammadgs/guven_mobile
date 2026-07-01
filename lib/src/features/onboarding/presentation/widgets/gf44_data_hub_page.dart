import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';

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
          final double subtitleT = _interval(swipe, 0.24, 0.62);
          final double iconsT = _interval(swipe, 0.08, 1);

          return LayoutBuilder(
            builder: (context, constraints) {
              final Size screen = MediaQuery.sizeOf(context);
              final double bottom = 132 + MediaQuery.paddingOf(context).bottom;
              final double horizontalPadding = (screen.width * 0.055).clamp(18.0, 24.0).toDouble();
              final double contentWidth = constraints.maxWidth - horizontalPadding * 2;
              final double gapX = (screen.width * 0.075).clamp(24.0, 38.0).toDouble();
              final double cellWidth = ((contentWidth - gapX) / 2).clamp(118.0, 160.0).toDouble();
              final double subtitleTop = (screen.height * 0.43).clamp(342.0, 418.0).toDouble();
              final double subtitleSize = (screen.width * 0.066).clamp(21.0, 29.0).toDouble();
              final double iconSize = (screen.width * 0.15).clamp(50.0, 66.0).toDouble();
              final double labelSize = (screen.width * 0.041).clamp(14.0, 18.0).toDouble();
              final double gapY = (screen.height * 0.085).clamp(58.0, 84.0).toDouble();

              return Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottom),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      top: subtitleTop,
                      left: 0,
                      right: 0,
                      child: _BlurText(
                        progress: subtitleT,
                        text: 'GF44 ilə məlumatlarınızı\nmərkəzləşdirilmiş şəkildə idarə edin.',
                        fontSize: subtitleSize,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.50),
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
                  ],
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
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: labelSize, height: 1.15, letterSpacing: -0.1, shadows: _shadows),
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

class _BlurText extends StatelessWidget {
  const _BlurText({required this.progress, required this.text, required this.fontSize});
  final double progress;
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0).toDouble();
    return Opacity(
      opacity: Curves.easeOut.transform(t),
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - t)),
        child: blurred(
          14 * (1 - t),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: fontSize, height: 1.18, letterSpacing: -0.2, shadows: _shadows)),
        ),
      ),
    );
  }
}

const List<Shadow> _shadows = <Shadow>[
  Shadow(color: Color(0x30000000), blurRadius: 18, offset: Offset(0, 6)),
];
