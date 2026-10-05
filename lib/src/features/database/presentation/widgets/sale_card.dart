import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/sale.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One sale document, shut or open.
///
/// Shut, it is the website's table row: number and date, customer,
/// warehouse, kind, the two flags and the amount. Tapping it opens it into
/// the site's `Satış` window: every name under its own heading, and the
/// product lines in a table at the foot — the task cards' behaviour, and
/// like them it does not swap one arrangement for the other. Everything the
/// shut card shows stays on screen and slides to its new place while the
/// headings and the rows only an open card has grow into the gaps.
///
/// Not glass: a flat tint over a blur that the whole list shares (see
/// [kDatabaseCardFill]).
class SaleCard extends StatefulWidget {
  const SaleCard({
    super.key,
    required this.sale,
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  /// The row, with its document laid over it once that is known.
  final Sale sale;

  /// Whether the card is open. Owned by the list, not the card, so a card
  /// scrolled far enough away to be rebuilt comes back the way it was left.
  final bool expanded;

  final VoidCallback onToggle;

  /// True while the document behind the card is on its way.
  final bool loading;

  /// Why the document could not be read, or null.
  final String? error;

  /// Asks for the document again after [error].
  final VoidCallback onRetry;

  @override
  State<SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends State<SaleCard>
    with SingleTickerProviderStateMixin {
  // The task card's timing, so the two lists open alike.
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
  void didUpdateWidget(covariant SaleCard oldWidget) {
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
          padding: EdgeInsets.fromLTRB(23 * s, 10.2 * s, 23 * s, 18.3 * s),
          child: AnimatedBuilder(
            animation: _open,
            builder: (BuildContext context, _) => _Body(
              sale: widget.sale,
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

/// The card's contents at [t] of the way open.
///
/// One column in both states, so the blend is a matter of gaps: the shut
/// card's rows keep their order, and each heading and open-only row is let
/// in between them at [t] of its height, pushing everything under it down by
/// exactly as much. At 0 and 1 the result is exactly one of the two designs.
class _Body extends StatelessWidget {
  const _Body({
    required this.sale,
    required this.t,
    required this.scale,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Sale sale;
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
    final TextStyle name = databaseCardNameStyle(s);

    Widget heading(String text) =>
        Text(text, maxLines: 1, softWrap: false, style: body);

    // A row that came without its organisation has it fetched when the card
    // opens; until then the line is held open, empty, rather than saying `—`
    // and taking it back.
    final String organization =
        sale.organization ?? (loading ? ' ' : kUnknownValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DatabaseCardHeading(number: sale.number, date: sale.date, scale: s),
        SizedBox(height: lerpDouble(10, 13.9, t)! * s),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              heading('Müştəri:'),
              SizedBox(height: 1.5 * s),
            ],
          ),
        _Growing(text: sale.customer ?? kUnknownValue, style: name, t: t),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              SizedBox(height: 11.8 * s),
              heading('Təşkilat:'),
              SizedBox(height: 1.5 * s),
              _Wrapped(text: organization, style: name),
              SizedBox(height: 11.8 * s),
              heading('Menecer:'),
              SizedBox(height: 1.5 * s),
              _Wrapped(text: sale.manager ?? kUnknownValue, style: name),
            ],
          ),
        SizedBox(height: lerpDouble(13.2, 11.8, t)! * s),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              heading('Anbar:'),
              SizedBox(height: 1.5 * s),
            ],
          ),
        _Growing(text: sale.warehouse ?? kUnknownValue, style: body, t: t),
        SizedBox(height: lerpDouble(10.2, 18.2, t)! * s),
        Text(
          sale.docTypeLabel ?? kUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body,
        ),
        SizedBox(height: lerpDouble(10.2, 14.2, t)! * s),
        _Standing(sale: sale, scale: s),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              SizedBox(height: 29.5 * s),
              SaleLinesTable(
                lines: sale.lines,
                loading: loading,
                error: error,
                onRetry: onRetry,
                scale: s,
              ),
            ],
          ),
      ],
    );
  }
}

