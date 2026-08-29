import 'package:flutter/material.dart';

import '../../../core/json.dart';

/// The file families a task's attachments are shown as.
///
/// Ported one for one from the website's `FileUploadManager.fileTypes` and
/// `detectFileTypeKey`, labels and priority included, so a file that reads
/// `EXCEL faylı` in the task table reads `EXCEL faylı` on the phone. The order
/// of the checks is that function's: an explicit voice-recording flag first,
/// then the MIME type, then the extension.
enum AttachmentKind {
  /// A microphone recording made in the task manager. Distinct from [music]
  /// on purpose — the site calls one `Səs qeydi` and the other `Audio faylı`.
  voiceNote('Səs qeydi', Icons.mic_rounded, Color(0xFF3B82F6)),

  music('Audio faylı', Icons.music_note_rounded, Color(0xFF8B5CF6)),
  image('Şəkil', Icons.image_rounded, Color(0xFF3B82F6)),
  video('Video', Icons.videocam_rounded, Color(0xFFEF4444)),
  pdf('PDF faylı', Icons.picture_as_pdf_rounded, Color(0xFFEF4444)),
  word('WORD faylı', Icons.description_rounded, Color(0xFF2563EB)),
  excel('EXCEL faylı', Icons.table_chart_rounded, Color(0xFF10B981)),
  powerpoint('PPT faylı', Icons.slideshow_rounded, Color(0xFFF97316)),
  other('Fayl', Icons.insert_drive_file_rounded, Color(0xFF64748B));

  const AttachmentKind(this.label, this.icon, this.color);

  /// What the chip says — the type, not the filename, exactly as the design
  /// draws it and as the site's own chips do.
  final String label;

  final IconData icon;
  final Color color;

  static const Map<AttachmentKind, List<String>> _extensions =
      <AttachmentKind, List<String>>{
        AttachmentKind.music: <String>[
          'mp3', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'flac', 'wma', 'opus',
          'weba',
        ],
        AttachmentKind.image: <String>[
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico', 'tif',
          'tiff', 'heic', 'heif', 'avif',
        ],
        AttachmentKind.video: <String>[
          'mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv', 'm4v', 'mpg',
          'mpeg', '3gp',
        ],
        AttachmentKind.pdf: <String>['pdf'],
        AttachmentKind.word: <String>[
          'doc', 'docx', 'docm', 'dot', 'dotx', 'odt', 'rtf',
        ],
        AttachmentKind.excel: <String>[
          'xls', 'xlsx', 'xlsm', 'xlsb', 'csv', 'ods',
        ],
        AttachmentKind.powerpoint: <String>[
          'ppt', 'pptx', 'pptm', 'pps', 'ppsx', 'pot', 'potx', 'odp',
        ],
      };

  static AttachmentKind resolve({
    String? mimeType,
    String? filename,
    bool isVoiceNote = false,
  }) {
    final String mime = (mimeType ?? '')
        .toLowerCase()
        .split(';')
        .first
        .trim();
    final String name = (filename ?? '').toLowerCase();

    // 1. An explicit recording marker wins outright — a microphone recording
    //    is always `Səs qeydi`, whatever it was encoded as.
    if (isVoiceNote ||
        name.contains('səs-qeydi') ||
        name.contains('ses-qeydi') ||
        name.contains('recording')) {
      return AttachmentKind.voiceNote;
    }

    // 2. The MIME type, when the server sent a real one. `octet-stream` is the
    //    server saying it does not know, so it is skipped rather than trusted.
    if (mime.isNotEmpty && mime != 'application/octet-stream') {
      if (mime.startsWith('audio/')) return AttachmentKind.music;
      if (mime.startsWith('image/')) return AttachmentKind.image;
      if (mime.startsWith('video/')) return AttachmentKind.video;
      if (mime.contains('pdf')) return AttachmentKind.pdf;
      if (mime == 'application/msword' ||
          mime.contains('wordprocessingml') ||
          mime.contains('ms-word') ||
          mime == 'application/rtf') {
        return AttachmentKind.word;
      }
      if (mime.contains('ms-excel') ||
          mime.contains('spreadsheetml') ||
          mime == 'text/csv' ||
          mime.contains('spreadsheet')) {
        return AttachmentKind.excel;
      }
      if (mime.contains('ms-powerpoint') ||
          mime.contains('presentationml') ||
          mime.contains('presentation')) {
        return AttachmentKind.powerpoint;
      }
    }

    // 3. The extension, ignoring any query or fragment on the name.
    final RegExpMatch? match = RegExp(
      r'\.([a-z0-9]+)$',
    ).firstMatch(name.split(RegExp(r'[?#]')).first);
    if (match != null) {
      final String extension = match.group(1)!;
      for (final MapEntry<AttachmentKind, List<String>> entry
          in _extensions.entries) {
        if (entry.value.contains(extension)) return entry.key;
      }
    }

    return AttachmentKind.other;
  }
}

/// One file hanging off a task.
///
/// A task row names its files as bare uuids, so an attachment starts life
/// knowing nothing but its id — [kind] is [AttachmentKind.other] and [name] is
/// null until the metadata lands. See `TaskFilesApi.describe`.
@immutable
class TaskAttachment {
  const TaskAttachment({
    required this.id,
    this.name,
    this.kind = AttachmentKind.other,
    this.mimeType,
    this.sizeBytes,
    this.resolved = false,
  });

