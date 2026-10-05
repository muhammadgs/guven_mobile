import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/team_controller.dart';
import 'package:guven_mobile/src/features/database/application/team_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/team_filter.dart';
import 'package:guven_mobile/src/features/database/domain/team_member.dart';

/// `Komanda` reads a blank in 1C as nothing at all — and its filter finds
/// what it is asked for in the whole register: a code, a name, a position or
/// a department through the bridge, a salary or a status on the phone.
void main() {
  group('reading a person', () {
    test('the live row\'s fields', () {
      // Person 40 as the bridge answered on 2026-10-05.
      final TeamMember member = TeamMember.fromJson(<String, Object?>{
        'id': 40,
        'onec_guid': 'de985727-925e-11f1-ac06-bc24113ee005',
        'code': '0000000051',
        'full_name': 'Məhərrəmova Pərvanə Ələstun qızı',
        'position': 'Paketçi',
        'department': 'ƏSAS şöbə',
        'phone': null,
        'email': null,
        'hire_date': '2026-06-30T00:00:00',
        'salary': 687.0,
        'is_active': true,
        'baza_id': 18,
      })!;

      expect(member.id, 40);
      expect(member.code, '0000000051');
      expect(member.name, 'Məhərrəmova Pərvanə Ələstun qızı');
      expect(member.position, 'Paketçi');
      expect(member.department, 'ƏSAS şöbə');
      expect(member.salary, 687);
      expect(member.active, isTrue);
    });

    test('a blank position or department, and a salary of 0, are nothing', () {
      // Person 2, as most of the register is.
      final TeamMember member = TeamMember.fromJson(<String, Object?>{
        'id': 2,
        'code': 'д000000014',
        'full_name': 'Abdullayev Rəşad Asif oğlu',
        'position': '',
        'department': '  ',
        'salary': 0.0,
        'is_active': true,
      })!;
      expect(member.position, isNull);
      expect(member.department, isNull);
      expect(member.salary, isNull);
      expect(member.active, isTrue);

      // And with no id, no person.
      expect(TeamMember.fromJson(<String, Object?>{'code': '1'}), isNull);
    });
  });

  group('the filter\'s rules', () {
    const TeamMember packer = TeamMember(
      id: 1,
      code: '0000000051',
      name: 'Məhərrəmova  Pərvanə',
      position: 'Paketçi',
      department: 'ƏSAS şöbə',
      salary: 687,
      active: true,
    );
    const TeamMember unpaid = TeamMember(
      id: 2,
      code: 'д000000014',
      name: 'Abdullayev Rəşad',
      department: 'Ağ Şəhər',
      active: false,
    );

    TeamFilter only(TeamColumn column, String value) =>
        TeamFilter.none.toggle(column, value);

    test('a value in every column', () {
      expect(only(TeamColumn.position, 'Paketçi').matches(packer), isTrue);
      expect(only(TeamColumn.position, 'Paketçi').matches(unpaid), isFalse);
      expect(only(TeamColumn.department, 'ağ şəhər').matches(unpaid), isTrue);
      expect(only(TeamColumn.code, '0000000051').matches(packer), isTrue);
      // A name is matched with its spacing set aside.
      expect(
        only(TeamColumn.name, 'Məhərrəmova Pərvanə').matches(packer),
        isTrue,
      );
      expect(only(TeamColumn.status, 'active').matches(packer), isTrue);
      expect(only(TeamColumn.status, 'inactive').matches(unpaid), isTrue);
      expect(only(TeamColumn.status, 'active').matches(unpaid), isFalse);
    });

    test('a salary span holds the salaries in it, and nobody without one', () {
      TeamFilter span(double? min, double? max) => TeamFilter.none.withRange(
        TeamColumn.salary,
        FilterRange(min: min, max: max),
      );
      expect(span(600, 700).matches(packer), isTrue);
      expect(span(700, null).matches(packer), isFalse);
      // Up to 700 is not "everybody whose pay nobody wrote down".
      expect(span(null, 700).matches(unpaid), isFalse);
      expect(span(0, null).matches(unpaid), isFalse);
      expect(span(600, 700).columnCount, 1);
      expect(
        span(600, 700).withRange(TeamColumn.salary, FilterRange.any),
        (TeamFilter.none),
      );
    });

    test('the code goes to the bridge first, then the name, the position '
        'and the department', () {
      final TeamFilter filter = TeamFilter.none
          .toggle(TeamColumn.department, 'ƏSAS şöbə')
          .toggle(TeamColumn.status, 'active');
      expect(filter.searchColumn, TeamColumn.department);
      expect(
        filter.toggle(TeamColumn.position, 'Paketçi').searchColumn,
        TeamColumn.position,
      );
      expect(
        filter
            .toggle(TeamColumn.name, 'Məhərrəmova Pərvanə')
            .toggle(TeamColumn.code, '0000000051')
            .searchColumn,
        TeamColumn.code,
      );
      expect(only(TeamColumn.status, 'active').searchColumn, isNull);
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(filter.toggle(TeamColumn.status, 'active').columns, <TeamColumn>[
        TeamColumn.department,
      ]);
      expect(filter.cleared(TeamColumn.department).columnCount, 1);
    });
  });

  group('the controller', () {
    test('twenty at a time, and a salary is looked for in the whole '
        'register', () async {
      final _Bridge bridge = _Bridge();
      final TeamController team = bridge.controller();
      await team.ensureLoaded();
      expect(team.members, hasLength(20));
      bridge.requests.clear();

      // Only the last two are paid over 1,000 ₼.
      await team.setRange(TeamColumn.salary, const FilterRange(min: 1000));
      final TeamFilterView view = team.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((TeamMember m) => m.id), <int>[59, 60]);
      expect(view.scans, isTrue);
      expect(view.readOf, 60);
      // Every person read was the list's own, and the page grew while
      // nothing matched.
      expect(team.members, hasLength(60));
      expect(bridge.searches, isEmpty);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '40'],
      );
    });

    test('a position goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final TeamController team = bridge.controller();
      await team.ensureLoaded();

      await team.toggleFilter(TeamColumn.position, 'Paketçi');
      final TeamFilterView view = team.filtered!;
      expect(bridge.searches, <String>['Paketçi']);
      // `Paketçi köməkçisi` holds the word too, but is not the position.
      expect(view.rows.map((TeamMember m) => m.id), <int>[5, 15]);
      expect(view.scans, isFalse);

      // Let go, the list is the list again.
      await team.clearFilter();
      expect(team.filtered, isNull);
      expect(team.members, hasLength(20));
    });

    test('Vəzifə opens onto the whole register, read once', () async {
      final _Bridge bridge = _Bridge();
      final TeamController team = bridge.controller();
      await team.ensureLoaded();
      final TeamFilterValues values = team.values;

      values.open(TeamColumn.position);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 60 əməkdaş oxundu');
      while (team.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(team.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      // The most common first; nobody's blank position is offered.
      expect(values.values, const <FilterValue>[
        FilterValue('Paketçi', 'Paketçi'),
        FilterValue('Qəssab', 'Qəssab'),
        FilterValue('Paketçi köməkçisi', 'Paketçi köməkçisi'),
      ]);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20', '40'],
      );

      // The other columns list theirs at once now, asking nothing.
      final int asked = bridge.requests.length;
      values.open(TeamColumn.name);
      expect(values.values, hasLength(60));
      values.open(TeamColumn.department);
      expect(values.values.first, const FilterValue('ƏSAS şöbə', 'ƏSAS şöbə'));
      expect(bridge.requests, hasLength(asked));
    });

    test('Status offers both, and Maaş lists nothing but its span', () {
      final TeamController team = _Bridge().controller();
      final TeamFilterValues values = team.values;
      values.open(TeamColumn.status);
      expect(values.values, const <FilterValue>[
        FilterValue('active', 'Aktiv'),
        FilterValue('inactive', 'Deaktiv'),
      ]);
      values.open(TeamColumn.salary);
      expect(values.values, isEmpty);
      expect(team.rangeFieldOf(TeamColumn.salary)!.suffix, '₼');
      expect(team.rangeFieldOf(TeamColumn.position), isNull);
    });
  });
}

/// The register: sixty people in the bridge's order. Every tenth from the
/// sixth is a packer, the fourth a butcher and the thirtieth a packer's
/// help; the rest have no position. Nobody is paid but the packers (687)
/// and the last two (1,000 and 1,160); a department on all but every third.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 60;

  TeamController controller() {
    final TeamController team = TeamController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(team.dispose);
    return team;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': i + 1,
    'code': '00000000${i.toString().padLeft(2, '0')}',
    'full_name': 'Əməkdaş $i',
    'position': switch (i) {
      3 => 'Qəssab',
      29 => 'Paketçi köməkçisi',
      _ when i % 10 == 4 && i < 20 => 'Paketçi',
      _ => '',
    },
    'department': i % 3 == 0 ? '' : 'ƏSAS şöbə',
    'salary': switch (i) {
      58 => 1000.0,
      59 => 1160.0,
      _ when i % 10 == 4 && i < 20 => 687.0,
      _ => 0.0,
    },
    'is_active': true,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['code']} ${row['full_name']} ${row['position']} '
                    '${row['department']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
          row,
    ];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
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
