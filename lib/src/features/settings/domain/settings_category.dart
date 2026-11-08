const String kSettingsIconDir = 'assets/images/icons/setting_icons/';

/// The headings `Tənzimləmələr` files its options under, in the order the
/// page stacks them. Only `Hesab` exists so far; the rest arrive as they are
/// designed, each one a row on the first level and a page of its own under
/// the title on the second.
enum SettingsCategory {
  account(title: 'Hesab', iconFile: 'account_icon.svg');

  const SettingsCategory({required this.title, required this._iconFile});

  final String title;
  final String _iconFile;

  String get icon => '$kSettingsIconDir$_iconFile';
}

/// `Çıxış edin`'s glyph. Red in the file too; it is painted in the label's
/// red so the two fade together.
const String kSettingsExitIcon = '${kSettingsIconDir}exit_icon.svg';
