import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'task_attachment.dart';
import 'task_status.dart';

/// Which table a task came out of, and therefore which endpoints act on it.
///
/// The backend keeps internal, cross-company and partner tasks in three
/// parallel resources with the same verbs — `/tasks/{id}/start`,
/// `/tasks-external/{id}/start`, `/partner-tasks/{id}/start` — so a card
/// carries its origin and the API layer picks the prefix from it.
enum TaskSource {
  internal('/tasks'),
  external('/tasks-external'),
  partner('/partner-tasks'),

  /// Archived and report rows are read-only here: nothing to start, pause or
  /// approve, so they carry no verb prefix.
  readOnly('');

  const TaskSource(this.pathPrefix);

  final String pathPrefix;

  bool get isActionable => pathPrefix.isNotEmpty;
}

/// One task, as a card needs it.
@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.source,
    required this.company,
    required this.workType,
    required this.status,
    this.assignedBy,
    this.assignedTo,
    this.assignedToId,
    this.description,
    this.createdAt,
    this.dueDate,
    this.attachments = const <TaskAttachment>[],
    this.attachmentIds = const <String>[],
  });

  final int? id;
  final TaskSource source;

  /// The card's headline — the company the work belongs to, not the task's own
  /// title. That is what the design shows and what the site's table leads
  /// with.
  final String company;

  /// The second line: `İş növü` on the site.
  final String workType;

  final TaskStatus status;

  /// `Kim tərəfindən` — who handed the task over.
  final String? assignedBy;

  /// `İcra edən` — who is carrying it out.
  final String? assignedTo;
  final int? assignedToId;

  final String? description;
  final DateTime? createdAt;
  final DateTime? dueDate;

  /// Files already embedded in the list payload.
  final List<TaskAttachment> attachments;

  /// File uuids the row named without expanding. Fetched one by one the first
  /// time a card is opened, so a list of forty tasks costs no file requests.
  final List<String> attachmentIds;

  bool get hasAttachments =>
      attachments.isNotEmpty || attachmentIds.isNotEmpty;

  /// Whether the signed-in user is the one carrying this out.
  ///
  /// By id when both sides have one; by name otherwise, because several list
  /// endpoints return `assigned_to_name` and no id at all.
  bool isMine({int? userId, String? fullName}) {
    if (assignedToId != null && userId != null) return assignedToId == userId;
    final String? mine = fullName?.trim().toLowerCase();
    final String? theirs = assignedTo?.trim().toLowerCase();
    if (mine == null || mine.isEmpty || theirs == null) return false;
    return mine == theirs;
  }

  TaskItem copyWith({
    TaskStatus? status,
    List<TaskAttachment>? attachments,
  }) {
    return TaskItem(
      id: id,
      source: source,
      company: company,
      workType: workType,
      status: status ?? this.status,
      assignedBy: assignedBy,
      assignedTo: assignedTo,
      assignedToId: assignedToId,
      description: description,
      createdAt: createdAt,
      dueDate: dueDate,
      attachments: attachments ?? this.attachments,
      attachmentIds: attachmentIds,
    );
  }

  /// Reads whatever shape the endpoint answered with.
  ///
  /// Five endpoints feed this screen and none of them agree on field names;
  /// every lookup below is a list of the spellings seen across the API schema
  /// and the website's own task table.
  factory TaskItem.fromRow(Map<String, Object?> row, TaskSource source) {
    final Map<String, Object?> data = row['task'] is Map
        ? <String, Object?>{...asMap(row['task']), ...row}
        : row;

    return TaskItem(
      id: readInt(data, <String>[
        'id',
        'task_id',
        'partner_task_id',
        'original_task_id',
      ]),
      source: source,
      company:
          readString(data, <String>[
            'company_name',
            'source_company_name',
            'partner_company_name',
            'target_company_name',
            'companyName',
          ]) ??
          '—',
      workType:
          readString(data, <String>[
            'work_type_name',
            'work_type',
            'workTypeName',
            'task_title',
            'title',
          ]) ??
          '—',
      status: TaskStatus.fromRaw(
        readString(data, <String>['status', 'task_status']),
      ),
      assignedBy: readString(data, <String>[
        'assigned_by_name',
        'creator_name',
        'created_by_name',
        'assigner_name',
      ]),
      assignedTo: readString(data, <String>[
        'assigned_to_name',
        'assignee_name',
        'executor_name',
        'partner_name',
      ]),
      assignedToId: readInt(data, <String>[
        'assigned_to',
        'assignee_id',
        'executor_id',
      ]),
      description: readString(data, <String>[
        'task_description',
        'description',
        'details',
      ]),
      createdAt: readDate(data, <String>[
        'created_at',
        'createdAt',
        'assigned_date',
        'created_date',
        'archived_at',
      ]),
      dueDate: readDate(data, <String>['due_date', 'deadline', 'dueDate']),
      attachments: _attachments(data),
      attachmentIds: _attachmentIds(data),
    );
  }

  static List<TaskAttachment> _attachments(Map<String, Object?> row) {
    for (final String key in <String>[
      'files',
      'attachments',
      'task_files',
      'attached_files',
      'documents',
    ]) {
      final Object? value = row[key];
      if (value is! List) continue;
      final List<TaskAttachment> parsed = <TaskAttachment>[];
      for (final Object? entry in value) {
        if (entry is! Map) continue;
        final TaskAttachment? file = TaskAttachment.fromRow(
          entry.cast<String, Object?>(),
        );
        if (file != null) parsed.add(file);
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return const <TaskAttachment>[];
  }

  /// Bare uuids, for the rows that reference files without embedding them.
  static List<String> _attachmentIds(Map<String, Object?> row) {
    final List<String> ids = <String>[];
    for (final String key in <String>[
      'file_uuids',
      'file_ids',
      'files',
      'attachments',
      'file_uuid',
    ]) {
      final Object? value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        ids.add(value.trim());
      } else if (value is List) {
        for (final Object? entry in value) {
          if (entry is String && entry.trim().isNotEmpty) ids.add(entry.trim());
        }
      }
      if (ids.isNotEmpty) return ids;
    }
    return const <String>[];
  }
}
