import 'package:flutter/material.dart';

import '../../../core/json.dart';

/// The file families the cards draw a distinct badge for.
///
/// Matched against the same set the backend's `FileCategory` enum knows —
/// `document_pdf`, `document_word`, `document_excel`, `image`, `archive` — and
/// then against the extension, because not every row carries a category.
enum AttachmentKind {
  pdf,
  word,
  excel,
  slides,
  image,
  archive,
  audio,
  video,
  other;

  IconData get icon => switch (this) {
    AttachmentKind.pdf => Icons.picture_as_pdf_rounded,
    AttachmentKind.word => Icons.article_rounded,
    AttachmentKind.excel => Icons.table_chart_rounded,
    AttachmentKind.slides => Icons.slideshow_rounded,
    AttachmentKind.image => Icons.image_rounded,
    AttachmentKind.archive => Icons.folder_zip_rounded,
    AttachmentKind.audio => Icons.audiotrack_rounded,
    AttachmentKind.video => Icons.movie_rounded,
    AttachmentKind.other => Icons.insert_drive_file_rounded,
  };

  /// The badge colour. Each family wears the colour its own desktop app does,
  /// so the type is readable before the label is.
  Color get color => switch (this) {
    AttachmentKind.pdf => const Color(0xFFE8412F),
    AttachmentKind.word => const Color(0xFF2B579A),
    AttachmentKind.excel => const Color(0xFF1D7145),
    AttachmentKind.slides => const Color(0xFFD24726),
    AttachmentKind.image => const Color(0xFF7A5AF8),
    AttachmentKind.archive => const Color(0xFFD08700),
    AttachmentKind.audio => const Color(0xFF00A3A3),
    AttachmentKind.video => const Color(0xFF9B2FAE),
    AttachmentKind.other => const Color(0xFF5A6472),
  };

  /// What the chip is called when the file itself has no usable name.
  String get genericLabel => switch (this) {
    AttachmentKind.pdf => 'PDF faylı',
    AttachmentKind.word => 'Word faylı',
    AttachmentKind.excel => 'Excel faylı',
    AttachmentKind.slides => 'Təqdimat',
    AttachmentKind.image => 'Şəkil',
    AttachmentKind.archive => 'Arxiv',
    AttachmentKind.audio => 'Səs faylı',
    AttachmentKind.video => 'Video',
    AttachmentKind.other => 'Fayl',
  };

  /// Reads the family out of whatever the row happens to carry: the backend's
  /// own category first, then the extension, then the MIME type.
  static AttachmentKind resolve({
    String? category,
    String? extension,
    String? mimeType,
  }) {
    switch ((category ?? '').toLowerCase()) {
      case 'document_pdf':
        return AttachmentKind.pdf;
      case 'document_word':
        return AttachmentKind.word;
      case 'document_excel':
        return AttachmentKind.excel;
      case 'image' || 'project_image' || 'company_logo' || 'partner_logo':
        return AttachmentKind.image;
      case 'archive':
        return AttachmentKind.archive;
      case 'audio':
        return AttachmentKind.audio;
      case 'company_video' || 'project_video':
        return AttachmentKind.video;
    }

    final String ext = (extension ?? '').toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf':
        return AttachmentKind.pdf;
      case 'doc' || 'docx' || 'rtf' || 'odt':
        return AttachmentKind.word;
      case 'xls' || 'xlsx' || 'csv' || 'ods':
        return AttachmentKind.excel;
      case 'ppt' || 'pptx' || 'odp':
        return AttachmentKind.slides;
      case 'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' || 'svg':
        return AttachmentKind.image;
      case 'zip' || 'rar' || '7z' || 'tar' || 'gz':
        return AttachmentKind.archive;
      case 'mp3' || 'wav' || 'm4a' || 'aac' || 'ogg':
        return AttachmentKind.audio;
      case 'mp4' || 'mov' || 'avi' || 'mkv' || 'webm':
        return AttachmentKind.video;
    }

    final String mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return AttachmentKind.image;
    if (mime.startsWith('audio/')) return AttachmentKind.audio;
    if (mime.startsWith('video/')) return AttachmentKind.video;
    if (mime.contains('pdf')) return AttachmentKind.pdf;
    if (mime.contains('word')) return AttachmentKind.word;
    if (mime.contains('sheet') || mime.contains('excel')) {
      return AttachmentKind.excel;
    }
    if (mime.contains('presentation')) return AttachmentKind.slides;
    if (mime.contains('zip') || mime.contains('compressed')) {
      return AttachmentKind.archive;
    }
    return AttachmentKind.other;
  }
}

/// One file hanging off a task.
@immutable
class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.name,
    required this.kind,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final AttachmentKind kind;
  final int? sizeBytes;

  /// Reads a `FileResponse`, or any of the thinner shapes the task endpoints
  /// embed instead of one.
  static TaskAttachment? fromRow(Map<String, Object?> row) {
    final String? id = readString(row, <String>[
      'id',
      'file_id',
      'file_uuid',
      'uuid',
    ]);
    if (id == null) return null;

    final String? name = readString(row, <String>[
      'original_filename',
      'filename',
      'file_name',
      'name',
      'title',
    ]);
    final AttachmentKind kind = AttachmentKind.resolve(
      category: readString(row, <String>['category', 'file_category']),
      extension:
          readString(row, <String>['file_extension', 'extension']) ??
          _extensionOf(name),
      mimeType: readString(row, <String>['mime_type', 'content_type']),
    );

    return TaskAttachment(
      id: id,
      name: name ?? kind.genericLabel,
      kind: kind,
      sizeBytes: readInt(row, <String>['file_size', 'size', 'size_bytes']),
    );
  }

  static String? _extensionOf(String? filename) {
    if (filename == null) return null;
    final int dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return null;
    return filename.substring(dot + 1);
  }

  /// `2.4 MB`, or null when the row never said.
  String? get readableSize {
    final int? bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
