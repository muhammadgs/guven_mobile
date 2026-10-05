/// What every card on the `Baza` tab is made of: the tinted pane over a
/// shared blur, the number-and-date line at its top, and the two faces its
/// words are set in.
///
/// `Satışlar`' and `Stok`'s designs draw the same card — the same yellow, the
/// same corner, the same first line — and differ only in the rows under it,
/// so this is the part they share rather than two copies that could drift.
library;

import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

import 'database_glass.dart';

/// What a field says when the bridge does not say it.
const String kUnknownValue = '—';

/// The pane: [kDatabaseCardFill] over a blur of whatever is behind it,
/// rounded to [kDatabaseCardRadius].
///
/// Not glass. A list that can run to thousands of cards gets one blur for
/// all of them — the list's `BackdropGroup` — and a flat tint per card, never
/// a lens each.
class DatabaseCardSurface extends StatelessWidget {
  const DatabaseCardSurface({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(kDatabaseCardRadius * s),
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(
          sigmaX: kDatabaseRowBlurSigma,
          sigmaY: kDatabaseRowBlurSigma,
        ),
        child: ColoredBox(
          color: kDatabaseCardFill,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A card's words: Poppins at [size], in the design's ink.
TextStyle databaseCardStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  FontStyle style = FontStyle.normal,
  double height = 1.2,
  Color color = kGlassInk,
}) => TextStyle(
  fontFamily: 'Poppins',
  fontWeight: weight,
  fontStyle: style,
  fontSize: size,
  height: height,
  letterSpacing: 0,
  color: color,
);

/// A card's names — a customer, a product: CalSans, the app's display face,
/// at the design's 15pt on its frame.
TextStyle databaseCardNameStyle(double scale) => TextStyle(
  fontFamily: 'CalSans',
  fontSize: 15 * scale,
  height: 1.2,
  letterSpacing: 0,
  color: kGlassInk,
);

/// A run of rows only an open card has, let in at [t] of its height.
///
/// Clipped rather than squashed, so it is uncovered from the top the way a
/// drawer opens, and faded by [fade] so the words do not arrive as a sliver.
/// `Satışlar`' cards and `Sifarişlər`' open alike through it.
class DatabaseCardReveal extends StatelessWidget {
  const DatabaseCardReveal({
    super.key,
    required this.t,
    required this.fade,
    required this.children,
  });

  final double t;
  final double fade;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: t,
        child: Opacity(
          opacity: fade,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// How far into an opening card its open-only rows start to show: they are
/// held back until the shut rows are well on their way, so they arrive into
/// room already made rather than on top of text still moving out of it.
double databaseCardFade(double t) => ((t - 0.35) / 0.65).clamp(0.0, 1.0);

/// A card's first line: its number on the left, its date on the right, on
/// one baseline.
class DatabaseCardHeading extends StatelessWidget {
  const DatabaseCardHeading({
    super.key,
    required this.number,
    required this.date,
    required this.scale,
  });

  final String? number;
  final String? date;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final String? date = this.date;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            // Numbers are short, but a long one is set smaller rather than
            // cut: a number with its tail missing names a different thing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                number ?? kUnknownValue,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: kDatabaseFigureFont,
                  fontSize: 14 * s,
                  height: 1.2,
                  letterSpacing: 0,
                  color: kGlassInk,
                ),
              ),
            ),
          ),
        ),
        if (date != null) ...<Widget>[
          SizedBox(width: 12 * s),
          Text(
            date,
            maxLines: 1,
            softWrap: false,
            style: databaseCardStyle(14 * s, style: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}
