import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/product.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One product, shut or open.
///
/// Shut, it is the website's table row as the design draws it: the code,
/// the name, the category — and under it `Artikul:` for a product that has
/// one — and the price over its unit. Tapping it opens it
/// into the site's `Məhsul` window: each of those under its own heading,
/// then the stock, the kind, the VAT rate and the status, and the product's
/// balance in each warehouse in a table at the foot. Like `Satışlar`' card
/// it does not swap one arrangement for the other: the shut card's rows stay
/// on screen and slide to their new places while the headings and the rows
/// only an open card has grow into the gaps.
///
/// The numbers are the design's, measured off its two frames (2.111px a
/// point shut, 1.622 open): shut, the card is 138pt tall with the baselines
/// 25.4, 54.05, 83.8 and 114pt down; open, the headings and their values are
/// 18.9–20.1pt apart and each pair 33.1pt from the next — the design's
/// average, where its own gaps wander between 28.9 and 35.1 — and the
/// table's rows 21.6pt apart. The name takes every line it needs and the
/// card grows with it, `Stok`'s rule.
class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  /// The row, with the product's own answer laid over it once that is
  /// known.
  final Product product;

  /// Whether the card is open. Owned by the list, not the card, so a card
  /// scrolled far enough away to be rebuilt comes back the way it was left.
  final bool expanded;

  final VoidCallback onToggle;

  /// True while the product's own answer is on its way.
  final bool loading;

  /// Why the product's own answer could not be read, or null.
  final String? error;

  /// Asks for the product's own answer again after [error].
  final VoidCallback onRetry;

  /// 23pt either side and 12.2pt above the code — `Stok`'s, which puts the
  /// code on the same 25.4pt baseline.
  static const double kPadH = 23;
  static const double kPadTop = 12.2;

  /// Under the price line of a shut card.
  static const double kPadBottom = 20.33;

  /// Shut: from the code to the name, the name to the category, and the
  /// category to the price.
  static const double kShutNameGap = 10.71;
  static const double kShutCategoryGap = 12.7;
  static const double kShutPriceGap = 13.07;

  /// Open: from the code to `Məhsul adı:`; from a heading to its value; from
  /// one pair to the next.
  static const double kOpenFirstGap = 14.5;
  static const double kHeadingNameGap = 0.95;
  static const double kHeadingValueGap = 3.1;
  static const double kOpenNameGap = 16.05;
  static const double kOpenPairGap = 16.1;

  /// From `Status` to the table's first rule.
  static const double kTableGap = 16.4;

  /// An open card's last row sits this much further from its bottom edge
  /// than a shut card's price does.
  static const double kOpenPadExtra = 0.345;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
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
  void didUpdateWidget(covariant ProductCard oldWidget) {
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
            ProductCard.kPadH * s,
            ProductCard.kPadTop * s,
            ProductCard.kPadH * s,
            ProductCard.kPadBottom * s,
          ),
          child: AnimatedBuilder(
            animation: _open,
            builder: (BuildContext context, _) => _Body(
              product: widget.product,
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
    required this.product,
    required this.t,
    required this.scale,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Product product;
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
    final String? article = _article(product);

    Widget heading(String text) => _Line(text: text, style: body);
    Widget gap(double shut, double open) =>
        SizedBox(height: lerpDouble(shut, open, t)! * s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DatabaseCardHeading(number: product.code, date: null, scale: s),
        gap(ProductCard.kShutNameGap, ProductCard.kOpenFirstGap),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              heading('Məhsul adı:'),
              SizedBox(height: ProductCard.kHeadingNameGap * s),
            ],
          ),
        // 1C doubles some of the spaces in a name and leaves others
        // trailing; the design, like the website, shows it with one. Every
        // line it needs, shut and open alike.
        Text(_written(product.name), style: databaseCardNameStyle(s)),
        gap(ProductCard.kShutCategoryGap, ProductCard.kOpenNameGap),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              heading('Kateqoriya:'),
              SizedBox(height: ProductCard.kHeadingValueGap * s),
            ],
          ),
        _Line(text: _written(product.category), style: body),
        // Only some products have an article number; theirs goes under the
        // category in the category's own face, shut and open alike, a line
        // apart as the price is.
        if (article != null) ...<Widget>[
          gap(ProductCard.kShutPriceGap, ProductCard.kOpenPairGap),
          _Pair(label: 'Artikul:', value: article, scale: s),
        ],
        gap(ProductCard.kShutPriceGap, ProductCard.kOpenPairGap),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              heading('Qiymət / Vahid:'),
              SizedBox(height: ProductCard.kHeadingValueGap * s),
            ],
          ),
        _Line(text: _priceLine(product), style: body),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              SizedBox(height: ProductCard.kOpenPairGap * s),
              _Pair(
                label: 'Stokda:',
                value: product.stock == null
                    ? kUnknownValue
                    : formatQuantity(product.stock!),
                scale: s,
              ),
              SizedBox(height: ProductCard.kOpenPairGap * s),
              _Pair(
                label: 'Növ:',
                value: product.type ?? kUnknownValue,
                scale: s,
              ),
              SizedBox(height: ProductCard.kOpenPairGap * s),
              _Pair(label: 'ƏDV:', value: _vat(product), scale: s),
              SizedBox(height: ProductCard.kOpenPairGap * s),
              _Pair(
                label: 'Status:',
                value: product.isActive ? 'aktiv' : 'deaktiv',
                valueColor: product.isActive ? kSaleDone : kSalePending,
                scale: s,
              ),
              SizedBox(height: ProductCard.kTableGap * s),
              ProductBalancesTable(
                balances: product.balances,
                loading: loading,
                error: error,
                onRetry: onRetry,
                scale: s,
              ),
            ],
          ),
        SizedBox(height: ProductCard.kOpenPadExtra * t * s),
      ],
    );
  }

  static String _written(String? text) {
    if (text == null) return kUnknownValue;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? kUnknownValue : tidy;
  }

  /// The article number with its spaces made single, or null for a product
  /// that has none.
  static String? _article(Product product) {
    final String? article = product.article;
    if (article == null) return null;
    final String tidy = tidySpaces(article);
    return tidy.isEmpty ? null : tidy;
  }

  /// `15.60 ₼ / əd` — the price over the unit it is asked for, as the
  /// design writes them. The unit is 1C's own short name.
  static String _priceLine(Product product) {
    final double? price = product.price;
    final String money = price == null ? kUnknownValue : formatMoney(price);
    final String? unit = product.unit;
    return unit == null ? money : '$money / ${tidySpaces(unit)}';
  }

  /// `18%`, or `yoxdur` — the filter's own word for a product with no VAT
  /// (the website's `ƏDV-siz`).
  static String _vat(Product product) {
    if (product.hasNoVat) return 'yoxdur';
    return '${formatQuantity(product.vat!)}%';
  }
}

