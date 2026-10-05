import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One customer in 1C's directory — a row of the website's `Müştərilər`
/// table, and one card on the phone.
///
/// The bridge answers it two ways, read live on 2026-10-04:
///
/// * a row of `/customers/`: `{id, code, name, inn, customer_type,
///   payment_deadline_days, credit_limit, phone, email, …}` — everything a
///   shut card and the filter need;
/// * `/customers/{id}`: the same, plus what only an open card shows — the
///   role (`is_buyer`, `is_supplier`) and the legal status (`legal_type`).
///   It is asked for when the card is opened, and laid over the row by
///   [mergedWith].
///
/// The field names are the website's (`one_c_dashboard.js`), since the
/// bridge's spec types the answers as a bare `{}`.
@immutable
class Customer {
  const Customer({
    required this.id,
    this.code,
    this.taxId,
    this.name,
    this.type,
    this.paymentDays,
    this.legalStatus,
    this.buyer,
    this.supplier,
  });

  /// Null when [row] has no id: the id is what opens a customer, and tells
  /// it from the one that takes its place on the next page.
  ///
  /// [knownId] is for a customer fetched *by* its id, whose answer need not
  /// repeat it.
  static Customer? fromJson(Map<String, Object?> row, {int? knownId}) {
    final int? id = readInt(row, <String>['id', 'customer_id']) ?? knownId;
    if (id == null) return null;
    return Customer(
      id: id,
      code: readString(row, <String>['code']),
      taxId: readString(row, <String>['inn', 'voen']),
      name: readString(row, <String>['name', 'full_name']),
      type: readString(row, <String>['customer_type']),
      paymentDays: readInt(row, <String>['payment_deadline_days']),
      legalStatus: readString(row, <String>['legal_type']),
      buyer: readBool(row, <String>['is_buyer']),
      supplier: readBool(row, <String>['is_supplier']),
    );
  }

  final int id;

  /// `NT0000275` — the customer's code in 1C. Every customer has one.
  final String? code;

  /// The VÖEN, which 45 of 310 customers had on 2026-10-04; 1C leaves the
  /// rest blank.
  final String? taxId;

  /// `(İŞÇİ) -  FİDAN S.`, exactly as 1C spells it — spaces doubled or
  /// trailing, as some of the names are.
  final String? name;

  /// `legal` or `physical`, 1C's own word for the kind of customer.
  final String? type;

  /// How many days the customer has to pay: 30 for every customer on
  /// 2026-10-04.
  final int? paymentDays;

  /// `Hüq. şəxs` — 1C's own short words, from the customer's own answer.
  final String? legalStatus;

  /// `is_buyer` and `is_supplier`, from the customer's own answer; null
  /// until that has been read.
  final bool? buyer;
  final bool? supplier;

  /// What the card's `Kod/ Vöen` line shows: the VÖEN when 1C has one, the
  /// code when it does not — the website's `inn || code`.
  String? get taxIdOrCode => taxId ?? code;

  /// Whether the customer is a legal person: the website's own test, any
  /// `customer_type` that says `legal`.
  bool get isLegal => type?.toLowerCase().contains('legal') ?? false;

  /// `Hüquqi` or `Fiziki`, as the website words the kind; null when 1C does
  /// not say. Anything that is not `legal` is `Fiziki`, as on the website.
  String? get typeLabel {
    if (type == null) return null;
    return isLegal ? 'Hüquqi' : 'Fiziki';
  }

  /// Whether the customer's own answer has been read, so [roleLabel] and
  /// [legalStatus] mean what they say rather than "not asked yet".
  bool get hasDetail => buyer != null || supplier != null;

  /// `Alıcı`, `Təchizatçı` or both, as the website words the role; null for
  /// a customer that is neither, or one whose own answer is not yet here.
  String? get roleLabel {
    final List<String> roles = <String>[
      if (buyer == true) 'Alıcı',
      if (supplier == true) 'Təchizatçı',
    ];
    return roles.isEmpty ? null : roles.join(', ');
  }

  /// `30 gün`, or null — the website prints `—` for a term of 0 as well as a
  /// missing one.
  String? get paymentTerm {
    final int? days = paymentDays;
    if (days == null || days <= 0) return null;
    return '$days gün';
  }

  /// The row, with [detail] — the customer's own, later answer — laid over
  /// it.
  Customer mergedWith(Customer detail) => Customer(
    id: id,
    code: detail.code ?? code,
    taxId: detail.taxId ?? taxId,
    name: detail.name ?? name,
    type: detail.type ?? type,
    paymentDays: detail.paymentDays ?? paymentDays,
    legalStatus: detail.legalStatus ?? legalStatus,
    buyer: detail.buyer ?? buyer,
    supplier: detail.supplier ?? supplier,
  );
}
