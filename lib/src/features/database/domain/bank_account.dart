import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One bank account in 1C's catalogue — a row of the website's `Bank
/// Hesabları` table, and one card on the phone.
///
/// The bridge answers it two ways, read live on 2026-10-08:
///
/// * a row of `/bank-accounts/`: `{id, onec_guid, code, name, bank_name,
///   account_number, currency, is_default, is_active, created_at,
///   updated_at, baza_id}` — everything a shut card and the filter need;
/// * `/bank-accounts/{id}`: the same, plus what only an open card shows —
///   `payments_count`, `total_in`, `total_out` and `balance` (and the
///   payments themselves, which the card does not list). It is asked for
///   when the card is opened, and laid over the row by [mergedWith].
///
/// There were ten accounts, all in manat, all active, none the default, and
/// none with a payment yet. The 1C guid is not shown, as on `Kassalar`.
@immutable
class BankAccount {
  const BankAccount({
    required this.id,
    this.code,
    this.name,
    this.bankName,
    this.number,
    this.currency = kBankAccountCurrency,
    this.isDefault,
    this.active,
    this.paymentsCount,
    this.totalIn,
    this.totalOut,
    this.balance,
  });

  /// Null when [row] has no id: the id is what opens an account, and tells
  /// it from the one that takes its place on the next page.
  ///
  /// [knownId] is for an account fetched *by* its id, whose answer need not
  /// repeat it.
  static BankAccount? fromJson(Map<String, Object?> row, {int? knownId}) {
    final int? id = readInt(row, <String>['id', 'bank_account_id']) ?? knownId;
    if (id == null) return null;
    return BankAccount(
      id: id,
      code: readString(row, <String>['code']),
      name: readString(row, <String>['name']),
      bankName: readString(row, <String>['bank_name', 'bank']),
      number: readString(row, <String>['account_number', 'iban']),
      // The website's own rule, `b.currency || 'AZN'`: an account 1C names
      // no currency for keeps the company's own.
      currency: readString(row, <String>['currency']) ?? kBankAccountCurrency,
      isDefault: readBool(row, <String>['is_default']),
      active: readBool(row, <String>['is_active']),
      paymentsCount: readInt(row, <String>['payments_count']),
      totalIn: readDouble(row, <String>['total_in']),
      totalOut: readDouble(row, <String>['total_out']),
      balance: readDouble(row, <String>['balance']),
    );
  }

  final int id;

  /// `NT0000001` — the account's code in 1C.
  final String? code;

  /// `CARI-Pasha bank AZ60 (əsas)`, as 1C spells it.
  final String? name;

  /// `Pasha bank` — the bank the account is held at.
  final String? bankName;

  /// `AZ60PAHA40060AZNHC0100191890` — the account's number, an IBAN where
  /// 1C has one.
  final String? number;

  /// `AZN` — or, when 1C names none, [kBankAccountCurrency].
  final String currency;

  /// `is_default`: the company's main account. False for all ten on
  /// 2026-10-08.
  final bool? isDefault;

  /// `is_active`: true for all ten on 2026-10-08.
  final bool? active;

  /// What only the account's own answer carries: how many payments went
  /// through it, what came in, what went out, and what is left. Null until
  /// that answer has been read.
  final int? paymentsCount;
  final double? totalIn;
  final double? totalOut;
  final double? balance;

  /// `Əsas` or `Əlavə`, as the website words the kind; null when 1C does
  /// not say.
  String? get kindLabel => switch (isDefault) {
    true => 'Əsas',
    false => 'Əlavə',
    null => null,
  };

  /// Whether the account's own answer has been read, so the figures mean
  /// what they say rather than "not asked yet".
  bool get hasDetail =>
      paymentsCount != null ||
      totalIn != null ||
      totalOut != null ||
      balance != null;

  /// The row, with [detail] — the account's own, later answer — laid over
  /// it.
  BankAccount mergedWith(BankAccount detail) => BankAccount(
    id: id,
    code: detail.code ?? code,
    name: detail.name ?? name,
    bankName: detail.bankName ?? bankName,
    number: detail.number ?? number,
    currency: detail.currency,
    isDefault: detail.isDefault ?? isDefault,
    active: detail.active ?? active,
    paymentsCount: detail.paymentsCount ?? paymentsCount,
    totalIn: detail.totalIn ?? totalIn,
    totalOut: detail.totalOut ?? totalOut,
    balance: detail.balance ?? balance,
  );
}

/// What an account's currency is when 1C does not say: the website's `AZN`.
const String kBankAccountCurrency = 'AZN';
