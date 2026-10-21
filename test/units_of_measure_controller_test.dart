import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/units_of_measure_controller.dart';
import 'package:guven_mobile/src/features/database/application/units_of_measure_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/unit_of_measure.dart';
import 'package:guven_mobile/src/features/database/domain/units_of_measure_filter.dart';

/// `Ölçü Vahidləri` reads a unit the way the website does — the guid set
/// aside, a blank international code as none — and its filter finds what it
/// is asked for in the whole catalogue: a code or a name through the bridge,
/// an international code on the phone.
void main() {
  group('reading a unit', () {
    test('the live row\'s fields', () {
      // Unit 498 as the bridge answered on 2026-10-10.
      final UnitOfMeasure unit = UnitOfMeasure.fromJson(<String, Object?>{
        'id': 498,
        'onec_guid': 'eec1f6cf-4fcd-11ef-ab76-98b4f1c6b4f2',
        'code': '110',
        'name': 'Bağlama',
        'international_code': 'Bağ',
        'created_at': '2026-10-10T07:37:03.576224',
        'updated_at': '2026-10-10T07:37:03.576224',
        'baza_id': 18,
      })!;

      expect(unit.id, 498);
      expect(unit.code, '110');
      expect(unit.name, 'Bağlama');
      expect(unit.internationalCode, 'Bağ');
    });

    test('a blank international code is none, and no id is no unit', () {
      final UnitOfMeasure unit = UnitOfMeasure.fromJson(<String, Object?>{
        'id': 507,
        'code': '123',
        'name': 'DƏFƏ',
        'international_code': '',
      })!;
      expect(unit.internationalCode, isNull);
      expect(UnitOfMeasure.fromJson(<String, Object?>{'code': '1'}), isNull);
    });
  });

  group('the filter\'s rules', () {
    const UnitOfMeasure bundle = UnitOfMeasure(
      id: 498,
      code: '110',
      name: 'Bağlama',
      internationalCode: 'Bağ',
    );
    const UnitOfMeasure times = UnitOfMeasure(
      id: 507,
      code: '123',
      name: 'DƏFƏ  ',
    );

    UnitsOfMeasureFilter only(UnitsOfMeasureColumn column, String value) =>
        UnitsOfMeasureFilter.none.toggle(column, value);

    test('a value in every column', () {
      expect(only(UnitsOfMeasureColumn.code, '110').matches(bundle), isTrue);
      expect(only(UnitsOfMeasureColumn.code, '110').matches(times), isFalse);
      // A name is matched with its spacing set aside.
      expect(only(UnitsOfMeasureColumn.name, 'DƏFƏ').matches(times), isTrue);
      expect(
        only(UnitsOfMeasureColumn.internationalCode, 'Bağ').matches(bundle),
        isTrue,
      );
      // A unit with no international code matches none.
      expect(
        only(UnitsOfMeasureColumn.internationalCode, 'Bağ').matches(times),
        isFalse,
      );
    });

    test('the code goes to the bridge first, then the name; the '
        'international code never does', () {
      final UnitsOfMeasureFilter filter = UnitsOfMeasureFilter.none.toggle(
        UnitsOfMeasureColumn.internationalCode,
        'KGM',
      );
      expect(filter.searchColumn, isNull);
      expect(
        filter.toggle(UnitsOfMeasureColumn.name, 'kq').searchColumn,
        UnitsOfMeasureColumn.name,
      );
      expect(
        filter
            .toggle(UnitsOfMeasureColumn.name, 'kq')
            .toggle(UnitsOfMeasureColumn.code, '166')
            .searchColumn,
        UnitsOfMeasureColumn.code,
      );
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(
        filter.toggle(UnitsOfMeasureColumn.internationalCode, 'KGM'),
        UnitsOfMeasureFilter.none,
      );
      expect(
        filter.cleared(UnitsOfMeasureColumn.internationalCode),
        UnitsOfMeasureFilter.none,
      );
    });
  });

  group('the controller', () {
    test('twenty at a time, and an international code is looked for in the '
        'whole catalogue', () async {
      final _Bridge bridge = _Bridge();
      final UnitsOfMeasureController units = bridge.controller();
      await units.ensureLoaded();
      expect(units.units, hasLength(20));
      // The bridge's order: by name, byte by byte.
      expect(units.units.first.name, 'Ay');
      bridge.requests.clear();

      // `KGM` is `kletka`'s and `kq`'s, both past the first page.
      await units.toggleFilter(UnitsOfMeasureColumn.internationalCode, 'KGM');
      final UnitsOfMeasureFilterView view = units.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((UnitOfMeasure u) => u.id), <int>[502, 511]);
      expect(view.scans, isTrue);
      expect(view.readOf, 32);
      // Every unit read was the list's own.
      expect(units.units, hasLength(32));
      expect(bridge.searches, isEmpty);
    });

    test(
      'a name goes to the bridge, and finds every unit of that name',
      () async {
        final _Bridge bridge = _Bridge();
        final UnitsOfMeasureController units = bridge.controller();
        await units.ensureLoaded();

        await units.toggleFilter(UnitsOfMeasureColumn.name, 'Nəfər');
        final UnitsOfMeasureFilterView view = units.filtered!;
        expect(bridge.searches, <String>['Nəfər']);
        // 1C has `Nəfər` twice, under 107 and 888.
        expect(view.rows.map((UnitOfMeasure u) => u.code), <String>[
          '107',
          '888',
        ]);
        expect(view.scans, isFalse);

        // A code is sent too — and checked exactly: `11` would find four.
        await units.setFilter(
          UnitsOfMeasureFilter.none.toggle(UnitsOfMeasureColumn.code, '110'),
        );
        expect(bridge.searches.last, '110');
        expect(units.filtered!.rows.map((UnitOfMeasure u) => u.name), <String>[
          'Bağlama',
        ]);

        // Let go, the list is the list again.
        await units.clearFilter();
        expect(units.filtered, isNull);
        expect(units.units, hasLength(20));
      },
    );

    test('Beynəlxalq kod opens onto the whole catalogue, read once', () async {
      final _Bridge bridge = _Bridge();
      final UnitsOfMeasureController units = bridge.controller();
      await units.ensureLoaded();
      final UnitsOfMeasureFilterValues values = units.values;

      values.open(UnitsOfMeasureColumn.internationalCode);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 32 vahid oxundu');
      while (units.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(units.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      // The most common first, then as met; the nine blanks are no value.
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Ay',
        'm2',
        'KGM',
        'PCE',
        'Bağ',
        'GN',
        'Kis',
        'Kom',
        'LTR',
        'N',
        'PK',
        'PM',
        'Qt',
        'Rey',
        'X',
        'dst',
        'GC',
        'm3',
        'MTR',
        '129',
      ]);
      final int asked = bridge.requests.length;
      expect(asked, 2);

      // The other columns list theirs at once now, asking nothing: the two
      // `Nəfər` are one name.
      values.open(UnitsOfMeasureColumn.name);
      expect(values.values, hasLength(31));
      values.open(UnitsOfMeasureColumn.code);
      expect(values.values, hasLength(32));
      expect(values.values.first, const FilterValue('104', '104'));
      expect(bridge.requests, hasLength(asked));
    });

    test('typing a name asks the bridge once typing pauses', () async {
      final _Bridge bridge = _Bridge();
      final UnitsOfMeasureController units = bridge.controller();
      await units.ensureLoaded();
      final UnitsOfMeasureFilterValues values = units.values;

      values.open(UnitsOfMeasureColumn.name);
      values.search('kub');
      expect(values.isSearching, isTrue);
      // On the phone already: none of the first twenty.
      expect(values.values, isEmpty);
      await Future<void>.delayed(
        kUnitsOfMeasureValueSearchDelay + const Duration(milliseconds: 50),
      );
      expect(bridge.searches, <String>['kub']);
      expect(values.isSearching, isFalse);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'kub',
        'kubmetr',
      ]);
    });
  });
}