  final String id;

  /// The original filename, once it is known.
  final String? name;

  final AttachmentKind kind;

  /// The server's own `Content-Type`, when it gave a real one.
  ///
  /// Kept beside [kind] rather than folded into it because the two are for
  /// different jobs: [kind] picks the chip's icon and label, this is handed to
  /// the phone so it knows what it is being asked to open. Passing it is what
  /// lets a file with no extension in its name still open.
  final String? mimeType;

  final int? sizeBytes;

  /// Whether [kind] and [name] came from the server rather than being the
  /// standing-in defaults.
  final bool resolved;

  /// What the chip is labelled: the type, per the design.
  String get label => kind.label;

  /// The full name, for the tooltip and for the file written to disk.
  String get filename => name ?? 'fayl-${id.substring(0, id.length.clamp(0, 8))}';

  TaskAttachment describedAs({
    String? name,
    required AttachmentKind kind,
    String? mimeType,
    int? sizeBytes,
  }) {
    return TaskAttachment(
      id: id,
      name: name ?? this.name,
      kind: kind,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      resolved: true,
    );
  }

  /// A file extension for [filename] when it has none of its own.
  ///
  /// Android decides who is offered a file by its extension unless it is told
  /// a type outright, and a name that came back as a bare uuid has neither. It
  /// is worked out from the MIME type first and the resolved [kind] second.
  String? get suggestedExtension {
    final String name = filename.toLowerCase();
    if (RegExp(r'\.[a-z0-9]{1,8}$').hasMatch(name)) return null;

    return switch ((mimeType ?? '').toLowerCase()) {
      'application/pdf' => 'pdf',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      'audio/mpeg' => 'mp3',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/mp4' || 'audio/x-m4a' => 'm4a',
      'audio/webm' => 'weba',
      'audio/ogg' => 'ogg',
      'video/mp4' => 'mp4',
      'video/quicktime' => 'mov',
      'text/csv' => 'csv',
      'text/plain' => 'txt',
      'application/msword' => 'doc',
      'application/vnd.ms-excel' => 'xls',
      'application/vnd.ms-powerpoint' => 'ppt',
      'application/zip' => 'zip',
      final String mime when mime.contains('wordprocessingml') => 'docx',
      final String mime when mime.contains('spreadsheetml') => 'xlsx',
      final String mime when mime.contains('presentationml') => 'pptx',
      _ => switch (kind) {
        AttachmentKind.pdf => 'pdf',
        AttachmentKind.word => 'docx',
        AttachmentKind.excel => 'xlsx',
        AttachmentKind.powerpoint => 'pptx',
        AttachmentKind.image => 'jpg',
        AttachmentKind.video => 'mp4',
        AttachmentKind.voiceNote || AttachmentKind.music => 'mp3',
        AttachmentKind.other => null,
      },
    };
  }

  /// Reads an embedded file object — a `FileResponse`, or one of the thinner
  /// shapes the task endpoints sometimes carry instead.
  static TaskAttachment? fromRow(Map<String, Object?> row) {
    final String? id = readString(row, <String>[
      'file_id',
      'uuid',
      'file_uuid',
      'id',
    ]);
    if (id == null) return null;

    final String? name = readString(row, <String>[
      'original_filename',
      'filename',
      'file_name',
      'name',
    ]);
    final String? mime = readString(row, <String>['mime_type', 'content_type']);
    final String? category = readString(row, <String>[
      'category',
      'file_category',
    ]);

    return TaskAttachment(
      id: id,
      name: name,
      kind: AttachmentKind.resolve(
        mimeType: mime,
        filename: name,
        isVoiceNote:
            category == 'audio_recording' || row['is_audio_recording'] == true,
      ),
      mimeType: mime,
      sizeBytes: readInt(row, <String>['file_size', 'size', 'size_bytes']),
      // Only a row that actually said something counts as described; one that
      // carried nothing but an id still needs the server asked.
      resolved: name != null || mime != null,
    );
  }

  /// `2.4 MB`, or null when nothing has said how big it is.
  String? get readableSize {
    final int? bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Pulls file uuids out of whatever shape `file_uuids` arrived in.
///
/// PostgreSQL hands its `uuid[]` column straight through as a literal —
/// `{"a1b2…","c3d4…"}` — and the backend passes that string on unparsed on
/// some endpoints and as a real JSON array on others. The website copes with
/// exactly this in three separate places; this is the same rule, once.
///
/// Anything that is not 36 characters with hyphens in it is dropped, which is
/// what keeps a stray `NULL` or an empty `{}` out of the list.
List<String> parseFileUuids(Object? value) {
  final List<String> raw = <String>[];
  if (value is String) {
    final String cleaned = value
        .replaceFirst(RegExp(r'^\{'), '')
        .replaceFirst(RegExp(r'\}$'), '')
        .trim();
    if (cleaned.isNotEmpty) raw.addAll(cleaned.split(','));
  } else if (value is List) {
    for (final Object? entry in value) {
      if (entry is String) raw.add(entry);
    }
  }

  final List<String> uuids = <String>[];
  for (final String entry in raw) {
    final String uuid = entry.trim().replaceAll('"', '').replaceAll("'", '');
    if (uuid.length == 36 && uuid.contains('-')) uuids.add(uuid);
  }
  return uuids;
}
