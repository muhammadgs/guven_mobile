import 'package:flutter/foundation.dart';

/// Every page the signed-in app can show, whether its button sits in the bar
/// or in the `Daha çox` fan.
///
/// The declaration order is the page stack's order and nothing else — where a
/// page's *button* sits is [ShellNavLayout]'s business, and moving a button
/// must never rebuild the page behind it.
enum ShellDestination {
  companies('Şirkətlər', 'company.svg'),
  employees('Əməkdaşlar', 'workers.svg'),
  home('Əsas səhifə', 'home.svg'),
  tasks('Tapşırıqlar', 'tasks.svg'),
  partners('Partniyorlar', 'partniyorlar.svg'),
  protocols('Protokol/Qeyd', 'protokol_qeyd.svg'),
  documents('Sənədlər', 'senedler.svg'),
  departments('Departamentlər', 'departamentler.svg'),
  institutions('Rəsmi Qurumlar', 'resmi_qurumlar.svg'),
  board('Board', 'board.svg'),
  settings('Tənzimləmə', 'tenzimleme.svg'),
  database('Baza', 'baza.svg');

  const ShellDestination(this.title, this._iconFile);

  final String title;
  final String _iconFile;

  String get icon => '$kNavIconDir$_iconFile';
}

const String kNavIconDir = 'assets/images/icons/nav_icons/';

/// The `Daha çox` cell's own glyphs: filled while the fan is shut, outlines
/// only while it is open — its inside empties, and the pages it holds are
/// what fill the screen instead.
const String kMenuTitle = 'Daha çox';
const String kMenuIcon = '${kNavIconDir}menu.svg';
const String kMenuOpenIcon = '${kNavIconDir}menu_open.svg';

/// Which of the two places a button can live.
enum NavShelf { bar, more }

/// One place a button can occupy.
@immutable
class NavSlot {
  const NavSlot(this.shelf, this.index);

  final NavShelf shelf;

  /// For [NavShelf.bar], the index among the bar's *pages* — `Daha çox` is
  /// not one of them. See [ShellNavLayout.cellOf].
  final int index;

  @override
  bool operator ==(Object other) =>
      other is NavSlot && other.shelf == shelf && other.index == index;

  @override
  int get hashCode => Object.hash(shelf, index);

  @override
  String toString() => 'NavSlot(${shelf.name}, $index)';
}

/// Which page buttons sit in the bar and which in the `Daha çox` fan, and in
/// what order.
///
/// `Daha çox` itself is not in either list: it is pinned to the bar's middle
/// cell ([menuCell]), because the fan grows out of it and cannot be dragged
/// into itself. So the bar always has [barPageCount] pages around it and the
/// fan always holds the rest — a drag between the two is a swap, never a move,
/// and neither count ever changes.
@immutable
class ShellNavLayout {
  const ShellNavLayout({required this.bar, required this.more});

  static const int barPageCount = 4;

  /// `Daha çox`'s cell in the five-cell bar.
  static const int menuCell = 2;

  static const int cellCount = barPageCount + 1;

  static const ShellNavLayout defaults = ShellNavLayout(
    bar: <ShellDestination>[
      ShellDestination.companies,
      ShellDestination.employees,
      ShellDestination.home,
      ShellDestination.tasks,
    ],
    more: <ShellDestination>[
      ShellDestination.partners,
      ShellDestination.protocols,
      ShellDestination.documents,
      ShellDestination.departments,
      ShellDestination.institutions,
      ShellDestination.board,
      ShellDestination.settings,
      ShellDestination.database,
    ],
  );

  final List<ShellDestination> bar;
  final List<ShellDestination> more;

  /// The bar cell that shows bar page [barIndex].
  static int cellOf(int barIndex) =>
      barIndex < menuCell ? barIndex : barIndex + 1;

  /// The bar page shown in [cell], or null for `Daha çox`'s own cell.
  static int? barIndexOfCell(int cell) {
    if (cell == menuCell) return null;
    return cell < menuCell ? cell : cell - 1;
  }

  List<ShellDestination> shelf(NavShelf shelf) =>
      shelf == NavShelf.bar ? bar : more;

  ShellDestination at(NavSlot slot) => shelf(slot.shelf)[slot.index];

  NavSlot slotOf(ShellDestination destination) {
    final int inBar = bar.indexOf(destination);
    if (inBar >= 0) return NavSlot(NavShelf.bar, inBar);
    return NavSlot(NavShelf.more, more.indexOf(destination));
  }

  /// The bar cell [destination] sits in, or null when it is in the fan.
  int? cellOfDestination(ShellDestination destination) {
    final int inBar = bar.indexOf(destination);
    return inBar < 0 ? null : cellOf(inBar);
  }

  /// The layout after the button in [from] has been dropped on [to].
  ///
  /// Within one shelf the button is lifted out and reinserted, so the ones in
  /// between close ranks — the way icons reflow on a phone's home screen.
  /// Across shelves the two buttons trade places, which is what keeps the bar
  /// at exactly [barPageCount] pages.
  ShellNavLayout moved(NavSlot from, NavSlot to) {
    if (from == to) return this;
    final List<ShellDestination> nextBar = List<ShellDestination>.of(bar);
    final List<ShellDestination> nextMore = List<ShellDestination>.of(more);
    List<ShellDestination> of(NavShelf shelf) =>
        shelf == NavShelf.bar ? nextBar : nextMore;

    if (from.shelf == to.shelf) {
      final List<ShellDestination> list = of(from.shelf);
      final ShellDestination item = list.removeAt(from.index);
      list.insert(to.index, item);
    } else {
      final ShellDestination lifted = at(from);
      final ShellDestination displaced = at(to);
      of(from.shelf)[from.index] = displaced;
      of(to.shelf)[to.index] = lifted;
    }
    return ShellNavLayout(
      bar: List<ShellDestination>.unmodifiable(nextBar),
      more: List<ShellDestination>.unmodifiable(nextMore),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'bar': <String>[for (final ShellDestination d in bar) d.name],
    'more': <String>[for (final ShellDestination d in more) d.name],
  };

  /// Reads a saved layout back, or null when it cannot be trusted: a page
  /// that no longer exists, one that appears twice, one that is missing, or a
  /// bar of the wrong length. A stale layout falls back to [defaults] rather
  /// than hiding a page nobody can reach.
  static ShellNavLayout? fromJson(Object? json) {
    if (json is! Map) return null;
    final List<ShellDestination>? bar = _destinations(json['bar']);
    final List<ShellDestination>? more = _destinations(json['more']);
    if (bar == null || more == null || bar.length != barPageCount) return null;
    final Set<ShellDestination> seen = <ShellDestination>{...bar, ...more};
    if (seen.length != bar.length + more.length ||
        seen.length != ShellDestination.values.length) {
      return null;
    }
    return ShellNavLayout(
      bar: List<ShellDestination>.unmodifiable(bar),
      more: List<ShellDestination>.unmodifiable(more),
    );
  }

  static List<ShellDestination>? _destinations(Object? json) {
    if (json is! List) return null;
    final List<ShellDestination> out = <ShellDestination>[];
    for (final Object? name in json) {
      final ShellDestination? match = ShellDestination.values
          .where((ShellDestination d) => d.name == name)
          .firstOrNull;
      if (match == null) return null;
      out.add(match);
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is ShellNavLayout &&
      listEquals(other.bar, bar) &&
      listEquals(other.more, more);

  @override
  int get hashCode => Object.hash(Object.hashAll(bar), Object.hashAll(more));
}