/// The live catalogue, as the bridge answered on 2026-10-10: 32 units by
/// name, byte by byte — `[id, code, name, international code]`.
const List<(int, String, String, String)> kLiveUnits =
    <(int, String, String, String)>[
      (491, '104', 'Ay', 'Ay'),
      (498, '110', 'Bağlama', 'Bağ'),
      (483, '113', 'Boy', 'm2'),
      (507, '123', 'DƏFƏ', ''),
      (490, '103', 'Gün', 'GN'),
      (492, '105', 'Kisə', 'Kis'),
      (503, '222', 'Komple', 'Kom'),
      (510, '112', 'L', 'LTR'),
      (493, '107', 'Nəfər', ''),
      (500, '888', 'Nəfər', 'N'),
      (486, '341', 'PK', 'PK'),
      (489, '102', 'PM', 'PM'),
      (487, '231', 'Qutu', 'Qt'),
      (496, '345', 'RL', ''),
      (495, '109', 'Reys', 'Rey'),
      (494, '108', 'TOP', 'Ay'),
      (481, '444', 'Ton', ''),
      (505, '333', 'Xidmət', 'X'),
      (485, '223', 'cüt', ''),
      (484, '121', 'dəst', 'dst'),
      (501, '412', 'gecə', 'GC'),
      (502, '207', 'kletka', 'KGM'),
      (499, '555', 'km', ''),
      (511, '166', 'kq', 'KGM'),
      (488, '342', 'kub', 'm3'),
      (506, '111', 'kubmetr', ''),
      (509, '106', 'm', 'MTR'),
      (482, '101', 'm2', 'm2'),
      (504, '794', 'paqonmetr', 'PCE'),
      (508, '129', 'pors', '129'),
      (497, '212', 'Çəllək', 'Ay'),
      (512, '796', 'əd', 'PCE'),
    ];

class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  UnitsOfMeasureController controller() {
    final UnitsOfMeasureController units = UnitsOfMeasureController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(units.dispose);
    return units;
  }

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final (int id, String code, String name, String international)
          in kLiveUnits)
        // The bridge's `search`: the code or the name, case set aside.
        if (search == null ||
            code.contains(search) ||
            name.toLowerCase().contains(search.toLowerCase()))
          <String, Object?>{
            'id': id,
            'onec_guid': 'guid-$id',
            'code': code,
            'name': name,
            'international_code': international,
            'baza_id': 18,
          },
    ];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'total': found.length,
      'page': page,
      'page_size': size,
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
