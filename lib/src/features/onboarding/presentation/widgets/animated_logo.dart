import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/effects.dart';

/// The Güvən Finans mark, animated as if it is being assembled "from scratch".
///
/// The source SVG ([_assetPath]) is split into its individual `<path>` pieces;
/// each piece fades and un-blurs from a small offset on a staggered timeline so
/// the logo resolves out of soft, blurry fragments into its final crisp form.
class AnimatedGuvenLogo extends StatefulWidget {
  const AnimatedGuvenLogo({
    super.key,
    required this.width,
    this.delay = Duration.zero,
    this.progress,
  });

  final double width;
  final Duration delay;

  /// Optional externally-owned timeline progress. When provided, this widget
  /// becomes deterministic and does not run its private controller.
  final double? progress;

  static const String _assetPath = 'assets/images/logos/logo.svg';

  // Intrinsic aspect ratio of the source artwork (viewBox 177 x 98).
  static const double _aspect = 177 / 98;

  @override
  State<AnimatedGuvenLogo> createState() => _AnimatedGuvenLogoState();
}

class _AnimatedGuvenLogoState extends State<AnimatedGuvenLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Pre-built SVG widgets, one per source path. Built once so flutter_svg
  /// never re-parses the (large) path data on an animation frame.
  List<Widget>? _pieces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _loadPieces();
  }

  Future<void> _loadPieces() async {
    final List<String> svgs = await _GuvenLogoSvg.pieces(
      AnimatedGuvenLogo._assetPath,
    );
    if (!mounted) return;
    setState(() {
      _pieces = <Widget>[
        for (final String svg in svgs)
          SvgPicture.string(svg, fit: BoxFit.contain),
      ];
    });
    if (widget.progress == null) {
      await Future<void>.delayed(widget.delay);
      if (mounted) _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double height = widget.width / AnimatedGuvenLogo._aspect;
    final List<Widget>? pieces = _pieces;

    if (pieces == null) {
      return SizedBox(width: widget.width, height: height);
    }

    return SizedBox(
      width: widget.width,
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double progress =
              (widget.progress ?? _controller.value).clamp(0.0, 1.0);
          return Stack(
            children: <Widget>[
              for (int i = 0; i < pieces.length; i++)
                Positioned.fill(
                  child: _animatePiece(
                    i,
                    pieces.length,
                    pieces[i],
                    progress,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Staggers each piece across the timeline and applies the
  /// blur → opacity → settle transform for its current progress.
  Widget _animatePiece(int index, int count, Widget child, double progress) {
    final double order = count <= 1 ? 0.0 : index / (count - 1);
    final double start = order * 0.34;
    final double end = (start + 0.64).clamp(0.0, 1.0);
    final double raw = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(raw);

    final double sigma = (1 - eased) * 18;
    final double opacity = Curves.easeOut.transform(raw);
    final double scale = 1.08 - 0.08 * eased;
    final double angle = (order - 0.5) * 1.6;
    final double radius = (1 - eased) * 22;
    final double dx = radius * angle;
    final double dy = (1 - eased) * (10 - order * 16);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: blurred(sigma, child),
        ),
      ),
    );
  }
}

/// Loads the logo SVG once and splits it into one standalone SVG document per
/// `<path>`, preserving the original `viewBox` so the pieces stay registered.
class _GuvenLogoSvg {
  _GuvenLogoSvg._();

  static final Map<String, List<String>> _cache = <String, List<String>>{};

  static Future<List<String>> pieces(String assetPath) async {
    final List<String>? cached = _cache[assetPath];
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(assetPath);
    final String viewBox =
        RegExp(r'viewBox="([^"]*)"').firstMatch(raw)?.group(1) ?? '0 0 177 98';
    final List<String> ds = RegExp(r'd="([^"]*)"')
        .allMatches(raw)
        .map((Match m) => m.group(1)!)
        .toList();

    final List<String> result = ds.isEmpty
        // Fallback: render the document whole if no paths were extracted.
        ? <String>[raw]
        : <String>[
            for (final String d in ds)
              '<svg viewBox="$viewBox" xmlns="http://www.w3.org/2000/svg">'
                  '<path d="$d" fill="white"/></svg>',
          ];

    _cache[assetPath] = result;
    return result;
  }
}
