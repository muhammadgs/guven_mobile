import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/task_edit.dart';
import '../domain/task_item.dart';

/// Everything `Redaktə` asks the backend for.
///
/// Three resources, one per kind of task, each addressed at its own prefix
/// ([_base]) — they are separate tables and their ids do not mean the same
/// thing. Two of them, `/tasks/{id}` and `/tasks-external/{id}`, take a
/// free-form PATCH; the partner one is a typed PUT that also demands
/// `updated_by` ([TaskEditCapabilities.hasFreeFormUpdate]).
///
/// The write is a **partial** one on purpose: only what the user actually
/// changed is sent. Posting the whole form back would overwrite columns this
/// sheet does not draw with the values it happened to read a minute earlier,
/// and two people editing one task would each undo the other.
class TaskEditApi {
  const TaskEditApi(this._client);

  final ApiClient _client;

  /// The task's own row, for the three answers no list endpoint carries:
  /// `notes`, `work_type_id` and `is_company_viewable`.
  Future<TaskEditSnapshot> load(TaskItem task) async {
    final Object? payload = await _client.get(_base(task));
    return TaskEditSnapshot.fromRow(asMap(payload));
  }

  /// Writes the changed fields.
  ///
  /// Every argument is nullable and null means *untouched*, which is why the
  /// note and the description are passed as `String?` rather than as empty
  /// strings: clearing a note and never opening it are different intentions,
  /// and only the first should reach the column.
  Future<void> save({
    required TaskItem task,
    required int? myUserId,
    int? assignedTo,
    int? workTypeId,
    String? description,
    String? note,
    DateTime? dueDate,
    bool? showToCompany,
    int? viewableCompanyId,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'assigned_to': ?assignedTo,
      'task_description': ?description,
      task.source.noteField: ?note,
      if (dueDate != null) 'due_date': _date(dueDate),
      if (workTypeId != null && task.source.canEditWorkType)
        'work_type_id': workTypeId,
      if (showToCompany != null &&
          task.source.canEditVisibility) ...<String, Object?>{
        'is_company_viewable': showToCompany,
        // Explicitly null rather than omitted: turning the switch off has to
        // clear the company that could see it, or the flag and the id
        // disagree and the site reads the id.
        'viewable_company_id': showToCompany ? viewableCompanyId : null,
      },
    };
    if (body.isEmpty) return;

    if (task.source.hasFreeFormUpdate) {
      await _client.patch(_base(task), body: body);
      return;
    }
    // `PartnerTaskUpdate` refuses anything without it.
    await _client.put(
      _base(task),
      body: <String, Object?>{'updated_by': myUserId, ...body},
    );
  }

  /// Brings the task to one of the three ends the sheet offers.
  ///
  /// Written straight into the row rather than through the backend's dedicated
  /// verbs, because those verbs do not work. `PUT /tasks/{id}/complete` answers
  /// with `Task tamamlanmadı: type object 'TaskArchiveService' has no attribute
  /// 'update_task'` — it tries to archive the task itself through a method that
  /// is not there any more — and `PUT /tasks/{id}/reject` sits on the same
  /// untravelled path. The website has never called either one: every button on
  /// it that finishes a task writes `status` through the ordinary update
  /// endpoint, and posts to `/task-archive/archive` separately when it wants the
  /// row archived. This does the first of those two, which is the one the app's
  /// own screens read.
  Future<void> setStatus({
    required TaskItem task,
    required TaskEditStatus status,
    required int? myUserId,
  }) async {
    final String base = _base(task);
    final bool done = status == TaskEditStatus.complete;

    if (task.source.hasFreeFormUpdate) {
      await _client.patch(
        base,
        body: <String, Object?>{
          'status': status.raw,
          if (done) ...<String, Object?>{
            'completed_date': _date(DateTime.now()),
            'progress_percentage': 100,
          },
        },
      );
      return;
    }

    // `PartnerTaskUpdate` refuses anything without `updated_by`, and declares
    // no `completed_date` — a partner task records its completion in the
    // progress alone.
    await _client.put(
      base,
      body: <String, Object?>{
        'updated_by': myUserId,
        'status': status.raw,
        if (done) 'progress_percentage': 100,
      },
    );
  }

