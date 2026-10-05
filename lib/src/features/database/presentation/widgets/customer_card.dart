import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/customer.dart';
import '../../domain/database_filter.dart' show tidySpaces;
import 'database_card.dart';
import 'database_glass.dart';

/// One customer, shut or open.
///
/// Shut, it is the design's first card: the name, the code — the VÖEN when
/// 1C has one, as the website's `VÖEN / KOD` column shows it — and the kind.
/// Tapping it opens it into the design's second card: the code and the kind
/// take their labels, `Kod/ Vöen:` and `Növ:`, and the role, the legal
/// status — only for a customer 1C gives one — and the payment term grow in
/// under them. Like the other `Baza`
/// cards it does not swap one arrangement for the other: the shut card's
/// rows stay on screen and move to their new places — the code slides right
/// as its label comes in ahead of it — while the rows only an open card has
/// grow into the room made for them.
///
/// Every name is one size, short or long — the user's word (2026-10-04),
/// after a first try that set short names larger: CalSans at 20pt, 26pt a
/// line, off the picture they drew it in. A long name takes every line it
/// needs and the card grows with it, `Stok`'s rule.
///
/// The rest is the design's, measured off its frame at 2px a point:
/// Poppins at 14 and the code ChakraPetch at 14; 24pt from the code to the
/// kind on a shut card; on an open one the pairs 28.75pt apart — the
/// design's average, where its own gaps shrink from 31 to 27 — and the last
/// 30pt above the bottom edge. The name's last baseline is 27.5pt above the
/// code's, between what the design gave a 24pt name and a 16pt one.
class CustomerCard extends StatefulWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  /// The row, with the customer's own answer laid over it once that is
  /// known.
  final Customer customer;

  /// Whether the card is open. Owned by the list, not the card, so a card
  /// scrolled far enough away to be rebuilt comes back the way it was left.
  final bool expanded;

  final VoidCallback onToggle;

  /// True while the customer's own answer is on its way.
  final bool loading;

  /// Why the customer's own answer could not be read, or null.
  final String? error;

  /// Asks for the customer's own answer again after [error].
  final VoidCallback onRetry;

  /// 23pt either side — every `Baza` card's, and the design's first card's
  /// rows — and 10.4pt above the name's line.
  static const double kPadH = 23;
  static const double kPadTop = 10.4;

  /// Under the last row of a shut card.
  static const double kPadBottom = 21.3;

  /// An open card's last row sits this much further from its bottom edge.
  static const double kOpenPadExtra = 4.95;

  /// The name's size and its line: a whole number of points, so the lines
  /// land where they are measured to.
  static const double kName = 20;
  static const double kNameHeight = 26 / kName;

  /// From the name's last line to the code's line.
  static const double kNameGap = 8.15;

  /// Between one row and the next, shut and open.
  static const double kShutRowGap = 6.89;
  static const double kOpenRowGap = 11.75;

  /// From `Kod/ Vöen:` to the code: the design leaves a wide gap there,
  /// where every other label is a space from its value.
  static const double kCodeLabelGap = 16.8;

  /// The name's face on the design's frame.
  static TextStyle nameStyle(double scale) => TextStyle(
    fontFamily: 'CalSans',
    fontSize: kName * scale,
    height: kNameHeight,
    letterSpacing: 0,
    color: kGlassInk,
  );

  @override
  State<CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<CustomerCard>
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
  void didUpdateWidget(covariant CustomerCard oldWidget) {
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
            CustomerCard.kPadH * s,
            CustomerCard.kPadTop * s,
            CustomerCard.kPadH * s,
            CustomerCard.kPadBottom * s,
          ),
          child: AnimatedBuilder(
            animation: _open,
            builder: (BuildContext context, _) => _Body(
              customer: widget.customer,
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
/// so the blend is a matter of gaps and of labels coming in, and at 0 and 1
/// it is exactly one of the two designs.
class _Body extends StatelessWidget {
  const _Body({
    required this.customer,
    required this.t,
    required this.scale,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Customer customer;
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
    final TextStyle body = databaseCardStyle(14 * s);
    final TextStyle figure = TextStyle(
      fontFamily: kDatabaseFigureFont,
      fontSize: 14 * s,
      height: 1.2,
      letterSpacing: 0,
      color: kGlassInk,
    );
    final double rowGap =
        lerpDouble(CustomerCard.kShutRowGap, CustomerCard.kOpenRowGap, t)! * s;
    final String? error = this.error;
    final String? legalStatus = loading ? null : customer.legalStatus;

    // What only the customer's own answer says: `…` while it is on its way,
    // and `—` when it says nothing — or could not be read.
    String detail(String? value) {
      if (loading) return '…';
      return value ?? kUnknownValue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Every line it needs.
        Text(_written(customer.name), style: CustomerCard.nameStyle(s)),
        SizedBox(height: CustomerCard.kNameGap * s),
        _LabelledLine(
          label: 'Kod/ Vöen:',
          gap: CustomerCard.kCodeLabelGap * s,
          value: customer.taxIdOrCode ?? kUnknownValue,
          labelStyle: body,
          valueStyle: figure,
          t: t,
          fade: fade,
        ),
        SizedBox(height: rowGap),
        _LabelledLine(
          // A space, as the design sets every other label from its value;
          // a hard one, so it is measured rather than dropped at the end of
          // the label.
          label: 'Növ:\u00A0',
          gap: 0,
          value: customer.typeLabel ?? kUnknownValue,
          labelStyle: body,
          valueStyle: body,
          t: t,
          fade: fade,
        ),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              SizedBox(height: CustomerCard.kOpenRowGap * s),
              _Pair(
                label: 'Rolu:',
                value: detail(customer.roleLabel),
                pending: loading,
                scale: s,
              ),
              // Only a customer 1C gives a legal status has the row — the
              // website leaves it blank for the rest, and so does the card.
              // It is the customer's own answer that says, so the row grows
              // in when that lands rather than standing there empty.
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: legalStatus == null
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(height: CustomerCard.kOpenRowGap * s),
                          _Pair(
                            label: 'Hüquqi Status:',
                            value: legalStatus,
                            scale: s,
                          ),
                        ],
                      ),
              ),
              SizedBox(height: CustomerCard.kOpenRowGap * s),
              _Pair(
                label: 'Ödəniş müddəti:',
                value: customer.paymentTerm ?? kUnknownValue,
                scale: s,
              ),
              if (error != null && !loading) ...<Widget>[
                SizedBox(height: CustomerCard.kOpenRowGap * s),
                _Failure(message: error, onRetry: onRetry, scale: s),
              ],
            ],
          ),
        SizedBox(height: CustomerCard.kOpenPadExtra * t * s),
      ],
    );
  }

  static String _written(String? text) {
    if (text == null) return kUnknownValue;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? kUnknownValue : tidy;
  }
}

