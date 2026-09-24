import 'package:flutter/painting.dart';

const String kDatabaseIconDir = 'assets/images/icons/database_main_panel/';

/// The ten figures on `Əsas panel`, in the order the design stacks them.
///
/// The same ten the website's 1C dashboard puts on its overview
/// (`one_c_dashboard.js`), read from the same places ([DatabaseOverview]), so
/// the phone and the site never disagree about a number.
///
/// Each one carries its own arc colour: the design runs them down the list as
/// one hue wheel, cyan at the top to red at the bottom, so the order here is
/// the order of the colours too.
enum DatabaseMetric {
  products(
    label: 'Cəmi Məhsul',
    iconFile: 'mehsullar.svg',
    iconSize: 28,
    arc: Color(0xFF00FFFF),
  ),
  customers(
    label: 'Cəmi Müştəri',
    iconFile: 'musteri.svg',
    iconSize: 22,
    arc: Color(0xFF00AAFF),
  ),
  orders(
    label: 'Cəmi Sifariş',
    iconFile: 'sifaris.svg',
    iconSize: 22,
    arc: Color(0xFF0055FF),
  ),
  salesDocuments(
    label: 'Satış Sənədi',
    iconFile: 'satis_senedi.svg',
    iconSize: 22,
    arc: Color(0xFF2F00FF),
  ),
  stockRecords(
    label: 'Stok Qeydi',
    iconFile: 'stok_qeydi.svg',
    iconSize: 22,
    arc: Color(0xFF7700FF),
  ),
  team(
    label: 'Komanda',
    iconFile: 'komanda.svg',
    iconSize: 23,
    arc: Color(0xFFB700FF),
  ),
  creditors(
    label: 'Kreditor',
    iconFile: 'Kreditor.svg',
    iconSize: 26,
    arc: Color(0xFFE500FF),
  ),
  debitors(
    label: 'Debitor',
    iconFile: 'Debitor.svg',
    iconSize: 26,
    arc: Color(0xFFFF00C3),
  ),
  salesAmount(
    label: 'Ümumi Satış Məbləği',
    iconFile: 'umumi_satis_meblegi.svg',
    iconSize: 26,
    arc: Color(0xFFFF006A),
    isMoney: true,
  ),
  debtLoad(
    label: 'Cari Borc Yükü',
    iconFile: 'cari_borc_yuku.svg',
    iconSize: 26,
    arc: Color(0xFFFF0004),
    isMoney: true,
  );

  const DatabaseMetric({
    required this.label,
    required this.iconFile,
    required this.iconSize,
    required this.arc,
    this.isMoney = false,
  });

  final String label;

  /// The glyph's file in [kDatabaseIconDir]. See [icon] for the asset path.
  final String iconFile;

  /// The glyph's side on the design's frame — each SVG's own frame, which is
  /// the size the design places it at. They differ (22 to 28), and drawing
  /// them all in one box would shrink the wide ones and blow up the narrow
  /// ones.
  final double iconSize;

  /// The arc on the row's left end.
  final Color arc;

  /// An amount in manat rather than a count of rows.
  final bool isMoney;

  String get icon => '$kDatabaseIconDir$iconFile';
}