/// One line that never breaks and is never cut: one too wide for its room
/// is set smaller instead.
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

/// `Stokda:  26` — a heading and its value on one line, two spaces apart as
/// the design sets them.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.value,
    required this.scale,
    this.valueColor = kGlassInk,
  });

  final String label;
  final String value;
  final double scale;
  final Color valueColor;

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
            text: '$label  ',
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: body.copyWith(color: valueColor),
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

/// The product's balance in each warehouse: `Anbar`, `Miqdar`, and `Cəmi`
/// under them — the website's table, most first.
///
/// The warehouse takes whatever the figure leaves and wraps inside it; the
/// figure sits centred under `Miqdar`, whose column is as wide as the wider
/// of the two — the design puts `Miqdar` right at the content's edge.
///
/// `Cəmi` adds up the rows, as the website's does. That is not always the
/// card's `Stokda`: the bridge keeps a warehouse's older count in the list
/// after a newer sync has left it out of the stock figure.
///
/// Public so its rows can be pinned by a test.
class ProductBalancesTable extends StatelessWidget {
  const ProductBalancesTable({
    super.key,
    required this.balances,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.scale,
  });

  final List<ProductBalance>? balances;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final double scale;

  /// The design's table: from the rule to the heading's line, from there to
  /// the second rule, and on to the first row; then 21.6pt a row.
  static const double kHeadingTop = 3.75;
  static const double kHeadingBottom = 3.85;
  static const double kRowsTop = 7.83;
  static const double kRowGap = 4.6;

  /// Either side of a figure in its column.
  static const double kFigurePad = 2;

