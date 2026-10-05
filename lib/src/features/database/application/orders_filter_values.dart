import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/order.dart';
import '../domain/orders_filter.dart';
import '../presentation/database_format.dart';
import 'database_filter_source.dart';
import 'orders_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kOrdersValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
const int kOrdersValueSearchMin = 2;

/// How many orders a number search asks for: the list shows five or six
/// values at a time, and a longer number narrows it further.
const int kOrdersNumberSearchSize = 12;

/// The values the open column of the `Sifarişlər` filter offers — each
/// column its own, and all of them, not only the ones on the orders loaded
/// so far:
///
/// * `Sifariş` — the numbers on the phone, highest first, and while typing
///   the ones the bridge finds, since its `search` reads numbers;
/// * `Tarix`, `Məbləğ`, `Ödəniş` — every day, every amount and every payment
///   state in the table. The bridge can say none of these, so the first time
///   one of them opens the rest of the table is read
///   ([OrdersController.readAll]), and the column says how far that has got
///   rather than listing values that would still move under a finger. Days
///   newest first, amounts largest first;
/// * `Status` — the statuses the bridge says have orders: one one-row
///   count for each of the website's seven, asked once, unless every order
///   is on the phone already.
class OrdersFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  OrdersFilterValues(this._owner, this._api) {
    _owner.addListener(_ownerChanged);
  }

  final OrdersController _owner;
  final DatabaseApi _api;

  OrdersColumn? _column;

  @override
  OrdersColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  /// True while the open column waits for every order, or for the statuses
  /// to be counted, before it lists anything.
  bool _waiting = false;

  @override
  bool get isSearching => _searching || _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    if (total == null || total == 0) return 'Sifarişlər oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} sifariş oxundu';
  }

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  Timer? _debounce;
  int _serial = 0;
  bool _disposed = false;

  /// What the bridge answered a number search, by query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  /// The statuses the bridge counted orders for, once asked.
  List<String>? _statuses;
  bool _countingStatuses = false;

  final Map<OrdersColumn, List<String>> _local = <OrdersColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(OrdersColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));

    _waiting = false;
    if (!_owner.hasEveryOrder) {
      if (column.needsEveryOrder) {
        // Returns at once if the reading is already under way.
        _owner.readAll();
        _waiting = _owner.isReadingAll;
      } else if (column == OrdersColumn.status) {
        if (_owner.isReadingAll) {
          // The table is on its way anyway, and asking the bridge beside it
          // risks the connection it drops when asked two things at once.
          _waiting = true;
        } else if (_statuses == null) {
          _waiting = true;
          _countStatuses();
        }
      }
    }
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _waiting = false;
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text], and asks the bridge once typing pauses.
  @override
  void search(String text) {
    final OrdersColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column == OrdersColumn.number &&
        !_owner.hasEveryOrder &&
        query.length >= kOrdersValueSearchMin &&
        !_answers.containsKey(filterSearchKey(query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kOrdersValueSearchDelay, () => _ask(query));
    }
    notifyListeners();
  }

  /// The numbers of the orders whose number holds [query].
  Future<void> _ask(String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<Order> page = await _api.ordersPage(
        page: 1,
        pageSize: kOrdersNumberSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[key] = <String>[
        for (final Order order in page.rows)
          if (order.number case final String number
              when filterSearchKey(number).contains(key))
            number,
      ];
    } on ApiException {
      // What is on the phone is still listed, and the next letter typed asks
      // again.
    } finally {
      if (!_disposed && serial == _serial) {
        _searching = false;
        if (_column == OrdersColumn.number) _rebuild();
        notifyListeners();
      }
    }
  }

  /// Which of the website's statuses have orders: a one-row count of each,
  /// one after another — the bridge drops connections asked for several at
  /// once.
  Future<void> _countStatuses() async {
    if (_countingStatuses) return;
    _countingStatuses = true;
    try {
      final List<String> found = <String>[];
      for (final OrderStatus status in OrderStatus.values) {
        final DatabasePage<Order> page = await _api.ordersPage(
          page: 1,
          pageSize: 1,
          status: status.code,
        );
        if (_disposed) return;
        if ((page.total ?? page.received) > 0) found.add(status.code);
      }
      _statuses = found;
    } on ApiException {
      // The statuses of the orders on the phone are still listed; the next
      // time the column opens asks again.
    } finally {
      _countingStatuses = false;
      if (!_disposed) _finishWaiting(OrdersColumn.status);
    }
  }

  /// The owner has moved on: rows arrived, or the table has been read.
  void _ownerChanged() {
    final OrdersColumn? column = _column;
    if (column == null || !_waiting || _owner.isReadingAll) return;
    if (column == OrdersColumn.status && _countingStatuses) return;
    _finishWaiting(column);
  }

  void _finishWaiting(OrdersColumn column) {
    if (_column != column || !_waiting) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final OrdersColumn? column = _column;
    if (column == null || _waiting) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = _query.trim();
    final String key = filterSearchKey(query);
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = _valueOf(column, value);
      if (key.isNotEmpty && !_hits(column, item, query)) return;
      if (seen.add(_identity(column, value))) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);

    switch (column) {
      case OrdersColumn.number:
        _localValues(column).forEach(add);
        _answered()?.forEach(add);
      case OrdersColumn.status:
        final Set<String> present = <String>{
          ..._localValues(column),
          ...?_statuses,
        };
        // The website's order; a status it has no word for, after them.
        for (final OrderStatus status in OrderStatus.values) {
          if (present.contains(status.code)) add(status.code);
        }
        _localValues(column).forEach(add);
      case OrdersColumn.payment:
        final List<String> present = _localValues(column);
        for (final OrderPayment payment in OrderPayment.values) {
          if (present.contains(payment.code)) add(payment.code);
        }
        present.forEach(add);
      case OrdersColumn.date || OrdersColumn.amount:
        _localValues(column).forEach(add);
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered() {
    final String query = _query.trim();
    for (int end = query.length; end >= kOrdersValueSearchMin; end--) {
      final List<String>? answer =
          _answers[filterSearchKey(query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(OrdersColumn column, String value) =>
      switch (column) {
        OrdersColumn.number => filterKey(value),
        OrdersColumn.amount => '${amountKey(double.tryParse(value))}',
        _ => value,
      };

  static FilterValue _valueOf(OrdersColumn column, String value) =>
      switch (column) {
        OrdersColumn.number => FilterValue(value, tidySpaces(value)),
        OrdersColumn.date => FilterValue(value, value),
        OrdersColumn.amount => FilterValue(
          value,
          formatMoney(double.tryParse(value) ?? 0),
        ),
        OrdersColumn.status => FilterValue(value, OrderStatus.labelOf(value)),
        OrdersColumn.payment => FilterValue(value, OrderPayment.labelOf(value)),
      };

  static bool _hits(OrdersColumn column, FilterValue item, String query) {
    final String key = filterSearchKey(query);
    if (filterSearchKey(item.label).contains(key)) return true;
    switch (column) {
      case OrdersColumn.date:
        // `18.09`, `18.09.2026` and `1809` find `2026-09-18` too.
        final List<String> parts = item.value.split('-');
        if (parts.length != 3) return false;
        final String dotted = '${parts[2]}.${parts[1]}.${parts[0]}';
        if (dotted.contains(key)) return true;
        final String digits = key.replaceAll(RegExp(r'\D'), '');
        return digits.isNotEmpty &&
            (dotted.replaceAll('.', '').contains(digits) ||
                item.value.replaceAll('-', '').contains(digits));
      case OrdersColumn.amount:
        // `6720` finds `6,720.00 ₼`; so does `6,720`, whose comma groups
        // thousands, and `27,9` finds `27.90 ₼`, whose comma is the decimal
        // point a local keyboard types.
        String typed = key.replaceAll(RegExp(r'[\s₼]'), '');
        if (typed.isEmpty) return false;
        final bool grouped = RegExp(r',\d{3}(?!\d)').hasMatch(typed);
        typed = grouped
            ? typed.replaceAll(',', '')
            : typed.replaceAll(',', '.');
        return item.value.contains(typed);
      default:
        return false;
    }
  }

  /// Every value of [column] among the orders on the phone: numbers highest
  /// first, days newest first, amounts largest first, statuses as met.
  List<String> _localValues(OrdersColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Set<String> seen = <String>{};
      final List<String> out = <String>[];
      for (final Order order in _owner.knownOrders) {
        final String? value = switch (column) {
          OrdersColumn.number => order.number,
          OrdersColumn.date => order.date,
          OrdersColumn.amount =>
            order.amount == null || !order.amount!.isFinite
                ? null
                : amountValue(order.amount!),
          OrdersColumn.status => order.status,
          OrdersColumn.payment => order.payment,
        };
        if (value == null) continue;
        final String identity = _identity(column, value);
        if (identity.isEmpty) continue;
        if (seen.add(identity)) out.add(value);
      }
      switch (column) {
        case OrdersColumn.number || OrdersColumn.date:
          out.sort((String a, String b) => b.compareTo(a));
        case OrdersColumn.amount:
          out.sort(
            (String a, String b) => double.parse(b).compareTo(double.parse(a)),
          );
        case OrdersColumn.status || OrdersColumn.payment:
          break;
      }
      return out;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _owner.removeListener(_ownerChanged);
    super.dispose();
  }
}