/// A row whose label only an open card shows: `Kod/ Vöen:` ahead of the
/// code, `Növ:` ahead of the kind. The label comes in from nothing as the
/// card opens, pushing the value along its line to where the open design
/// has it; shut, the value stands where the label will start.
class _LabelledLine extends StatelessWidget {
  const _LabelledLine({
    required this.label,
    required this.gap,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    required this.t,
    required this.fade,
  });

  final String label;
  final double gap;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final double t;
  final double fade;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        // Always laid out, even shut, so the line is as tall shut as open
        // and nothing jumps when the card starts to move.
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: Opacity(
              opacity: fade,
              child: Padding(
                padding: EdgeInsets.only(right: gap),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: labelStyle,
                ),
              ),
            ),
          ),
        ),
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            // A code or a kind with its tail missing names a different
            // thing; one too wide for its room is set smaller instead.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: valueStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `Rolu: Alıcı` — a heading and its value on one line, a space apart as
/// the design sets them.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.value,
    required this.scale,
    this.pending = false,
  });

  final String label;
  final String value;
  final double scale;

  /// The value is a stand-in while the customer's own answer is on its way,
  /// and is drawn muted.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = databaseCardStyle(14 * scale);
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label ',
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: pending ? body.copyWith(color: kGlassInkMuted) : null,
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: body,
        ),
      ),
    );
  }
}

/// Why the customer's own answer could not be read, and a way to ask again,
/// under the rows it left saying `—`.
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
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            message,
            style: databaseCardStyle(
              11 * s,
              height: 1.55,
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
    );
  }
}