/// The two flags, and the amount at the far end.
///
/// The second flag stands in a column of its own: after `Postlanıb` it
/// starts where it starts on every other card, and only a `Postlanmayıb` too
/// long to leave that room pushes it on — the design's two cards measure
/// exactly that.
class _Standing extends StatelessWidget {
  const _Standing({required this.sale, required this.scale});

  final Sale sale;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double? amount = sale.amount;

    Widget flag(bool done, String yes, String no) => Text(
      done ? yes : no,
      maxLines: 1,
      softWrap: false,
      style: databaseCardStyle(14 * s, color: done ? kSaleDone : kSalePending),
    );

    return Row(
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: 78.5 * s),
          child: flag(sale.isPosted, 'Postlanıb', 'Postlanmayıb'),
        ),
        SizedBox(width: 15 * s),
        flag(sale.isSold, 'Satılıb', 'Satılmayıb'),
        SizedBox(width: 10 * s),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            // Seven figures and a currency still fit a 360pt phone; anything
            // longer is set smaller rather than cut, since the cut end of an
            // amount is the end that matters.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount == null
                    ? kUnknownValue
                    : '${formatDecimal(amount)} ${sale.currency ?? 'AZN'}',
                maxLines: 1,
                softWrap: false,
                style: databaseCardStyle(14 * s, weight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A name that is given every line it needs once the card opens.
class _Wrapped extends StatelessWidget {
  const _Wrapped({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// One line on a shut card, every line it needs on an open one.
///
/// Most customers and warehouses fit one line, and then this is just that
/// line. One that is a little too long is set up to a seventh smaller, shut
/// and open alike, rather than cut or broken — Azerbaijani names are long,
/// and `FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)` alone fills the design's
/// card to the point. Only a name that would need more than that loses its
/// end on the shut card, and opens into its full size across as many lines as
/// it needs; the two versions are cross-faded while the card's height slides
/// between theirs, the way the task card's description is.
class _Growing extends StatelessWidget {
  const _Growing({required this.text, required this.style, required this.t});

  final String text;
  final TextStyle style;
  final double t;

  /// How far a shut line may shrink before it ellipsises instead.
  static const double _floor = 0.86;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        final TextDirection direction = Directionality.of(context);

        TextPainter measure(TextStyle style, {int? maxLines, double? within}) =>
            TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: direction,
              textScaler: scaler,
              maxLines: maxLines,
              ellipsis: maxLines == null ? null : '…',
            )..layout(maxWidth: within ?? double.infinity);

        final TextPainter natural = measure(style, maxLines: 1);
        final double needed = natural.width;
        natural.dispose();

        if (needed <= width) {
          // One line shut and open alike: nothing to blend.
          return Text(text, maxLines: 1, softWrap: false, style: style);
        }

        // A hair inside the edge, so rounding does not decide the ellipsis.
        final double fit = width / needed * 0.995;
        final TextStyle shutStyle = style.copyWith(
          fontSize: style.fontSize! * fit.clamp(_floor, 1.0),
        );
        if (fit >= _floor) {
          // Close enough to set smaller, shut and open alike.
          return Text(text, maxLines: 1, softWrap: false, style: shutStyle);
        }
        final Text shutLine = Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: shutStyle,
        );
        if (t <= 0) return shutLine;

        final TextPainter shut = measure(shutStyle, maxLines: 1, within: width);
        final TextPainter open = measure(style, maxLines: 3, within: width);
        final double height = lerpDouble(shut.height, open.height, t)!;
        shut.dispose();
        open.dispose();

        return ClipRect(
          child: SizedBox(
            height: height,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Stack(
                children: <Widget>[
                  Opacity(
                    opacity: t,
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (t < 1) Opacity(opacity: 1 - t, child: shutLine),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The document's products: `Məhsul`, `Miqdar`, `Qiymət`, `Cəmi`.
///
/// The product takes whatever the three figures leave and wraps inside it;
/// the figures sit centred under their headings in three equal columns and
/// are set smaller, never cut, should one outgrow its column. Columns are
/// fractions of the card rather than the width of their contents, so every
/// card's table lines up with every other's.
///
/// Public so the column arithmetic can be pinned by a test.
class SaleLinesTable extends StatelessWidget {
  const SaleLinesTable({
    super.key,
    required this.lines,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.scale,
  });

  final List<SaleLine>? lines;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final double scale;

  /// Each figure column's share of the card's width.
  static const double figureColumn = 0.183;

  static const Map<int, TableColumnWidth> _columns = <int, TableColumnWidth>{
    0: FlexColumnWidth(),
    1: FractionColumnWidth(figureColumn),
    2: FractionColumnWidth(figureColumn),
    3: FractionColumnWidth(figureColumn),
  };

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final Widget rule = SizedBox(
      height: 1 * s,
      child: const ColoredBox(color: kGlassInk),
    );
    final TextStyle heading = databaseCardStyle(
      11 * s,
      weight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        rule,
        SizedBox(height: 3.05 * s),
        Table(
          columnWidths: _columns,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                Text('Məhsul', maxLines: 1, softWrap: false, style: heading),
                _Figure(text: 'Miqdar', style: heading),
                _Figure(text: 'Qiymət', style: heading),
                _Figure(text: 'Cəmi', style: heading),
              ],
            ),
          ],
        ),
        SizedBox(height: 1.75 * s),
        rule,
        SizedBox(height: 7.1 * s),
        // The spinner turns into the table when the document lands; this is
        // what keeps that from being a jump in the card's height.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _rows(context),
        ),
      ],
    );
  }

  Widget _rows(BuildContext context) {
    final double s = scale;
    final List<SaleLine>? lines = this.lines;
    final TextStyle cell = databaseCardStyle(11 * s, height: 1.55);
    final TextStyle note = databaseCardStyle(
      11 * s,
      height: 1.55,
      color: kGlassInkMuted,
    );

    if (lines != null && lines.isNotEmpty) {
      return Table(
        columnWidths: _columns,
        children: <TableRow>[
          for (int i = 0; i < lines.length; i++)
            _row(lines[i], cell, top: i == 0 ? 0 : 3 * s),
        ],
      );
    }

    if (loading) {
      return SizedBox(
        height: 17 * s,
        child: Center(
          child: SizedBox.square(
            dimension: 14 * s,
            child: const CircularProgressIndicator(
              strokeWidth: 1.8,
              color: kGlassInkMuted,
            ),
          ),
        ),
      );
    }

    final String? error = this.error;
    if (error != null) {
      return Row(
        children: <Widget>[
          Expanded(child: Text(error, style: note)),
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

    return Text('Sənəddə məhsul yoxdur.', style: note);
  }

  TableRow _row(SaleLine line, TextStyle style, {required double top}) {
    final double s = scale;
    String figure(double? value, String Function(double) write) =>
        value == null ? kUnknownValue : write(value);

    return TableRow(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: top, right: 6 * s),
          child: Text(line.product ?? kUnknownValue, style: style),
        ),
        _Figure(
          text: figure(line.quantity, formatQuantity),
          style: style,
          top: top,
        ),
        _Figure(
          text: figure(line.price, formatDecimal),
          style: style,
          top: top,
        ),
        _Figure(
          text: figure(line.amount, formatDecimal),
          style: style,
          top: top,
        ),
      ],
    );
  }
}

/// One figure or figure heading, centred in its column and set smaller
/// rather than cut should it be too wide for it.
class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.style, this.top = 0});

  final String text;
  final TextStyle style;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Align(
        alignment: Alignment.topCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        ),
      ),
    );
  }
}
