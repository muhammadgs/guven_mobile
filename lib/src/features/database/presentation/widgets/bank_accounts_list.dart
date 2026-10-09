import 'package:flutter/material.dart';

import '../../application/bank_accounts_controller.dart';
import '../../application/database_list_controller.dart';
import '../../domain/bank_account.dart';
import 'bank_account_card.dart';
import 'database_list.dart';

/// What `Bank Hesabları` calls a row: a *bank hesabı* — the website's own
/// words, `Bank hesabı tapılmadı`.
const DatabaseListWords kBankAccountsListWords = DatabaseListWords(
  unit: 'hesab',
  checking: 'Bank hesabları yoxlanılır…',
  empty: 'Bank hesabı tapılmadı.',
  filteredEmpty: 'Filterə uyğun bank hesabı tapılmadı.',
);

/// `Bank Hesabları`: every account in the catalogue as a card, in the
/// bridge's order — by name — fetched a page at a time as the list nears
/// its end; or, while a filter is on, the accounts it lets through.
/// [DatabaseList] does the paging; this says what a card is, and that a
/// card opens.
class BankAccountsList extends StatelessWidget {
  const BankAccountsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final BankAccountsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final BankAccountsController accounts = controller;
    return DatabaseList<BankAccount>(
      source: accounts,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (BankAccount account) => account.id,
      words: kBankAccountsListWords,
      // `Kassalar`' card, `Kassalar`' 9pt between cards.
      gap: 9,
      card:
          (
            BuildContext context,
            DatabaseRows<BankAccount> rows,
            BankAccount row,
          ) {
            // Both of the page's lists — every account, and the ones a
            // filter lets through — are [BankAccountsRows], and each opens
            // its own cards.
            final BankAccountsRows list = rows as BankAccountsRows;
            return BankAccountCard(
              account: accounts.view(row),
              expanded: list.isExpanded(row.id),
              loading: accounts.isDetailLoading(row.id),
              error: accounts.detailError(row.id),
              onToggle: () => list.toggle(row),
              onRetry: () => accounts.loadDetail(row.id),
            );
          },
    );
  }
}
