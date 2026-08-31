import 'dart:convert';
import 'dart:math' as math;

import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/new_task.dart';
import '../domain/task_item.dart';

/// Everything the `Yeni tapşırıq` sheet asks the backend for.
///
/// The payloads below are the website's own, read out of
/// `assets/js/task_js/ui_ux/new_task_design.js` and checked field by field
/// against the OpenAPI schemas, because the three create endpoints agree on
/// almost nothing:
///
/// * `TaskCreate.metadata` is a **string** and `TaskExternalCreate.metadata` is
///   an **object**. The site stringifies both, which the external endpoint
///   rejects; each gets the shape its own schema declares here.
/// * `TaskCreate` is the only one with a `file_uuids` field, so an internal
///   task carries its files in the create call and the other two have to be
///   updated afterwards ([attachFiles]).
/// * `PartnerTaskCreate` demands a product serial, a model, a task code and a
///   `forwarded_by` before it will accept anything at all — none of which this
///   form asks for, so they are filled in the way the site fills them.
class TaskCreateApi {
  const TaskCreateApi(this._client);

  final ApiClient _client;

  // ── The pickers ─────────────────────────────────────────────────────────

  /// `Sifarişçi şirkətlər` — the companies below us, which is what a **Daxili**
  /// task is created *for*.
  Future<List<TaskOption>> subCompanies(String companyCode) async {
    final Object? payload = await _client.get(
      '/companies/$companyCode/sub-companies',
      query: const <String, String>{'include_employees': 'false'},
    );
    return _options(
      asRows(payload, keys: <String>['sub_companies', 'companies']),
      TaskOption.company,
    );
  }

  /// `İcraçı şirkətlər` — the companies above us, which is who a **Şirkət**
  /// task is handed to. Empty is a legitimate answer: a company nobody is the
  /// customer of has no executors.
  Future<List<TaskOption>> parentCompanies(String companyCode) async {
    final Object? payload = await _client.get(
      '/companies/$companyCode/parent-companies',
    );
    return _options(
      asRows(payload, keys: <String>['parent_companies', 'companies']),
      TaskOption.company,
    );
  }

  Future<List<TaskOption>> partners(String companyCode) async {
    final Object? payload = await _client.get(
      '/partners/',
      query: <String, String>{'company_code': companyCode, 'per_page': '100'},
    );
    return _options(
      asRows(payload, keys: <String>['items', 'partners']),
      (Map<String, Object?> row) => TaskOption.partner(row, companyCode),
    );
  }

  Future<List<TaskOption>> employees(String companyCode) async {
    final Object? payload = await _client.get(
      '/users/company/$companyCode',
      query: const <String, String>{
        'include_inactive': 'false',
        'limit': '500',
      },
    );
    return _options(
      asRows(payload, keys: <String>['users', 'employees']),
      TaskOption.employee,
    );
  }

  Future<List<TaskOption>> departments(String companyCode) async {
    final Object? payload = await _client.get(
      '/departments/company-code/$companyCode',
      query: const <String, String>{'is_active': 'true'},
    );
    return _options(
      asRows(payload, keys: <String>['departments']),
      TaskOption.department,
    );
  }

  /// A company's work types.
  ///
  /// `/worktypes/company/{id}` is what the site asks for. When it answers with
  /// nothing — a company that has never defined any — the platform-wide list
  /// at `/tasks/work-types/` stands in, so the form is never unfillable for
  /// want of a work type nobody has created yet.
  Future<List<TaskOption>> workTypes(int companyId) async {
    List<TaskOption> options = const <TaskOption>[];
    try {
      final Object? payload = await _client.get(
        '/worktypes/company/$companyId',
        query: const <String, String>{'is_active': 'true'},
      );
      options = _options(
        asRows(payload, keys: <String>['work_types', 'worktypes']),
        TaskOption.workType,
      );
    } on ApiException {
      options = const <TaskOption>[];
    }
    if (options.isNotEmpty) return options;

    final Object? fallback = await _client.get('/tasks/work-types/');
    return _options(
      asRows(fallback, keys: <String>['work_types']),
      TaskOption.workType,
    );
  }

