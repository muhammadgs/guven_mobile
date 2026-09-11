import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/shell/domain/shell_destination.dart';

void main() {
  const ShellNavLayout d = ShellNavLayout.defaults;

  test('the default bar and fan are the design\'s', () {
    expect(d.bar.map((ShellDestination p) => p.title), <String>[
      'Şirkətlər',
      'Əməkdaşlar',
      'Əsas səhifə',
      'Tapşırıqlar',
    ]);
    expect(d.more.map((ShellDestination p) => p.title), <String>[
      'Partniyorlar',
      'Protokol/Qeyd',
      'Sənədlər',
      'Departamentlər',
      'Rəsmi Qurumlar',
      'Board',
      'Tənzimləmə',
      'Baza',
    ]);
    // Every page has exactly one button.
    expect(<ShellDestination>{...d.bar, ...d.more}.length,
        ShellDestination.values.length);
  });

  test('Daha çox sits in the middle cell, pages around it', () {
    expect(ShellNavLayout.barIndexOfCell(ShellNavLayout.menuCell), isNull);
    for (int page = 0; page < ShellNavLayout.barPageCount; page++) {
      final int cell = ShellNavLayout.cellOf(page);
      expect(cell, isNot(ShellNavLayout.menuCell));
      expect(ShellNavLayout.barIndexOfCell(cell), page);
    }
    expect(d.cellOfDestination(ShellDestination.home), 3);
    expect(d.cellOfDestination(ShellDestination.board), isNull);
  });

  test('along one shelf a button is reinserted, and the rest close ranks', () {
    final ShellNavLayout bar = d.moved(
      const NavSlot(NavShelf.bar, 3),
      const NavSlot(NavShelf.bar, 0),
    );
    expect(bar.bar, <ShellDestination>[
      ShellDestination.tasks,
      ShellDestination.companies,
      ShellDestination.employees,
      ShellDestination.home,
    ]);
    expect(bar.more, d.more);

    final ShellNavLayout fan = d.moved(
      const NavSlot(NavShelf.more, 0),
      const NavSlot(NavShelf.more, 7),
    );
    expect(fan.more.first, ShellDestination.protocols);
    expect(fan.more.last, ShellDestination.partners);
    expect(fan.bar, d.bar);
  });

  test('between the bar and the fan two buttons trade places', () {
    final ShellNavLayout traded = d.moved(
      const NavSlot(NavShelf.more, 5),
      const NavSlot(NavShelf.bar, 0),
    );
    expect(traded.bar.first, ShellDestination.board);
    expect(traded.more[5], ShellDestination.companies);
    expect(traded.bar.length, ShellNavLayout.barPageCount);
    expect(traded.more.length, d.more.length);

    final ShellNavLayout back = traded.moved(
      const NavSlot(NavShelf.bar, 0),
      const NavSlot(NavShelf.more, 5),
    );
    expect(back, d);
  });

  test('a saved layout comes back, and a stale one is refused', () {
    final ShellNavLayout traded = d.moved(
      const NavSlot(NavShelf.more, 2),
      const NavSlot(NavShelf.bar, 1),
    );
    expect(ShellNavLayout.fromJson(traded.toJson()), traded);

    expect(ShellNavLayout.fromJson(null), isNull);
    expect(ShellNavLayout.fromJson(<String, Object?>{'bar': 'x'}), isNull);
    // A page that no longer exists.
    expect(
      ShellNavLayout.fromJson(<String, Object?>{
        'bar': <String>['companies', 'employees', 'home', 'reports'],
        'more': d.more.map((ShellDestination p) => p.name).toList(),
      }),
      isNull,
    );
    // A page missing, one twice.
    expect(
      ShellNavLayout.fromJson(<String, Object?>{
        'bar': <String>['companies', 'employees', 'home', 'home'],
        'more': d.more.map((ShellDestination p) => p.name).toList(),
      }),
      isNull,
    );
    // A bar of the wrong length.
    expect(
      ShellNavLayout.fromJson(<String, Object?>{
        'bar': <String>['companies', 'employees', 'home'],
        'more': <String>[
          'tasks',
          ...d.more.map((ShellDestination p) => p.name),
        ],
      }),
      isNull,
    );
  });
}
