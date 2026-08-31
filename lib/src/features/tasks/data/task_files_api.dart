import 'dart:io';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/task_attachment.dart';

/// How a file ended up on screen, or why it did not open.
enum FileOpenResult {
  opened,

  /// The phone has nothing installed that handles this type.
  noHandler,

  /// The download failed, or the file is gone.
  failed,

  /// The app binary on the device predates the file-opening plugin. Only a
  /// reinstall fixes it, so it is worth saying so rather than reporting a
  /// generic failure.
  notInstalled,
}

/// Reads and opens a task's attachments.
///
/// Three things here are the backend's doing rather than choices:
///
/// 1. **There is no metadata endpoint.** Both file routes answer with the file
///    itself, so a file's type, name and size are read from the *headers* —
///    `Content-Type`, `Content-Disposition`, `Content-Length`. The website
///    does exactly this and says why in `fileUpload.js`.
///
/// 2. **Which of the two routes works keeps swapping.** As of 2026-08-31
///    `GET /files/{id}/download` answers 500 for every id, out of its own SQL
///    and before any lookup, while the inline `GET /files/{id}` is healthy —
///    it was the other way round a fortnight earlier. So both are tried, in
///    both directions: the inline route leads for metadata, the download route
///    leads for the bytes (it is the one that sets a filename), and each falls
///    through to the other. Without that fallback nothing opens at all.
///
/// 3. **The download endpoint takes the token as a query parameter**, because
///    the site opens it in a new tab and a tab cannot set a header. The
///    `Authorization` header is sent as well — belt and braces, since both are
///    accepted and only one of them survives a redirect.
class TaskFilesApi {
  TaskFilesApi(this._client);

  final ApiClient _client;

  /// Metadata, keyed by file id, for the life of the session.
  ///
  /// The same file appears on the same card every time the list refreshes, and
  /// probing it again on each pass would be a request per file per refresh.
  final Map<String, TaskAttachment> _described = <String, TaskAttachment>{};

  /// Files already pulled down this session: id to the path they were written
  /// to. A second tap opens the copy that is already there.
  final Map<String, String> _downloaded = <String, String>{};

  /// A download may be a real file over a phone connection, so it is given
  /// considerably longer than a dashboard call.
  static const Duration _downloadTimeout = Duration(minutes: 3);

  /// Fills in what [files] are, in one pass.
  ///
  /// Files that already know their own type — the few endpoints that embed
  /// real file objects — are passed straight through. Anything that cannot be
  /// described is returned as it came rather than dropped: a file whose type
  /// is unknown still opens, and the phone works out what to do with it.
  Future<List<TaskAttachment>> describe(List<TaskAttachment> files) async {
    return Future.wait(
      files.map((TaskAttachment file) async {
        if (file.resolved) return file;
        final TaskAttachment? cached = _described[file.id];
        if (cached != null) return cached;

        final TaskAttachment described = await _describeOne(file);
        _described[file.id] = described;
        return described;
      }),
    );
  }

  Future<TaskAttachment> _describeOne(TaskAttachment file) async {
    final _FileHeaders? headers = await _probe(file.id);
    if (headers == null) return file;

    return file.describedAs(
      name: headers.filename,
      kind: AttachmentKind.resolve(
        mimeType: headers.mimeType,
        filename: headers.filename,
      ),
      mimeType: headers.mimeType,
      sizeBytes: headers.sizeBytes,
    );
  }

  /// Asks the backend what a file is without fetching it.
  ///
  /// Both endpoints answer with the file itself, so what is read is the
  /// *headers*: `Content-Type`, `Content-Disposition`, `Content-Length`. The
  /// inline one is tried first because the download one has been answering 500
  /// for every id since 2026-08-31 — `column "id" does not exist`, out of its
  /// own SQL, before any lookup — while `/files/{id}` answers cleanly.
  /// [guven-file-endpoints] has the whole story; the order here is the one
  /// thing that has to change back if that query is ever fixed and the inline
  /// route turns out to be the narrower of the two.
  Future<_FileHeaders?> _probe(String id) async {
    for (final String path in <String>[_inlinePath(id), _downloadPath(id)]) {
      final http.Response? response = await _peek(path);
      if (response != null) return _FileHeaders.from(response.headers);
    }
    return null;
  }

  /// One endpoint's headers, without pulling the body down.
  ///
  /// `HEAD` first, so nothing is transferred at all; deployments that answer
  /// `405 allow: GET` to it — this one does — get a one-byte `Range` request
  /// instead.
  Future<http.Response?> _peek(String path) async {
    for (final Map<String, String> attempt in <Map<String, String>>[
      const <String, String>{},
      const <String, String>{'Range': 'bytes=0-0'},
    ]) {
      try {
        final http.Response response = await _client.rawRequest(
          attempt.isEmpty ? 'HEAD' : 'GET',
          path,
          query: _tokenQuery(),
          headers: attempt.isEmpty ? null : attempt,
        );
        // 206 is the Range request having been honoured; both count.
        if (response.statusCode < 400) return response;
      } on ApiException {
        // Try the next shape, then the next endpoint.
      }
    }
    return null;
  }

