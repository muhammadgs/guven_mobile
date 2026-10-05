import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/stock_item.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One balance: the product's code and the day it was counted, its name, the
/// warehouse, and how much of it is there — the website's five columns.
///
/// `Satışlar`' card, less everything that opens: a row says all the
/// website's table does, so there is nothing to open it onto. The name takes
/// every line it needs and the card grows with it, one line at the least;
/// nothing else on it ever needs a second.
///
/// The numbers are the design's, on its 402pt frame: a one-line card is
/// 139pt tall and every line of name adds one CalSans line, 18pt. The first
/// line and the pane are `Satışlar`' own ([DatabaseCardHeading],
/// [DatabaseCardSurface]). The design's two one-line cards agree to the
/// pixel, and the four rows' baselines sit 25.5, 54.25, 85 and 117pt down
/// them; set in the real faces on the design's own frame, these paddings land
/// every one within 0.1pt. On other screens the text engine rounds each line
/// to a whole point, which moves a card by a point or so either way — as it
/// does `Satışlar`' — and nothing more.
class StockCard extends StatelessWidget {
  const StockCard({super.key, required this.item});

  final StockItem item;

  /// The design's padding: 23pt either side, 12.2pt above the first line and
  /// 18.3pt under `Miqdar` — `Satışlar`' own, under its last line.
  static const double kPadH = 23;
  static const double kPadTop = 12.2;
  static const double kPadBottom = 18.3;

  /// The room between the rows, top to bottom.
  static const double kHeadingGap = 10.8;
  static const double kNameGap = 13.7;
  static const double kWarehouseGap = 14.9;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final TextStyle body = databaseCardStyle(14 * s);
    final double? quantity = item.quantity;

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          kPadH * s,
          kPadTop * s,
          kPadH * s,
          kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DatabaseCardHeading(number: item.code, date: item.date, scale: s),
            SizedBox(height: kHeadingGap * s),
            // 1C doubles some of the spaces in a name and leaves others
            // trailing; the design, like the website, shows it with one.
            Text(_written(item.product), style: databaseCardNameStyle(s)),
            SizedBox(height: kNameGap * s),
            Text(_written(item.warehouse), style: body),
            SizedBox(height: kWarehouseGap * s),
            Align(
              alignment: Alignment.centerLeft,
              // A figure is never cut: one too long for the card — there is
              // none in the data — is set smaller instead.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Miqdar: '
                  '${quantity == null ? kUnknownValue : formatQuantity(quantity)}',
                  maxLines: 1,
                  softWrap: false,
                  style: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _written(String? text) {
    if (text == null) return kUnknownValue;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? kUnknownValue : tidy;
  }
}
