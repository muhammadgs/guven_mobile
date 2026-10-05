import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/order.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One order, shut or open.
///
/// Shut, it is the website's table row: number and date, the amount, the
/// status and the payment. Tapping it opens it into the site's `Sifariş`
/// window: `Cəmi məbləğ` over the amount, then `Endirim`, `Vergi`,
/// `Ödənilən` and `Qalıq borc` in two columns. Like `Satışlar`' card it does
/// not swap one arrangement for the other: the amount and the two flags stay
/// on screen and slide to their new places while the rows only an open card
/// has grow into the gaps.
///
/// The numbers are the design's, measured off its two frames at 1.531px a
/// point: shut, the card is 122.9pt tall with its baselines 25.5, 67.75 and
/// 102pt down; open, 283.9pt, with `Cəmi məbləğ` at 54, the amount at 80.15,
/// the figures' headings at 116.7 and 182.9, the figures at 144.5 and 210.55
/// and the flags at 259.9. Set in the real faces on that frame, the gaps
/// below land every one within 0.1pt. The design's two rows of figures sit
/// a point or two apart sideways; they are set on one grid here.
class OrderCard extends StatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  /// The row, with the order's own answer laid over it once that is known.
  final Order order;

  /// Whether the card is open. Owned by the list, not the card, so a card
  /// scrolled far enough away to be rebuilt comes back the way it was left.
  final bool expanded;

  final VoidCallback onToggle;

  /// True while the order's own answer is on its way.
  final bool loading;

  /// Why the order's own answer could not be read, or null.
  final String? error;

  /// Asks for the order's own answer again after [error].
  final VoidCallback onRetry;

  /// The design's padding: 23pt either side, 12.2pt above the first line —
  /// `Stok`'s, which puts the number's baseline on the same 25.5pt — and
  /// 17.26pt under the flags of a shut card.
  static const double kPadH = 23;
  static const double kPadTop = 12.2;
  static const double kPadBottom = 17.26;

  /// An open card's flags sit this much further from its bottom edge.
  static const double kOpenPadExtra = 3.07;

  /// Shut: from the number's line to the amount, and on to the flags.
  static const double kShutAmountGap = 17.54;
  static const double kShutFlagsGap = 15.82;

  /// Open: from the number's line to `Cəmi məbləğ`, and on to the amount;
  /// from the amount to the figures, between their two rows, and on to the
  /// flags.
  static const double kOpenLabelGap = 11.42;
  static const double kLabelAmountGap = 1.52;
  static const double kOpenFiguresGap = 18.17;
  static const double kFigureRowGap = 20.1;
  static const double kFiguresFlagsGap = 30.95;

  /// From a figure's heading to the figure.
  static const double kFigureHeadingGap = 5.05;

  /// Where the right-hand column of figures starts: the design's 185pt of
  /// the 317 the card's content is wide, kept as a share so a wider screen
  /// keeps the proportion.
  static const int kLeftColumnFlex = 185;
  static const int kRightColumnFlex = 132;

  /// The second flag's column: it starts 91pt after the first unless the
  /// first is longer than [kFlagColumn], as `Satışlar`' does.
  static const double kFlagColumn = 76;
  static const double kFlagGap = 15;

  /// The amount's and the figures' type.
  static const double kAmountSize = 22;
  static const double kFigureSize = 20;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  // `Satışlar`' timing, so the lists open alike.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
    value: widget.expanded ? 1 : 0,
  );

  late final Animation<double> _open = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every number on this card is the design's, on its own frame.
    final double s = databaseScale(context);

    return Semantics(
      button: true,
      expanded: widget.expanded,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: DatabaseCardSurface(
          padding: EdgeInsets.fromLTRB(
            OrderCard.kPadH * s,
            OrderCard.kPadTop * s,
            OrderCard.kPadH * s,
            OrderCard.kPadBottom * s,
          ),
          child: AnimatedBuilder(
            animation: _open,
            builder: (BuildContext context, _) => _Body(
              order: widget.order,
              t: _open.value,
              scale: s,
              loading: widget.loading,
              error: widget.error,
              onRetry: widget.onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's contents at [t] of the way open: one column in both states,
/// so the blend is a matter of gaps, and at 0 and 1 it is exactly one of the
/// two designs.
class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.t,
    required this.scale,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Order order;
  final double t;
  final double scale;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double fade = databaseCardFade(t);
    final bool opening = t > 0;
    final double? amount = order.amount;
    final String? error = this.error;

    // A figure only the order's own answer carries is held open, empty,
    // while that answer is on its way, rather than saying `—` and taking it
    // back.
    String figure(double? value) {
      if (value != null) return formatMoney(value);
      return loading ? ' ' : kUnknownValue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DatabaseCardHeading(number: order.number, date: order.date, scale: s),
        SizedBox(
          height:
              lerpDouble(
                OrderCard.kShutAmountGap,
                OrderCard.kOpenLabelGap,
                t,
              )! *
              s,
        ),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              _Line(text: 'Cəmi məbləğ:', style: databaseCardStyle(14 * s)),
              SizedBox(height: OrderCard.kLabelAmountGap * s),
            ],
          ),
        _Line(
          text: amount == null ? kUnknownValue : formatMoney(amount),
          style: databaseCardStyle(
            OrderCard.kAmountSize * s,
            weight: FontWeight.w700,
          ),
        ),
        SizedBox(
          height:
              lerpDouble(
                OrderCard.kShutFlagsGap,
                OrderCard.kOpenFiguresGap,
                t,
              )! *
              s,
        ),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              _Figures(
                left: ('Endirim:', figure(order.discount)),
                right: ('Vergi:', figure(order.tax)),
                scale: s,
              ),
              SizedBox(height: OrderCard.kFigureRowGap * s),
              _Figures(
                left: ('Ödənilən:', figure(order.paid)),
                right: ('Qalıq borc:', figure(order.remaining)),
                scale: s,
              ),
              if (error != null)
                _Failure(message: error, onRetry: onRetry, scale: s),
              SizedBox(height: OrderCard.kFiguresFlagsGap * s),
            ],
          ),
        _Flags(order: order, scale: s),
        SizedBox(height: OrderCard.kOpenPadExtra * t * s),
      ],
    );
  }
}