  /// Files a finished task's copy under `Arxiv`.
  ///
  /// The backend does not do this for us — `PUT /tasks/{id}/complete` was meant
  /// to and is broken, see [setStatus] — so it is done the way the website does
  /// it, as a second call right after the status one: read the task back, copy
  /// it into the archive's own shape, post it. It is not a nicety. `Arxiv` is
  /// read from `/task-archive/…` and never from the tasks table, so a task
  /// nobody filed is a task that finished and then vanished.
  ///
  /// Answers false rather than throwing when the copy could not be written: by
  /// the time this runs the task is already completed, and calling the whole
  /// save failed would be wrong about the half that worked.
  Future<bool> archive({required TaskItem task, required int? myUserId}) async {
    try {
      final Map<String, Object?> row = asMap(await _client.get(_base(task)));
      final Map<String, Object?> body = _archiveBody(task, row, myUserId);
      // The archive is keyed by company and the site will not post without
      // one: a copy filed under no company is one no screen finds again.
      if (body['company_id'] == null) return false;
      await _client.post(task.source.archivePath, body: body);
      await _retire(task, myUserId);
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Takes a finished partner task out of the live list, once its copy is
  /// safely filed.
  ///
  /// Only partner tasks. A finished *task* leaves the screens on its own —
  /// every list that draws one asks for open statuses — but the partner table
  /// draws every row it is given, status and all, so the site takes the
  /// finished one out itself. It does that by deleting the row outright; this
  /// deactivates it, which reads the same everywhere and can be undone.
  ///
  /// A failure here is swallowed on purpose: the archive copy already exists,
  /// and the worst of it is a finished row still sitting in the site's table.
  Future<void> _retire(TaskItem task, int? myUserId) async {
    if (task.source != TaskSource.partner) return;
    try {
      await _client.put(
        _base(task),
        body: <String, Object?>{'updated_by': myUserId, 'is_active': false},
      );
    } on ApiException {
      return;
    }
  }

  /// The finished task in the shape `/task-archive/…` stores.
  ///
  /// Built from the task's own row rather than from the card, because the
  /// archive keeps a dozen columns no list row carries — the task's code, its
  /// priority, its hours, who raised it. Whatever the row cannot answer is left
  /// out rather than sent as null: this is an insert, and a null would write
  /// over a default the backend would otherwise fill in itself.
  static Map<String, Object?> _archiveBody(
    TaskItem task,
    Map<String, Object?> row,
    int? myUserId,
  ) {
    // Some of these endpoints answer `{task: {…}}` and some answer the task
    // itself, resolved exactly as `TaskEditSnapshot.fromRow` resolves it.
    final Map<String, Object?> data = row['task'] is Map
        ? <String, Object?>{...asMap(row['task']), ...row}
        : row;

    final int? createdBy = readInt(data, <String>['created_by', 'creator_id']);
    final Map<String, Object?> body = <String, Object?>{
      'original_task_id': task.id,
      'task_code':
          readString(data, <String>['task_code']) ??
          '${task.source.archivePrefix}-${task.id}',
      'task_title':
          readString(data, <String>['task_title', 'title']) ??
          'Task ${task.id}',
      'task_description': readString(data, <String>[
        'task_description',
        'description',
      ]),
      'assigned_to': readInt(data, <String>['assigned_to', 'assignee_id']),
      // A task with no executor was still handed over by whoever raised it,
      // which is the fallback the site uses here too.
      'assigned_by': readInt(data, <String>['assigned_by']) ?? createdBy,
      'created_by': createdBy,
      'creator_name': readString(data, <String>[
        'creator_name',
        'created_by_name',
      ]),
      'company_id': readInt(data, <String>['company_id']),
      'company_name': readString(data, <String>['company_name']),
      'target_company_id': readInt(data, <String>[
        'target_company_id',
        'partner_company_id',
        'viewable_company_id',
      ]),
      'target_company_name': readString(data, <String>[
        'target_company_name',
        'partner_company_name',
        'viewable_company_name',
      ]),
      'department_id': readInt(data, <String>['department_id']),
      'work_type_id': readInt(data, <String>['work_type_id']),
      'priority': readString(data, <String>['priority']) ?? 'medium',
      'status': TaskEditStatus.complete.raw,
      'progress_percentage': 100,
      'due_date': readString(data, <String>['due_date']),
      'started_date': readString(data, <String>['started_date']),
      'completed_date':
          readString(data, <String>['completed_date']) ?? _date(DateTime.now()),
      'notes': readString(data, <String>[task.source.noteField, 'notes']),
      'archived_by': myUserId,
      'updated_by': myUserId,
      'archive_reason': task.source.archiveReason,
      // Which of the archive's three lists this copy belongs in.
      'task_source': task.source.archiveSource,
      if (task.source == TaskSource.partner) 'is_partner_task': true,
      // Two `text[]` columns: this backend takes them as PostgreSQL array
      // literals, not as JSON arrays.
      'tags': _literal(data['tags']),
      'file_uuids': _literal(data['file_uuids']),
    };

    // The hours and the timer's own columns are copied across untouched. The
    // archive is where the cost of the work is read back from afterwards, and
    // recomputing somebody's logged time on the way in would be a quiet lie
    // about it.
    for (final String key in _carriedToArchive) {
      final Object? value = data[key];
      if (value != null) body[key] = value;
    }

    body.removeWhere((String _, Object? value) => value == null);
    return body;
  }

  /// Columns the archive copy takes from the task row exactly as it finds
  /// them.
  static const List<String> _carriedToArchive = <String>[
    'estimated_hours',
    'actual_hours',
    'is_billable',
    'billing_rate',
    'total_elapsed_seconds',
    'total_paused_seconds',
    'manual_added_seconds',
    'manual_added_hours',
    'manual_time_history',
    'created_at',
  ];

  /// A `text[]` column the way this backend writes it — `{"a","b"}` — or null
  /// when there is nothing in it. A value that is already a literal is passed
  /// straight through.
  static String? _literal(Object? value) {
    if (value is String) {
      final String text = value.trim();
      return text.isEmpty || text == '{}' ? null : text;
    }
    if (value is! List) return null;
    final List<String> items = <String>[
      for (final Object? item in value)
        if ('$item'.trim().isNotEmpty) '"${'$item'.trim()}"',
    ];
    return items.isEmpty ? null : '{${items.join(',')}}';
  }

  /// This task's own row: `/tasks/{id}`, `/tasks-external/{id}` or
  /// `/partner-tasks/{id}`.
  ///
  /// Off [TaskSource.pathPrefix] and never guessed. The three are separate
  /// tables with **separate id sequences** — `POST /tasks-external/sync/{id}`
  /// exists precisely to copy a row from one into the other — so addressing a
  /// cross-company task at `/tasks/{id}` would not fail, it would quietly read
  /// and rewrite whichever internal task happens to hold that number.
  String _base(TaskItem task) {
    final int? id = task.id;
    if (id == null || !task.source.isActionable) {
      throw const ApiException('Bu tapşırıq redaktə oluna bilməz.');
    }
    return '${task.source.pathPrefix}/$id';
  }

  static String _date(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }
}