  // ── Creating ────────────────────────────────────────────────────────────

  /// Creates the task and returns its id.
  ///
  /// [fileUuids] is only read for [NewTaskKind.internal]; the other two
  /// resources have no field for it and are updated by [attachFiles] once they
  /// have an id.
  Future<int> create({
    required NewTaskKind kind,
    required TaskOption company,
    required int? assignedTo,
    required TaskOption? watcher,
    required TaskOption workType,
    required TaskOption department,
    required DateTime dueDate,
    required String description,
    required bool showToCompany,
    required List<String> fileUuids,
    required int? myCompanyId,
    required String? myCompanyName,
    required int? myUserId,
    required String? myName,
  }) async {
    final String due = _date(dueDate);
    final int targetCompanyId = company.realCompanyId;

    final Map<String, Object?> base = <String, Object?>{
      // The site titles a task with the company it is for; the card's headline
      // and the site's table both read the company name, and `task_title` is
      // only the fallback for a row that carries no work type.
      'task_title': company.name,
      'task_description': description,
      'assigned_to': assignedTo,
      'priority': 'medium',
      // Every task starts as a request: the executor sees `Təsdiq et` /
      // `İmtina et` and nothing runs until they answer.
      'status': 'pending_approval',
      'due_date': due,
      'progress_percentage': 0,
      'is_billable': false,
      'department_id': department.id,
      'work_type_id': workType.id,
      'created_by': myUserId,
      'creator_name': myName,
    };

    final Map<String, Object?> metadata = <String, Object?>{
      'display_company_name': company.name,
      'target_company_name': company.name,
      'original_company_name': company.name,
      'company_name': company.name,
      'company_id': targetCompanyId,
      'target_company_id': targetCompanyId,
      'created_by_company': myCompanyName,
      'created_by_company_id': myCompanyId,
      'created_by_user_id': myUserId,
      'created_by_name': myName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'task_type': kind.name,
      'due_date': due,
      // On an internal task `Digər şirkətin işçisi` is a *watcher* — somebody
      // at the customer company who should be able to follow the work — not
      // the person doing it. No create schema has a field for that, and the
      // website simply drops the answer; recording it here at least means the
      // form is not asking a question whose answer goes nowhere.
      if (watcher != null && watcher.id != assignedTo) ...<String, Object?>{
        'watcher_user_id': watcher.id,
        'watcher_name': watcher.name,
      },
    };

    final int stamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, Object?> body = switch (kind) {
      NewTaskKind.internal => <String, Object?>{
        ...base,
        // A string, per `TaskCreate.metadata`.
        'metadata': jsonEncode(<String, Object?>{
          ...metadata,
          'is_visible_to_company': showToCompany,
          'viewable_company_id': showToCompany ? targetCompanyId : null,
        }),
        'company_id': targetCompanyId,
        'target_company_id': targetCompanyId,
        'target_company_name': company.name,
        // The one switch `Seçilmiş şirkətə göstər` throws: whether the company
        // the work is for can see the task at all.
        'is_company_viewable': showToCompany,
        if (showToCompany) 'viewable_company_id': targetCompanyId,
        'file_uuids': fileUuids,
      },
      NewTaskKind.company => <String, Object?>{
        ...base,
        // An object, per `TaskExternalCreate.metadata`.
        'metadata': metadata,
        'company_id': myCompanyId,
        'target_company_id': targetCompanyId,
        'target_company_name': company.name,
        'viewable_company_id': targetCompanyId,
        'is_for_subsidiary': false,
      },
      // `PartnerTaskCreate` declares no metadata field, so it is left off
      // rather than sent to be dropped. Everything from `task_code` down is
      // required by the schema and asked for by no design; these are the
      // site's own stand-ins.
      NewTaskKind.partner => <String, Object?>{
        ...base,
        'company_id': myCompanyId,
        'partner_id': company.id,
        'partner_company_name': company.name,
        'partner_company_id': company.companyId,
        'target_company_id': targetCompanyId,
        'target_company_name': company.name,
        'viewable_company_id': targetCompanyId,
        'task_code': 'PT-$stamp-${math.Random().nextInt(1000)}',
        'product_serial': 'SN-$stamp',
        'product_model': 'Default Model',
        'product_category': 'General',
        'contract_number': 'CT-$stamp',
        'purchase_order_number': 'PO-$stamp',
        'forwarded_by': myUserId ?? assignedTo,
      },
    };

    body.removeWhere((String _, Object? value) => value == null);

    final Object? response = await _client.post(kind.endpoint, body: body);
    final int? id = _createdId(response);
    if (id == null) {
      throw const ApiException('Tapşırıq yaradıldı, amma nömrəsi qayıtmadı.');
    }
    return id;
  }