/// One line that never breaks and is never cut: one too wide for its room —
/// there is none in the data — is set smaller instead.
class _Line extends StatelessWidget {
  const _Line({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

/// A row of two figures, each under its heading: the left one at the
/// content's edge, the right one where the design starts its column.
class _Figures extends StatelessWidget {
  const _Figures({
    required this.left,
    required this.right,
    required this.scale,
  });

  final (String, String) left;
  final (String, String) right;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: OrderCard.kLeftColumnFlex,
          child: _Figure(heading: left.$1, value: left.$2, scale: scale),
        ),
        Expanded(
          flex: OrderCard.kRightColumnFlex,
          child: _Figure(heading: right.$1, value: right.$2, scale: scale),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.heading,
    required this.value,
    required this.scale,
  });

  final String heading;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Line(text: heading, style: databaseCardStyle(14 * s)),
        SizedBox(height: OrderCard.kFigureHeadingGap * s),
        _Line(text: value, style: databaseCardStyle(OrderCard.kFigureSize * s)),
      ],
    );
  }
}

/// The status and the payment, in the website's colours: green once there,
/// blue on the way, red stopped.
class _Flags extends StatelessWidget {
  const _Flags({required this.order, required this.scale});

  final Order order;
  final double scale;

  static Color _ink(OrderTone? tone) => switch (tone) {
    OrderTone.done => kSaleDone,
    OrderTone.underway => kOrderUnderway,
    OrderTone.stopped => kSalePending,
    null => kGlassInk,
  };

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final String? status = order.status;
    final String? payment = order.payment;

    Widget flag(String text, OrderTone? tone) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: databaseCardStyle(14 * s, color: _ink(tone)),
      ),
    );

    return Row(
      children: <Widget>[
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: OrderCard.kFlagColumn * s),
            child: flag(
              status == null ? kUnknownValue : OrderStatus.labelOf(status),
              OrderStatus.byCode(status)?.tone,
            ),
          ),
        ),
        SizedBox(width: OrderCard.kFlagGap * s),
        Flexible(
          child: flag(
            payment == null ? kUnknownValue : OrderPayment.labelOf(payment),
            OrderPayment.byCode(payment)?.tone,
          ),
        ),
      ],
    );
  }
}

/// The order's own answer did not come: why, and a way to ask again. The
/// figures above it say `—` meanwhile.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    required this.onRetry,
    required this.scale,
  });

  final String message;
  final VoidCallback onRetry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Padding(
      padding: EdgeInsets.only(top: 10 * s),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: databaseCardStyle(
                11 * s,
                height: 1.35,
                color: kGlassInkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kGlassInk,
              visualDensity: VisualDensity.compact,
              textStyle: databaseCardStyle(11 * s, weight: FontWeight.w600),
            ),
            child: const Text('Yenidən cəhd et'),
          ),
        ],
      ),
    );
  }
}
