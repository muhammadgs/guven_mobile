import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/shell_destination.dart';

/// Where the user's arrangement of page buttons is kept between launches.
abstract interface class NavLayoutStore {
  /// The saved layout, or null when there is none or it cannot be read.
  Future<ShellNavLayout?> load();

  Future<void> save(ShellNavLayout layout);
}

/// A small JSON file in the app's support directory.
///
/// A file rather than the keystore: nothing here is secret, and
/// `flutter_secure_storage` is the token's. `path_provider` is already a
/// dependency, so this adds no native plugin and needs no reinstall.
class FileNavLayoutStore implements NavLayoutStore {
  static const String _fileName = 'nav_layout.json';

  Future<File> _file() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<ShellNavLayout?> load() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return null;
      return ShellNavLayout.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      // A layout that cannot be read is a layout that falls back to the
      // default, never a shell that fails to open.
      return null;
    }
  }

  @override
  Future<void> save(ShellNavLayout layout) async {
    try {
      final File file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(layout.toJson()), flush: true);
    } catch (_) {
      // Losing an arrangement is not worth an error the user can do nothing
      // about; the next change tries again.
    }
  }
}

/// Keeps the layout in memory only — for tests.
class MemoryNavLayoutStore implements NavLayoutStore {
  MemoryNavLayoutStore([this.saved]);

  ShellNavLayout? saved;

  @override
  Future<ShellNavLayout?> load() async => saved;

  @override
  Future<void> save(ShellNavLayout layout) async => saved = layout;
}
