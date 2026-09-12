import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Folders under the app's temporary directory that hold a signed-in user's
/// company data: downloaded task attachments, and voice notes recorded for a
/// task that has not been sent yet.
///
/// Named here, rather than in the features that write them, so that signing
/// out can empty them without the auth layer reaching into the tasks one.
const String kTaskFilesFolder = 'task_files';
const String kVoiceNotesFolder = 'voice_notes';

/// Deletes everything the signed-in user left on the device.
///
/// The OS only clears a cache under storage pressure, so without this a
/// contract opened on Monday would still be sitting on the phone after the
/// user signed out — and the next account to sign in on it would share the
/// same directory. Best-effort: a folder that cannot be removed is not worth
/// failing a sign-out over.
Future<void> wipeUserFiles() async {
  try {
    final Directory cache = await getTemporaryDirectory();
    for (final String name in <String>[kTaskFilesFolder, kVoiceNotesFolder]) {
      final Directory folder = Directory('${cache.path}/$name');
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  } catch (_) {
    // No platform directory (a widget test), or a file still held open.
  }
}
