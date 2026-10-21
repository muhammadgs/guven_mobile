import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// Which side of a debt a list holds: what the company owes, or what it is
/// owed. `Kreditorlar` and `Debitorlar` are one page drawn twice — the same
/// row, the same card, the same filter — and this is all that tells them
/// apart.
enum DebtKind {
  /// `Kreditorlar` — *bizim borcumuz*: the suppliers, the bank, the tax
  /// office the company has yet to pay.
  creditors('creditors', 'Borcumuz', 'kreditor'),

  /// `Debitorlar` — *bizə borclu olanlar*: the customers who have yet to
  /// pay the company.
  debitors('debitors', 'Borc', 'debitor');

  const DebtKind(this.endpoint, this.debtLabel, this.unit);

  /// The bridge's own word for the list: `/onec-data/{endpoint}/`.
  final String endpoint;

  /// What the card calls the amount (the user, 2026-10-20): `Borcumuz` on
  /// the creditors' — it is the company's own debt — and `Borc` on the
  /// debtors'.
  final String debtLabel;

  /// What one row is called: `88 kreditor`.
  final String unit;
}

/// One open debt between the company and a counterparty, under one
/// contract — a row of the website's `Kreditorlar` or `Debitorlar` table, and
/// one card on the phone.
///
/// A row of `/onec-data/creditors/` or `/onec-data/debitors/`, read live on
/// 2026-10-20: `{id, onec_guid, contractor, contract_id, contract,
/// total_debt, settlement_total, currency, organization, is_paid, baza_id,
/// synced_at}`. 88 creditors and 120 debtors, every one a single contract
/// with a positive debt, in AZN, of `NaTural-İD`, not paid. There is no
/// answer for one row on its own, and nothing a row leaves out to ask for.
///
/// The website's `Debet` and `Kredit` columns are not 1C's: it copies
/// [debt] into one of them by which list it is drawing, and leaves the other
/// empty. The phone shows the figure once.
@immutable
class Debt {
  const Debt({
    required this.id,
    this.contractor,
    this.contract,
    this.organization,
    this.debt,
    this.settlement,
    this.currency,
    this.paidFlag,
  });

  /// Null when [row] has no id: the id is what tells a row from the one that
  /// takes its place on the next page.
  static Debt? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id']);
    if (id == null) return null;
    return Debt(
      id: id,
      contractor: readString(row, <String>['contractor', 'counterparty']),
      contract: readString(row, <String>['contract', 'contract_name']),
      organization: readString(row, <String>['organization']),
      debt: readDouble(row, <String>['total_debt', 'debt']),
      settlement: readDouble(row, <String>['settlement_total', 'settlement']),
      currency: readString(row, <String>['currency']),
      paidFlag: readBool(row, <String>['is_paid']),
    );
  }

  final int id;

  /// `ORXAN ƏT MMC   __`, as 1C spells it — doubled spaces, trailing
  /// underscores and all.
  final String? contractor;

  /// `Əsas müqavilə`, `2026 Əsas müqavilə `, or a long one 1C cut at 50
  /// characters: `08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M`.
  final String? contract;

  /// `NaTural-İD` — the company's own legal entity in 1C, the one the
  /// contract was signed under.
  final String? organization;

  /// `total_debt`: what is still owed, in [currency].
  final double? debt;

  /// `settlement_total`: the debt in the contract's own settlement currency.
  /// Equal to [debt] on every one of the 208 rows on 2026-10-20 — they are
  /// all in manat.
  final double? settlement;

  /// `AZN` on every row.
  final String? currency;

  /// `is_paid` as the bridge sends it: false on every row.
  final bool? paidFlag;

  /// The website's own test: paid when 1C says so, or when nothing is owed
  /// (`d.is_paid === 1 || totalDebt === 0`).
  bool get paid => paidFlag == true || (debt ?? 0) == 0;
}
