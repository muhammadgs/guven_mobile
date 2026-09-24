/// The headings of the `Detallar` menu.
///
/// The website's 1C dashboard files its sidebar under exactly these, in this
/// order; the phone keeps them so that somebody who knows one knows the other.
enum DatabaseGroup {
  operations('Əməliyyatlar'),
  information('Məlumat'),
  finance('Maliyyə'),
  reports('Hesabatlar'),
  catalogues('Kataloqlar');

  const DatabaseGroup(this.title);

  final String title;

  /// The pages filed under this heading, in menu order.
  List<DatabaseSection> get sections => <DatabaseSection>[
    for (final DatabaseSection section in DatabaseSection.values)
      if (section.group == this) section,
  ];
}

/// Every page the `Baza` tab can show.
///
/// [overview] is `Əsas panel` and sits in the menu on its own; everything
/// else is reached through its [group]. The title is also what the page says
/// under `Baza`, so it is written the way the menu writes it.
enum DatabaseSection {
  overview('Əsas panel', null),
  sales('Satışlar', DatabaseGroup.operations),
  stock('Stok', DatabaseGroup.operations),
  orders('Sifarişlər', DatabaseGroup.operations),
  products('Məhsullar', DatabaseGroup.information),
  customers('Müştərilər', DatabaseGroup.information),
  team('Komanda', DatabaseGroup.information),
  creditors('Kreditorlar', DatabaseGroup.finance),
  debitors('Debitorlar', DatabaseGroup.finance),
  managerDebts('Menecer Borcları', DatabaseGroup.finance),
  debtAllocation('Borc Bölgüsü', DatabaseGroup.finance),
  managerStats('Menecer Statistikası', DatabaseGroup.reports),
  bankAccounts('Bank Hesabları', DatabaseGroup.catalogues),
  cashDesks('Kassalar', DatabaseGroup.catalogues),
  warehouses('Anbarlar', DatabaseGroup.catalogues),
  unitsOfMeasure('Ölçü Vahidləri', DatabaseGroup.catalogues);

  const DatabaseSection(this.title, this.group);

  final String title;

  /// The heading it is filed under, or null for `Əsas panel`.
  final DatabaseGroup? group;
}