  TextStyle get _heading =>
      databaseCardStyle(11 * scale, weight: FontWeight.w600);
  TextStyle get _cell => databaseCardStyle(11 * scale, height: 1.55);
  TextStyle get _total =>
      databaseCardStyle(11 * scale, height: 1.55, weight: FontWeight.w600);

  /// The rows, most first as the website sorts them — a count 1C left out,
  /// last — and `Cəmi` under them; null until there are any.
  List<(String, String, bool)>? get _lines {
    final List<ProductBalance>? balances = this.balances;
    if (balances == null || balances.isEmpty) return null;
    final List<ProductBalance> sorted = List<ProductBalance>.of(balances)
      ..sort(
        (ProductBalance a, ProductBalance b) =>
            (b.quantity ?? double.negativeInfinity).compareTo(
              a.quantity ?? double.negativeInfinity,
            ),
      );
    double sum = 0;
    for (final ProductBalance balance in sorted) {
      sum += balance.quantity ?? 0;
    }
    return <(String, String, bool)>[
      for (final ProductBalance balance in sorted)
        (
          balance.warehouse == null
              ? kUnknownValue
              : tidySpaces(balance.warehouse!),
          balance.quantity == null
              ? kUnknownValue
              : formatQuantity(balance.quantity!),
          false,
        ),
      ('Cəmi', formatQuantity(sum), true),
    ];
  }

  /// The heading and the rows are two tables — the rows grow in on their
  /// own — so the figures' column is measured once for both: as wide as
  /// `Miqdar` or the widest figure, whichever is wider.
  Map<int, TableColumnWidth> _columns(
    BuildContext context,
    List<(String, String, bool)>? lines,
  ) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    double widest = 0;
    void measure(String text, TextStyle style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }

    measure('Miqdar', _heading);
    for (final (String _, String figure, bool total)
        in lines ?? const <(String, String, bool)>[]) {
      measure(figure, total ? _total : _cell);
    }
    return <int, TableColumnWidth>{
      0: const FlexColumnWidth(),
      // A hair over the widest, so rounding never wraps a figure.
      1: FixedColumnWidth(widest.ceilToDouble() + 2 * kFigurePad * scale),
    };
  }

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final Widget rule = SizedBox(
      height: 1 * s,
      child: const ColoredBox(color: kGlassInk),
    );
    final TextStyle heading = _heading;
    final List<(String, String, bool)>? lines = _lines;
    final Map<int, TableColumnWidth> columns = _columns(context, lines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        rule,
        SizedBox(height: kHeadingTop * s),
        Table(
          columnWidths: columns,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                Text('Anbar', maxLines: 1, softWrap: false, style: heading),
                _Figure(text: 'Miqdar', style: heading, scale: s),
              ],
            ),
          ],
        ),
        SizedBox(height: kHeadingBottom * s),
        rule,
        SizedBox(height: kRowsTop * s),
        // The spinner turns into the table when the product lands; this is
        // what keeps that from being a jump in the card's height.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _rows(lines, columns),
        ),
      ],
    );
  }

  Widget _rows(
    List<(String, String, bool)>? lines,
    Map<int, TableColumnWidth> columns,
  ) {
    final double s = scale;
    final TextStyle note = databaseCardStyle(
      11 * s,
      height: 1.55,
      color: kGlassInkMuted,
    );

    if (lines != null) {
      return Table(
        columnWidths: columns,
        children: <TableRow>[
          for (int i = 0; i < lines.length; i++)
            _row(
              lines[i].$1,
              lines[i].$2,
              lines[i].$3 ? _total : _cell,
              top: i == 0 ? 0 : kRowGap * s,
            ),
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

    return Text('Anbarlarda qalıq yoxdur.', style: note);
  }

  TableRow _row(
    String warehouse,
    String quantity,
    TextStyle style, {
    required double top,
  }) {
    final double s = scale;
    return TableRow(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: top, right: 8 * s),
          child: Text(warehouse, style: style),
        ),
        _Figure(text: quantity, style: style, scale: s, top: top),
      ],
    );
  }
}

/// One figure or `Miqdar`, centred in its column.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.text,
    required this.style,
    required this.scale,
    this.top = 0,
  });

  final String text;
  final TextStyle style;
  final double scale;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: top,
        left: ProductBalancesTable.kFigurePad * scale,
        right: ProductBalancesTable.kFigurePad * scale,
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}
