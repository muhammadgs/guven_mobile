import 'dart:convert';

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
    this.assignedById,
    this.assignedTo,
    this.assignedToId,
    this.department,
    this.workTypeId,
    this.description,
    this.createdAt,
    this.dueDate,
    this.attachments = const <TaskAttachment>[],
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

  /// …and their user id, where the row carries one.
  ///
  /// Read for one reason: `Redaktə` is offered to the person who raised the
  /// task as well as to the person carrying it out ([isCreatedByMe]), and a
  /// name is not an identity — two people can share one.
  final int? assignedById;

  /// `İcra edən` — who is carrying it out.
  final String? assignedTo;
  final int? assignedToId;

  /// `Şöbə` — the department the work belongs to.
  ///
  /// Nothing on the card draws this. It is read because the filter has a
  /// `Şöbə` column, the same one the site's table filters on, and a column
  /// can only offer the values its rows actually carry.
  final String? department;

  /// The work type's own id, where the row carries one.
  ///
  /// The card draws [workType]'s name; this is what the edit sheet needs, so
  /// the `İşin növü` picker opens with the task's current answer ticked rather
  /// than with nothing selected.
  final int? workTypeId;

  final String? description;
  final DateTime? createdAt;
  final DateTime? dueDate;

  /// The task's files.
  ///
  /// Usually bare ids: the list endpoints name files through a `file_uuids`
  /// column and nothing else, so these arrive with no type and no name and are
  /// described later — see [needsFileDetails].
  final List<TaskAttachment> attachments;

  bool get hasAttachments => attachments.isNotEmpty;

  /// True while at least one file is still only an id.
  ///
  /// Describing them costs a request each, so it is done the first time a card
  /// is opened rather than while the list is being built.
  bool get needsFileDetails =>
      attachments.any((TaskAttachment file) => !file.resolved);

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

  /// Whether the signed-in user is the one who raised this task.
  ///
  /// Same two-step test as [isMine], for the same reason: `creator_name` is
  /// the only thing several list endpoints say about who created a task.
  bool isCreatedByMe({int? userId, String? fullName}) {
    if (assignedById != null && userId != null) return assignedById == userId;
    final String? mine = fullName?.trim().toLowerCase();
    final String? theirs = assignedBy?.trim().toLowerCase();
    if (mine == null || mine.isEmpty || theirs == null) return false;
    return mine == theirs;
  }

  /// Whether this task may be opened in `Redaktə`.
  ///
  /// Two people and no others: the one who raised it and the one carrying it
  /// out. Finished work is not editable — the three statuses the sheet's own
  /// `Status` field can set are the ends of the line, and a task that has
  /// reached one is a record rather than a plan.
  bool canEdit({int? userId, String? fullName}) =>
      id != null &&
      source.isActionable &&
      status.isOpen &&
      (isMine(userId: userId, fullName: fullName) ||
          isCreatedByMe(userId: userId, fullName: fullName));

  TaskItem copyWith({TaskStatus? status, List<TaskAttachment>? attachments}) {
    return TaskItem(
      id: id,
      source: source,
      company: company,
      workType: workType,
      status: status ?? this.status,
      assignedBy: assignedBy,
      assignedById: assignedById,
      assignedTo: assignedTo,
      assignedToId: assignedToId,
      department: department,
      workTypeId: workTypeId,
      description: description,
      createdAt: createdAt,
      dueDate: dueDate,
      attachments: attachments ?? this.attachments,
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
      assignedById: readInt(data, <String>[
        'created_by',
        'creator_id',
        'assigned_by',
        'created_by_id',
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
      department:
          readString(data, <String>['department_name', 'departmentName']) ??
          readString(asMap(data['department']), <String>[
            'name',
            'department_name',
          ]),
      workTypeId: readInt(data, <String>['work_type_id', 'worktype_id']),
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
    );
  }

  /// The files a task names.
  ///
  /// The website looks in two places in this order and so does this: an
  /// `attachments` array of real file objects — which some rows carry as a
  /// *JSON string* rather than a list — and, failing that, the `file_uuids`
  /// column, which is bare ids with no type or name attached. The second is
  /// the common case; those attachments start out unresolved and are described
  /// by `TaskFilesApi` when the card is first opened.
  static List<TaskAttachment> _attachments(Map<String, Object?> row) {
    for (final String key in <String>[
      'attachments',
      'files',
      'task_files',
      'attached_files',
    ]) {
      final Object? raw = row[key];
      final Object? value = raw is String ? _tryJson(raw) : raw;
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

    return <TaskAttachment>[
      for (final String id in parseFileUuids(
        row['file_uuids'] ?? row['file_uuid'] ?? row['file_ids'],
      ))
        TaskAttachment(id: id),
    ];
  }

  static Object? _tryJson(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }
}
