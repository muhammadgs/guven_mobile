import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One sale document synced from 1C — a row of the website's `Satış
/// Sənədləri` table, and one card on the phone.
///
/// The same shape serves both answers the bridge gives: a row of
/// `/onec-data/sales/`, and the document from `/onec-data/sales/{id}`.
/// Seen live on 2026-09-24, a list row already carries everything an open
/// card shows — the organisation and the product lines included — so the
/// document is only asked for when a row turns up without them, and
/// [mergedWith] lays it over the row.
///
/// The field names are the website's (`one_c_dashboard.js`), because the
/// bridge's own spec types both answers as a bare `{}`.
@immutable
class Sale {
  const Sale({
    required this.id,
    this.number,
    this.date,
    this.customer,
    this.manager,
    this.warehouse,
    this.organization,
    this.docType,
    this.amount,
    this.currency,
    this.posted,
    this.sold,
    this.lines,
  });

  /// Null when [row] has no id: the id is what opens a document, and a card
  /// that could never open is not worth a place in the list.
  ///
  /// [knownId] is for a document fetched *by* its id, whose answer need not
  /// repeat it.
  static Sale? fromJson(Map<String, Object?> row, {int? knownId}) {
    final int? id = readInt(row, <String>['id', 'sale_id']) ?? knownId;
    if (id == null) return null;

    final Object? lines = row['lines'];
    return Sale(
      id: id,
      number: readString(row, <String>['order_number', 'number', 'doc_number']),
      date: readDocumentDate(row, <String>['order_date', 'date', 'doc_date']),
      customer: readString(row, <String>['customer', 'customer_name']),
      manager: readString(row, <String>['manager', 'manager_name']),
      warehouse: readString(row, <String>['warehouse', 'warehouse_name']),
      organization: readString(row, <String>[
        'organization',
        'organization_name',
      ]),
      docType: readString(row, <String>['doc_type', 'document_type']),
      amount: readDouble(row, <String>['total_amount', 'amount', 'total']),
      currency: readString(row, <String>['currency']),
      posted: readBool(row, <String>['is_posted', 'posted']),
      sold: readBool(row, <String>['is_sold', 'sold']),
      lines: lines is List
          ? <SaleLine>[
              for (final Map<String, Object?> line in asRows(lines))
                SaleLine.fromJson(line),
            ]
          : null,
    );
  }

  final int id;

  /// `NT000007303`.
  final String? number;

  /// `2026-09-18`, the day 1C wrote on the document.
  final String? date;

  final String? customer;
  final String? manager;

  /// Sent as `""` on every document seen so far, which is read as unknown —
  /// the website's table says `—` for all of them too.
  final String? warehouse;

  /// `Təşkilat` — which of the company's own legal entities sold it.
  final String? organization;

  /// The bridge's own word for the kind of document — `invoice`, `order`…
  /// [docTypeLabel] is what a person reads.
  final String? docType;

  final double? amount;

  /// `AZN` unless the document says otherwise.
  final String? currency;

  /// Null when the answer did not say; read as "no", the way the website
  /// reads it.
  final bool? posted;
  final bool? sold;

  /// Null when the answer did not carry them, which is never confused with a
  /// document that has none.
  final List<SaleLine>? lines;

  bool get isPosted => posted ?? false;
  bool get isSold => sold ?? false;

  /// The website's names for the kinds, plus `order`, which it leaves in
  /// English only because its map lacks the entry.
  static const Map<String, String> _docTypeNames = <String, String>{
    'invoice': 'Qaimə',
    'sale': 'Satış',
    'sales_invoice': 'Satış qaiməsi',
    'return': 'Qaytarılma',
    'credit': 'Kredit sənədi',
    'order': 'Sifariş',
  };

  /// `Qaimə`, or the bridge's own word for a kind nobody has named yet.
  String? get docTypeLabel {
    final String? type = docType;
    return type == null ? null : kindLabel(type);
  }

  /// What a person reads for the bridge's word for a kind: `invoice` →
  /// `Qaimə`.
  static String kindLabel(String docType) =>
      _docTypeNames[docType.toLowerCase()] ?? docType;

  /// This row with everything [detail] knows laid over it.
  ///
  /// The document is the fresher of the two answers — it was asked for after
  /// the list — so where both say something, it wins.
  Sale mergedWith(Sale detail) => Sale(
    id: id,
    number: detail.number ?? number,
    date: detail.date ?? date,
    customer: detail.customer ?? customer,
    manager: detail.manager ?? manager,
    warehouse: detail.warehouse ?? warehouse,
    organization: detail.organization ?? organization,
    docType: detail.docType ?? docType,
    amount: detail.amount ?? amount,
    currency: detail.currency ?? currency,
    posted: detail.posted ?? posted,
    sold: detail.sold ?? sold,
    lines: detail.lines ?? lines,
  );

  /// Whether an open card has to ask for the document.
  ///
  /// Only when the row itself does not already say everything an open card
  /// shows. An empty `lines` in a *list* answer is not taken at its word — a
  /// list that leaves its lines out may well send `[]` for them.
  bool get needsDocument {
    final List<SaleLine>? lines = this.lines;
    return lines == null || lines.isEmpty || organization == null;
  }
}

/// One product on a sale document: the site's `Sətirlər` table, row by row.
@immutable
class SaleLine {
  const SaleLine({this.product, this.quantity, this.price, this.amount});

  factory SaleLine.fromJson(Map<String, Object?> row) => SaleLine(
    product: readString(row, <String>['product_name', 'name', 'product']),
    quantity: readDouble(row, <String>['quantity', 'qty']),
    price: readDouble(row, <String>['price']),
    amount: readDouble(row, <String>['amount', 'total', 'sum']),
  );

  final String? product;
  final double? quantity;
  final double? price;
  final double? amount;
}

/// The calendar day of a document, as `2026-09-18`.
///
/// Read the way the website shows it. A timestamp that names its zone is
/// moved into the phone's own before its day is taken, as a browser would;
/// one without a zone is 1C's local time already, and its date is read as
/// written — shifting a document dated midnight by the phone's offset would
/// file it under the day before.
String? readDocumentDate(Map<String, Object?> row, List<String> keys) {
  final String? text = readString(row, keys);
  if (text == null) return null;

  final bool zoned =
      text.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
  if (zoned) {
    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed != null) return _isoDay(parsed.toLocal());
  }

  final RegExpMatch? iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) return iso.group(0);

  // `18.09.2026`, the way 1C itself writes a date.
  final RegExpMatch? dotted = RegExp(
    r'^(\d{2})\.(\d{2})\.(\d{4})',
  ).firstMatch(text);
  if (dotted != null) {
    return '${dotted.group(3)}-${dotted.group(2)}-${dotted.group(1)}';
  }
  return text;
}

String _isoDay(DateTime at) =>
    '${at.year.toString().padLeft(4, '0')}-'
    '${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';
