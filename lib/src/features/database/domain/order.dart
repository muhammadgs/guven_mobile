import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'sale.dart' show readDocumentDate;

/// How far an order has got, which is what its colour says on a card — the
/// website's badge colours, three of them: arrived, on its way, stopped.
enum OrderTone { done, underway, stopped }

/// An order's `status`: the website's seven, in the order its filter lists
/// them, with its words for them (`one_c_dashboard.js`).
///
/// On 2026-09-27 the bridge's 7,519 orders held two of them: `delivered`
/// 7,477 times and `new` 42.
enum OrderStatus {
  fresh('new', 'Yeni', OrderTone.underway),
  confirmed('confirmed', 'Təsdiqləndi', OrderTone.done),
  processing('processing', 'İcradadır', OrderTone.underway),
  shipped('shipped', 'Göndərildi', OrderTone.underway),
  delivered('delivered', 'Çatdırıldı', OrderTone.done),
  cancelled('cancelled', 'Ləğv edildi', OrderTone.stopped),
  completed('completed', 'Tamamlandı', OrderTone.done);

  const OrderStatus(this.code, this.label, this.tone);

  /// The bridge's word, which is also what its `status` parameter takes.
  final String code;

  final String label;
  final OrderTone tone;

  static OrderStatus? byCode(String? code) {
    for (final OrderStatus status in values) {
      if (status.code == code) return status;
    }
    return null;
  }

  /// What a person reads for [code]: the website's word, or the bridge's own
  /// for a status nobody has named yet — the website does the same.
  static String labelOf(String code) => byCode(code)?.label ?? code;
}

/// An order's `payment_status`: the website's four, in its order, with its
/// words. Two of them in the data on 2026-09-27: `paid` and `unpaid`.
enum OrderPayment {
  unpaid('unpaid', 'Ödənilməyib', OrderTone.stopped),
  partial('partial', 'Qismən', OrderTone.underway),
  paid('paid', 'Ödənilib', OrderTone.done),
  overdue('overdue', 'Gecikmiş', OrderTone.stopped);

  const OrderPayment(this.code, this.label, this.tone);

  final String code;
  final String label;
  final OrderTone tone;

  static OrderPayment? byCode(String? code) {
    for (final OrderPayment payment in values) {
      if (payment.code == code) return payment;
    }
    return null;
  }

  static String labelOf(String code) => byCode(code)?.label ?? code;
}

/// One order synced from 1C — a row of the website's `Sifarişlər` table,
/// and one card on the phone.
///
/// The bridge answers it two ways, read live on 2026-09-27:
///
/// * a row of `/orders/`: `{id, onec_guid, order_number, order_date,
///   total_amount, status, payment_status, created_at, updated_at,
///   synced_at, baza_id}` — the table's five columns and nothing more;
/// * `/orders/{id}`: the same, plus `customer_id`, `paid_amount`,
///   `discount_amount`, `tax_amount`, `company_id` and `is_deleted`.
///
/// So what an open card adds — the discount, the tax, what has been paid —
/// comes from the second, asked for when the card is opened, and laid over
/// the row by [mergedWith]. Neither answer carries `remaining_amount` or
/// `currency`, which the website's window asks for too: it prints `0.00 ₼`
/// and `AZN` for them only because it writes a missing value as nothing.
@immutable
class Order {
  const Order({
    required this.id,
    this.number,
    this.date,
    this.amount,
    this.status,
    this.payment,
    this.discount,
    this.tax,
    this.paid,
    this.remaining,
  });

  /// Null when [row] has no id: the id is what opens an order, and tells it
  /// from the one that takes its place on the next page.
  ///
  /// [knownId] is for an order fetched *by* its id, whose answer need not
  /// repeat it.
  static Order? fromJson(Map<String, Object?> row, {int? knownId}) {
    final int? id = readInt(row, <String>['id', 'order_id']) ?? knownId;
    if (id == null) return null;
    return Order(
      id: id,
      number: readString(row, <String>['order_number', 'number']),
      date: readDocumentDate(row, <String>['order_date', 'date']),
      amount: readDouble(row, <String>['total_amount', 'amount', 'total']),
      status: readString(row, <String>['status']),
      payment: readString(row, <String>['payment_status']),
      discount: readDouble(row, <String>['discount_amount']),
      tax: readDouble(row, <String>['tax_amount']),
      paid: readDouble(row, <String>['paid_amount']),
      remaining: readDouble(row, <String>['remaining_amount']),
    );
  }

  final int id;

  /// `NT000007303`.
  final String? number;

  /// `2026-09-18`, the day 1C wrote on the order.
  final String? date;

  /// `Cəmi məbləğ`, in manat.
  final double? amount;

  /// The bridge's word: `delivered`, `new`… — [OrderStatus] names them.
  final String? status;

  /// The bridge's word: `paid`, `unpaid`… — [OrderPayment] names them.
  final String? payment;

  /// `Endirim`, `Vergi`, `Ödənilən` — only in the order's own answer, so
  /// null on a row until its card has been opened. `0.0` on every one of
  /// the 230 orders read on 2026-09-27, the 42 unpaid ones included: 1C
  /// does not fill them in yet.
  final double? discount;
  final double? tax;
  final double? paid;

  /// `Qalıq borc`. Sent by neither answer so far.
  final double? remaining;

  /// Whether the order's own answer has been read into this one: the row
  /// alone never carries these.
  bool get hasDetail => discount != null || tax != null || paid != null;

  /// This row with everything [detail] knows laid over it. The detail was
  /// asked for after the list, so where both say something it wins.
  Order mergedWith(Order detail) => Order(
    id: id,
    number: detail.number ?? number,
    date: detail.date ?? date,
    amount: detail.amount ?? amount,
    status: detail.status ?? status,
    payment: detail.payment ?? payment,
    discount: detail.discount ?? discount,
    tax: detail.tax ?? tax,
    paid: detail.paid ?? paid,
    remaining: detail.remaining ?? remaining,
  );
}