  /// Downloads [file] if it is not already here, then hands it to the phone.
  ///
  /// The bytes go to the app's cache directory under the file's own name, so
  /// whatever opens it shows the name the sender gave it rather than a uuid.
  Future<FileOpenResult> open(TaskAttachment file) async {
    try {
      final String path = await _localCopy(file);
      // The type is passed outright rather than left to be sniffed from the
      // path: the plugin falls back to the extension, and a file the server
      // named with no extension would otherwise be offered to nobody.
      final OpenResult result = await OpenFilex.open(
        path,
        type: file.mimeType,
      );
      return switch (result.type) {
        ResultType.done => FileOpenResult.opened,
        ResultType.noAppToOpen => FileOpenResult.noHandler,
        _ => FileOpenResult.failed,
      };
    } on ApiException {
      return FileOpenResult.failed;
    } on FileSystemException {
      return FileOpenResult.failed;
    } on MissingPluginException {
      // The plugin's native half is not in the running binary — the app was
      // installed before it was added, and a hot restart cannot add it.
      return FileOpenResult.notInstalled;
    }
  }

  /// Downloads [file] if it is not already here and answers with the path it
  /// was written to.
  ///
  /// Public because a voice note is *played* rather than handed to the phone:
  /// the card's own player needs the file on disk, and it needs it under the
  /// same one-download-per-session rule everything else here follows.
  Future<String> localPath(TaskAttachment file) => _localCopy(file);

  Future<String> _localCopy(TaskAttachment file) async {
    final String? existing = _downloaded[file.id];
    if (existing != null && File(existing).existsSync()) return existing;

    // The download endpoint first — it is the one that sets a filename — and
    // the inline one behind it, which is what actually answers while
    // `/download` is returning 500 for every id ([guven-file-endpoints]).
    // Without this second attempt no attachment can be opened at all, and a
    // voice note cannot be played.
    http.Response? response;
    for (final String path in <String>[
      _downloadPath(file.id),
      _inlinePath(file.id),
    ]) {
      final http.Response attempt = await _client.rawRequest(
        'GET',
        path,
        query: _tokenQuery(),
        timeout: _downloadTimeout,
      );
      if (attempt.statusCode < 400 && attempt.bodyBytes.isNotEmpty) {
        response = attempt;
        break;
      }
    }
    if (response == null) throw const ApiException('Fayl yüklənmədi.');

    // A name the server gave beats the one the list row carried, and a plain
    // id beats both when neither is usable. Whatever wins, it is given an
    // extension if it has none — that is what an app-chooser matches on.
    final TaskAttachment described = file.describedAs(
      name: _FileHeaders.from(response.headers).filename,
      kind: file.kind,
    );
    final String? extension = described.suggestedExtension;
    final String name =
        _safeName(described.filename, file.id) +
        (extension == null ? '' : '.$extension');

    final Directory cache = await getTemporaryDirectory();
    final Directory folder = Directory('${cache.path}/task_files/${file.id}');
    await folder.create(recursive: true);
    final File target = File('${folder.path}/$name');
    await target.writeAsBytes(response.bodyBytes);

    _downloaded[file.id] = target.path;
    return target.path;
  }

  String _downloadPath(String id) => '/files/$id/download';

  /// The same file, served inline. Not a metadata endpoint — it answers with
  /// the bytes too — but it is the one that works.
  String _inlinePath(String id) => '/files/$id';

  /// The access token, as the query parameter the download endpoint expects.
  Map<String, String> _tokenQuery() {
    final String? token = _client.tokens.accessToken;
    return token == null ? const <String, String>{} : <String, String>{
      'token': token,
    };
  }

  /// Strips anything a filesystem would object to, and keeps the extension —
  /// which on Android is what decides who is offered the file.
  static String _safeName(String name, String id) {
    final String cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return id;
    // Long names are truncated from the front, so the extension survives.
    if (cleaned.length <= 120) return cleaned;
    final int dot = cleaned.lastIndexOf('.');
    if (dot <= 0 || cleaned.length - dot > 12) return cleaned.substring(0, 120);
    return cleaned.substring(0, 120 - (cleaned.length - dot)) +
        cleaned.substring(dot);
  }
}

/// What the download endpoint's headers said the file is.
class _FileHeaders {
  const _FileHeaders({this.mimeType, this.filename, this.sizeBytes});

  final String? mimeType;
  final String? filename;
  final int? sizeBytes;

  factory _FileHeaders.from(Map<String, String> headers) {
    final String mime = (headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();

    return _FileHeaders(
      // `octet-stream` is the server declining to say, which is worse than
      // nothing here — it would out-vote the extension.
      mimeType: mime.isEmpty || mime == 'application/octet-stream' ? null : mime,
      filename: _filenameFrom(headers['content-disposition'] ?? ''),
      sizeBytes: int.tryParse(headers['content-length'] ?? ''),
    );
  }

  /// Reads `Content-Disposition`, preferring the RFC 5987 `filename*` form —
  /// which is the only one that survives Azerbaijani letters in a filename.
  static String? _filenameFrom(String disposition) {
    if (disposition.isEmpty) return null;

    final RegExpMatch? encoded = RegExp(
      r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (encoded != null) {
      final String raw = encoded.group(1)!.replaceAll(RegExp('["\']'), '').trim();
      try {
        return Uri.decodeComponent(raw);
      } on ArgumentError {
        return raw;
      }
    }

    final RegExpMatch? plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    final String? name = plain?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }
}
