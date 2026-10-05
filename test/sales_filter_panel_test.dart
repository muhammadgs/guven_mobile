import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/database/application/database_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/sales_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/sale_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// The `Satışlar` filter as the user meets it: a funnel beside the menu
/// button, the columns growing out of it, a column's values in the same
/// pane, and the list behind narrowing as values are chosen — on every phone,
/// with and without the keyboard up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What a value's row measures depends on its words, so the measuring is
  // done in the real faces.
  setUpAll(() async {
    Future<void> family(String name, List<String> files) async {
      final FontLoader loader = FontLoader(name);
      for (final String file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }

    await family('Poppins', <String>[
      'Poppins-Regular.ttf',
      'Poppins-Italic.ttf',
      'Poppins-Medium.ttf',
      'Poppins-SemiBold.ttf',
      'Poppins-Bold.ttf',
    ]);
    await family('CalSans', <String>['CalSans-Regular.ttf']);
    await family('ChakraPetch', <String>['ChakraPetch-Regular.ttf']);
  });

  testWidgets('the funnel is Satışlar\' alone, and opens the columns', (
    WidgetTester tester,
  ) async {
    final DatabaseController database = await _pump(
      tester,
      section: DatabaseSection.overview,
    );
    expect(find.bySemanticsLabel(RegExp('^Filtr')), findsNothing);

    database.select(DatabaseSection.sales);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Filtr')), findsOneWidget);

    await _openFilter(tester);
    expect(find.text('Filter'), findsOneWidget);
    for (final SalesColumn column in SalesColumn.values) {
      expect(find.text(column.label), findsOneWidget, reason: column.label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a column opens its values in the same pane, and back comes '
      'back', (WidgetTester tester) async {
    await _pump(tester);
    await _openFilter(tester);
    final Rect columns = _glass(tester);

    await tester.tap(find.text('Müştəri'));
    await tester.pumpAndSettle();
    expect(find.text('Hamısı'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(_inPanel(_Bridge.bar), findsOneWidget);
    expect(find.text('Sənəd'), findsNothing);

    // One pane: wider, from the same corner.
    final Rect values = _glass(tester);
    expect(values.topLeft, columns.topLeft);
    expect(values.width, greaterThan(columns.width * 1.5));

    await tester.tap(find.bySemanticsLabel('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Sənəd'), findsOneWidget);
    expect(find.text('Hamısı'), findsNothing);
    expect(_glass(tester), columns);
  });

  testWidgets('a value narrows the list behind, and the funnel counts it', (
    WidgetTester tester,
  ) async {
    final DatabaseController database = await _pump(tester);
    await _openFilter(tester);
    await tester.tap(find.text('Müştəri'));
    await tester.pumpAndSettle();

    await tester.tap(_inPanel(_Bridge.bar));
    await tester.pumpAndSettle();
    expect(database.sales.filter.valuesOf(SalesColumn.customer), <String>[
      _Bridge.bar,
    ]);

    // Off the glass closes it.
    await tester.tapAt(const Offset(390, 700));
    await tester.pumpAndSettle();
    expect(find.byType(DatabaseFilterPanel), findsNothing);

    final Iterable<SaleCard> cards = tester.widgetList<SaleCard>(
      find.byType(SaleCard),
    );
    expect(cards, isNotEmpty);
    expect(cards.every((SaleCard c) => c.sale.customer == _Bridge.bar), isTrue);
    expect(
      find.descendant(
        of: find.byType(GlassToolButton),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // `Hamısı` lets it go: the list is the list again.
    await _openFilter(tester);
    await tester.tap(find.text('Müştəri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hamısı'));
    await tester.tapAt(const Offset(390, 700));
    await tester.pumpAndSettle();
    expect(database.sales.filtered, isNull);
    expect(
      tester
          .widgetList<SaleCard>(find.byType(SaleCard))
          .map((SaleCard c) => c.sale.customer)
          .toSet(),
      hasLength(greaterThan(1)),
    );
  });

  testWidgets('a long name wraps rather than being cut', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await _openFilter(tester);
    await tester.tap(find.text('Müştəri'));
    await tester.pumpAndSettle();

    final Finder long = _inPanel(_Bridge.long);
    final Finder short = _inPanel(_Bridge.bar);
    expect(long, findsOneWidget);
    final double one = tester.getSize(short).height;
    expect(tester.getSize(long).height, greaterThan(one * 1.8));
    final RenderParagraph paragraph = tester.renderObject(long);
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  // ── Every phone ─────────────────────────────────────────────────────────

  const List<_Device> devices = <_Device>[
    _Device(
      'iPhone 16 Pro',
      Size(402, 874),
      EdgeInsets.only(top: 62, bottom: 34),
    ),
    _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    ),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    ),
    _Device(
      'S23 3-button',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 48),
    ),
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  for (final _Device device in devices) {
    for (final double fontScale in <double>[1.0, 1.2]) {
      testWidgets(
        '${device.name} @ ${fontScale}x — both pages fit, keyboard or not',
        (WidgetTester tester) async {
          final DatabaseController database = await _pump(
            tester,
            device: device,
            fontScale: fontScale,
          );
          // A column already narrowing the list, so `Sıfırla` is in the
          // title's line too.
          await database.sales.toggleFilter(SalesColumn.customer, _Bridge.bar);
          await tester.pumpAndSettle();
          await _openFilter(tester);
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;
          final double margin = DatabaseFilterMetrics.kMargin * s;

          Rect band({double keyboard = 0}) => Rect.fromLTRB(
            margin - 0.01,
            device.insets.top + margin - 0.01,
            device.size.width - margin + 0.01,
            device.size.height -
                (keyboard > device.insets.bottom
                    ? keyboard
                    : device.insets.bottom) -
                margin +
                0.01,
          );
          void inside(Rect rect, Rect band, String what) {
            const double e = 0.01;
            expect(
              rect.left >= band.left - e &&
                  rect.top >= band.top - e &&
                  rect.right <= band.right + e &&
                  rect.bottom <= band.bottom + e,
              isTrue,
              reason: '$what $rect is not inside $band',
            );
          }

          // The columns: every one of them on the glass, none scrolled away.
          final Rect columns = _glass(tester);
          inside(columns, band(), 'the columns');
          for (final SalesColumn column in SalesColumn.values) {
            final Rect row = tester.getRect(find.text(column.label));
            inside(row, columns, column.label);
          }

          // `Sıfırla` beside the title, never over it.
          final Rect title = _drawn(tester, find.text('Filter'));
          final Rect reset = tester.getRect(
            find
                .ancestor(
                  of: find.text('Sıfırla'),
                  matching: find.byType(Container),
                )
                .first,
          );
          inside(reset, columns, 'Sıfırla');
          expect(
            reset.left,
            greaterThanOrEqualTo(title.right),
            reason: 'Sıfırla $reset runs into the title $title',
          );

          // The values: five and a half rows at most, then a scroll.
          await tester.tap(find.text('Müştəri'));
          await tester.pumpAndSettle();
          final Rect values = _glass(tester);
          inside(values, band(), 'the values');
          final Rect list = tester.getRect(
            find.descendant(
              of: find.byType(DatabaseFilterPanel),
              matching: find.byType(ListView),
            ),
          );
          final double row = tester
              .getRect(
                find
                    .ancestor(
                      of: find.text('Hamısı'),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .height;
          expect(list.height, lessThanOrEqualTo(row * 5.5 + 0.5));
          inside(list, values, 'the list');

          // The keyboard: the panel climbs or shrinks, never under it.
          final double keyboard = device.size.height * 0.4;
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
          await tester.pumpAndSettle();
          final Rect typing = _glass(tester);
          inside(typing, band(keyboard: keyboard), 'the values over the keys');
          expect(
            find.descendant(
              of: find.byType(DatabaseFilterPanel),
              matching: find.byType(TextField),
            ),
            findsOneWidget,
          );
          final Rect field = tester.getRect(find.byType(TextField));
          inside(field, typing, 'the search field');

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// [text] on the filter's glass, not on a card behind it.
Finder _inPanel(String text) => find.descendant(
  of: find.byType(DatabaseFilterPanel),
  matching: find.text(text),
);

/// Where [finder]'s text actually lands: a text inside a `FittedBox` keeps
/// its unscaled size, and only the transform says how small it was drawn.
Rect _drawn(WidgetTester tester, Finder finder) {
  final RenderBox box = tester.renderObject(finder);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// The glass the filter is drawn on.
Rect _glass(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(DatabaseFilterPanel),
    matching: find.byType(AppGlassSurface),
  ),
);

Future<void> _openFilter(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Filtr')));
  await tester.pumpAndSettle();
  expect(find.byType(DatabaseFilterPanel), findsOneWidget);
}

class _Device {
  const _Device(this.name, this.size, this.insets);

  final String name;
  final Size size;
  final EdgeInsets insets;
}

Future<DatabaseController> _pump(
  WidgetTester tester, {
  DatabaseSection section = DatabaseSection.sales,
  _Device device = const _Device(
    'iPhone 16 Pro',
    Size(402, 874),
    EdgeInsets.only(top: 62, bottom: 34),
  ),
  double fontScale = 1.0,
}) async {
  const double ratio = 3;
  tester.view.physicalSize = device.size * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.view.padding = FakeViewPadding(
    top: device.insets.top * ratio,
    bottom: device.insets.bottom * ratio,
  );
  tester.platformDispatcher.textScaleFactorTestValue = fontScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final SessionController session = SessionController();
  addTearDown(session.dispose);
  final DatabaseController controller = DatabaseController(
    session,
    api: DatabaseApi(
      ApiClient(tokens: TokenStore(), httpClient: MockClient(_Bridge().answer)),
    ),
  )..select(section);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        type: MaterialType.transparency,
        child: DatabaseScreen(
          bottomReserve: 110,
          active: true,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Sixty documents, newest first, among four customers — one of them with a
/// name long enough to need two lines.
class _Bridge {
  static const String bar = '150 BAR JAZZ CLUB';
  static const String long =
      'FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP) VƏ TƏCHİZAT MƏRKƏZİ';
  static const List<String> customers = <String>[
    'COFFEMANİA',
    bar,
    long,
    'JUNO MMC',
  ];

  static const int _total = 60;

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    if (!path.endsWith('/onec-data/sales/')) {
      // `Əsas panel`'s figures and the catalogues: nothing to add.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 0});
    }

    final String? search = query['search'];
    final List<int> found = <int>[
      for (int i = 0; i < _total; i++)
        if (search == null ||
            filterSearchKey(
              customers[i % customers.length],
            ).contains(filterSearchKey(search)))
          i,
    ];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++)
          <String, Object?>{
            'id': found[k] + 1,
            'order_number': 'NT${(found[k] + 1).toString().padLeft(9, '0')}',
            'order_date': '2026-09-18',
            'customer': customers[found[k] % customers.length],
            'manager': 'S_Vurğun_S1',
            'organization': 'NaTural-İD',
            'warehouse': '',
            'doc_type': 'invoice',
            'total_amount': 58.2,
            'currency': 'AZN',
            'is_posted': true,
            'is_sold': false,
            'lines': <Object?>[
              <String, Object?>{
                'product_name': 'Tushonka',
                'quantity': 1,
                'price': 58.2,
                'amount': 58.2,
              },
            ],
          },
      ],
      'total': found.length,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