  /// Uploads one file and returns the uuid the server filed it under.
  ///
  /// `category` is what makes a microphone recording read as `Səs qeydi` in
  /// both clients rather than as an audio file somebody attached, which is why
  /// [PendingUpload.isVoiceNote] is carried this far.
  Future<String> upload(PendingUpload file) async {
    final Object? response = await _client.postMultipart(
      '/files/simple-upload',
      field: 'file',
      filename: file.name,
      bytes: file.bytes,
      contentType: file.mimeType,
      fields: <String, String>{
        'category': file.isVoiceNote ? 'audio_recording' : 'company_file',
        if (file.isVoiceNote) 'is_audio_recording': 'true',
      },
      timeout: const Duration(minutes: 3),
    );

    final Map<String, Object?> row = asMap(response);
    final String? uuid =
        readString(asMap(row['data']), <String>['uuid', 'file_id', 'id']) ??
        readString(row, <String>['uuid', 'file_id', 'id']);
    if (uuid == null) {
      throw ApiException('Fayl yükləndi, amma qeyd olunmadı: ${file.name}');
    }
    return uuid;
  }

  /// Points an already-created task at files uploaded beside it.
  ///
  /// Only needed for the two resources whose create schema has no `file_uuids`
  /// of its own. `tasks-external` takes a free-form update object;
  /// `partner-tasks` takes `PartnerTaskUpdate`, which requires `updated_by`.
  /// Both store the column as a PostgreSQL array literal, which is the shape
  /// the website writes and this app's [parseFileUuids] reads back.
  Future<void> attachFiles({
    required TaskSource source,
    required int taskId,
    required List<String> uuids,
    required int? myUserId,
  }) async {
    if (uuids.isEmpty) return;
    final String literal = '{${uuids.join(',')}}';

    switch (source) {
      case TaskSource.internal:
        await _client.post(
          '/tasks/$taskId/add-file-uuids',
          body: <String, Object?>{'file_uuids': uuids},
        );
      case TaskSource.external:
        await _client.patch(
          '/tasks-external/$taskId',
          body: <String, Object?>{'file_uuids': literal},
        );
      case TaskSource.partner:
        await _client.put(
          '/partner-tasks/$taskId',
          body: <String, Object?>{
            'updated_by': myUserId,
            'file_uuids': literal,
          },
        );
      case TaskSource.readOnly:
        return;
    }
  }

  // ── Plumbing ────────────────────────────────────────────────────────────

  /// Parses [rows] with [read], drops what it could not make sense of, and
  /// sorts by name — the order every one of these lists is drawn in.
  List<TaskOption> _options(
    List<Map<String, Object?>> rows,
    TaskOption? Function(Map<String, Object?>) read,
  ) {
    final List<TaskOption> options = <TaskOption>[];
    final Set<int> seen = <int>{};
    for (final Map<String, Object?> row in rows) {
      if (!isActiveRow(row)) continue;
      final TaskOption? option = read(row);
      if (option == null || !seen.add(option.id)) continue;
      options.add(option);
    }
    options.sort(
      (TaskOption a, TaskOption b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }

  /// The new task's id, out of whichever envelope it came back in.
  int? _createdId(Object? response) {
    final Map<String, Object?> row = asMap(response);
    return readInt(row, <String>['id', 'task_id', 'partner_task_id']) ??
        readInt(asMap(row['task']), <String>['id', 'task_id']) ??
        readInt(asMap(row['data']), <String>[
          'id',
          'task_id',
          'partner_task_id',
        ]);
  }

  static String _date(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }
}
