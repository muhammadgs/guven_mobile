import 'package:flutter/widgets.dart';

/// One line of text whose alphabetic baseline sits at [baseline] (screen y),
/// centred across the screen, shrunk only as far as it must to fit
/// [maxWidth].
///
/// The shrink is done on the font size, not with a `FittedBox`: a box that
/// scales its child keeps reporting the unscaled baseline, which would put a
/// shrunk title's baseline in the wrong place.
class PasscodeBaselineText extends StatelessWidget {
  const PasscodeBaselineText({
    super.key,
    required this.text,
    required this.style,
    required this.baseline,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double baseline;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final TextStyle fitted = fitTextStyle(context, text, style, maxWidth);
    final double size = fitted.fontSize ?? 14;
    // Generous room above the baseline for tall glyphs and the clamped
    // system text scale; the Baseline widget does the actual placing.
    final double above = size * 3;
    return Positioned(
      left: 0,
      right: 0,
      top: baseline - above,
      child: Baseline(
        baseline: above,
        baselineType: TextBaseline.alphabetic,
        child: Center(
          child: Text(
            text,
            style: fitted,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// [style] with its size reduced, if need be, so [text] fits one line of
/// [maxWidth] under the context's text scale.
TextStyle fitTextStyle(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  if (width <= maxWidth || width == 0) return style;
  final double size = style.fontSize ?? 14;
  return style.copyWith(fontSize: size * maxWidth / width);
}

/// A label centred on its *capitals* rather than on its line box — a digit
/// on a key looks centred only when its ink is, and a line box carries the
/// font's descender space below it.
class CapCenteredText extends StatelessWidget {
  const CapCenteredText({
    super.key,
    required this.text,
    required this.style,
    required this.capRatio,
  });

  final String text;
  final TextStyle style;

  /// Cap (or figure) height per point of font size.
  final double capRatio;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final double height = painter.height;
    painter.dispose();
    final double cap = scaler.scale(style.fontSize ?? 14) * capRatio;
    // Where the box centre is, minus where the caps' centre is.
    final double shift = height / 2 - (baseline - cap / 2);
    return Transform.translate(
      offset: Offset(0, shift),
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }
}
