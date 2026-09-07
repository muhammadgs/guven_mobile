import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'task_item.dart';
import 'task_scope.dart';

/// The three kinds of task this app can create, and what each one means.
///
/// They are not three shapes of the same form. The backend keeps them in three
/// parallel resources, and — the part that is easy to get backwards — the
/// company each one asks for is a *different relationship*:
///
/// * [internal] — our own task. The company picked is one of our **sub**
///   companies (`sifarişçi` — the customer the work is for), or ourselves.
///   `Digər şirkətin işçisi` is only there so somebody on the customer's side
///   can watch the task; the work is still ours, and `İcra edən` is one of our
///   own people.
/// * [company] — a task we hand **up** to one of our parent companies
///   (`icraçı` — our executor). There is no `İcra edən` of our own: the
///   executor is a person at that company. A company with no parents can
///   create none of these, which is why that picker can legitimately come back
///   empty.
/// * [partner] — the same shape again, aimed at a partner company.
///
/// Only [internal] carries `Seçilmiş şirkətə göstər`. On the other two the
/// question does not arise — the company the task is addressed to has to see
/// it, or it could not carry it out. The website draws that checkbox on its
/// company form anyway; that is a slip, not a specification.
enum NewTaskKind {
  internal(
    label: 'Daxili',
    icon: 'assets/images/icons/task_list_selection_icons/daxili.svg',
    iconScale: 0.92,
    endpoint: '/tasks/',
    source: TaskSource.internal,
    scope: TaskScope.internal,
    companyLabel: 'Şirkət',
    otherWorkerLabel: 'Digər şirkətin işçisi',
    hasOwnExecutor: true,
    hasVisibilityToggle: true,
  ),
  company(
    label: 'Şirkət',
    icon: 'assets/images/icons/task_list_selection_icons/sirket.svg',
    endpoint: '/tasks-external/',
    source: TaskSource.external,
    scope: TaskScope.company,
    companyLabel: 'Şirkət',
    otherWorkerLabel: 'Digər şirkətin işçisi',
    hasOwnExecutor: false,
    hasVisibilityToggle: false,
  ),
  partner(
    label: 'Partniyor',
    icon: 'assets/images/icons/task_list_selection_icons/partniyor.svg',
    iconScale: 1.32,
    endpoint: '/partner-tasks/',
    source: TaskSource.partner,
    scope: TaskScope.partner,
    companyLabel: 'Partniyor',
    otherWorkerLabel: 'Partniyor şirkətin işçisi',
    hasOwnExecutor: false,
    hasVisibilityToggle: false,
  );

  const NewTaskKind({
    required this.label,
    required this.icon,
    this.iconScale = 1,
    required this.endpoint,
    required this.source,
    required this.scope,
    required this.companyLabel,
    required this.otherWorkerLabel,
    required this.hasOwnExecutor,
    required this.hasVisibilityToggle,
  });

  /// What the chooser calls it.
  final String label;

  /// The chooser's glyph — the same three the scope bar wears, so the menu row
  /// and the cell the new task lands in are visibly the same thing.
  final String icon;

  /// How big that glyph is drawn *relative to the other two* in the chooser.
  ///
  /// The three SVGs are not drawn to one optical size: the partner handshake
  /// is wide and low, so in a shared box it reads smaller than the rest, and
  /// the internal checklist is dense enough to read larger. This nudges each
  /// back onto the same apparent weight. It corrects the artwork, not the
  /// layout — the menu's icon size itself is `NewTaskMetrics.labelSize`.
  final double iconScale;

  /// The widest of the three, which is what the chooser's icon gutter is
  /// sized to.
  static final double maxIconScale = values
      .map((NewTaskKind kind) => kind.iconScale)
      .reduce(math.max);

  final String endpoint;
  final TaskSource source;

  /// Which cell of the scope bar a task of this kind appears in once created.
  final TaskScope scope;

  final String companyLabel;
  final String otherWorkerLabel;

  /// Whether the form asks for one of *our* people to carry it out.
  final bool hasOwnExecutor;

  final bool hasVisibilityToggle;

  /// What the sheet is titled while this kind is being filled in.
  String get sheetTitle => switch (this) {
    NewTaskKind.internal => 'Yeni tapşırıq',
    NewTaskKind.company => 'Şirkət tapşırığı',
    NewTaskKind.partner => 'Partniyor tapşırığı',
  };
}

/// The fields the form asks a list for.
///
/// A field is a row on the sheet and a panel that grows out of it, so its
/// label, its glyph and its wording live here rather than being repeated at
/// each of those places.
enum NewTaskField {
  company('assets/images/icons/new_task_icons/sirket.svg'),
  executor('assets/images/icons/new_task_icons/icra_eden.svg'),
  otherWorker('assets/images/icons/new_task_icons/diger_sirketin_iscisi.svg'),
  workType('assets/images/icons/new_task_icons/isin_novu.svg'),
  department('assets/images/icons/new_task_icons/sobe.svg');

  const NewTaskField(this.icon);

  final String icon;

  String labelFor(NewTaskKind kind) => switch (this) {
    NewTaskField.company => kind.companyLabel,
    NewTaskField.executor => 'İcra edən',
    NewTaskField.otherWorker => kind.otherWorkerLabel,
    NewTaskField.workType => 'İşin növü',
    NewTaskField.department => 'Şöbə',
  };

  /// What the row says while nothing has been chosen.
  String hintFor(NewTaskKind kind) => switch (this) {
    NewTaskField.company => '${kind.companyLabel} seçin',
    NewTaskField.executor => 'İşçi seçin',
    NewTaskField.otherWorker => 'İşçi seçin (boş qoymaq olar)',
    NewTaskField.workType => 'İş növü seçin',
    NewTaskField.department => 'Şöbə seçin',
  };

  /// What an empty list says, which is never the same as "not chosen yet".
  String get emptyMessage => switch (this) {
    NewTaskField.company => 'Şirkət tapılmadı',
    NewTaskField.executor || NewTaskField.otherWorker => 'İşçi tapılmadı',
    NewTaskField.workType => 'İş növü tapılmadı',
    NewTaskField.department => 'Şöbə tapılmadı',
  };
}

/// One row of a picker: something with an id and a name.
///
/// Companies, employees, work types and departments all reduce to this. The
/// two extra fields are only ever filled in for companies: [code] is what the
/// employee and department endpoints are keyed by, and [companyId] is the
/// company behind a *partner relationship* — `id` on a partner row is the
/// relationship, not the company, and sending one where the other is meant is
/// the easiest mistake to make against this backend.
@immutable
class TaskOption {
  const TaskOption({
    required this.id,
    required this.name,
    this.code,
    this.companyId,
    this.isMine = false,
  });

  final int id;
  final String name;
  final String? code;
  final int? companyId;

  /// True for the signed-in user's own company in the [NewTaskKind.internal]
  /// company list — the entry that starts selected.
  final bool isMine;

  /// The company this option really points at: the relationship's target for a
  /// partner, and itself for everything else.
  int get realCompanyId => companyId ?? id;

  @override
  bool operator ==(Object other) =>
      other is TaskOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  /// An employee row: `/users/company/{code}`.
  ///
  /// The name is read by [readPersonName], which knows both spellings the
  /// endpoint mixes — an employee's `first_name`/`last_name` and an owner's
  /// `ceo_name`/`ceo_lastname`. A row that names nobody keeps its email
  /// address as the label, because a picker cannot offer several people all
  /// called `Ad yoxdur`; a row with neither is dropped.
  static TaskOption? employee(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'user_id']);
    final String? name =
        readPersonName(row) ?? readString(row, <String>['email', 'ceo_email']);
    if (id == null || name == null) return null;
    return TaskOption(id: id, name: name);
  }

  /// A work type: `/worktypes/company/{id}`.
  static TaskOption? workType(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'work_type_id']);
    final String? name = readString(row, <String>[
      'work_type_name',
      'name',
      'title',
      'label',
    ]);
    if (id == null || name == null) return null;
    return TaskOption(id: id, name: name);
  }

  /// A department: `/departments/company-code/{code}`.
  static TaskOption? department(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'department_id']);
    final String? name = readString(row, <String>['department_name', 'name']);
    if (id == null || name == null) return null;
    return TaskOption(id: id, name: name);
  }

  /// A company from `sub-companies` or `parent-companies`.
  static TaskOption? company(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['company_id', 'id']);
    final String? name = readString(row, <String>['company_name', 'name']);
    if (id == null || name == null) return null;
    return TaskOption(
      id: id,
      name: name,
      code: readString(row, <String>['company_code', 'code']),
    );
  }

  /// A partner relationship from `/partners/?company_code={code}`.
  ///
  /// The row names both sides; which one is "the partner" depends on which
  /// side we are, so [myCode] decides. [id] stays the *relationship* id,
  /// because that is what `PartnerTaskCreate.partner_id` wants.
  static TaskOption? partner(Map<String, Object?> row, String? myCode) {
    final int? id = readInt(row, <String>['id', 'partner_id']);
    if (id == null) return null;

    final String? requesterCode = readString(row, <String>[
      'requester_company_code',
    ]);
    final bool weAsked = myCode != null && requesterCode == myCode;

    final String? name = weAsked
        ? readString(row, <String>[
            'partner_company_name',
            'target_company_name',
          ])
        : readString(row, <String>[
            'partner_company_name',
            'requester_company_name',
          ]);
    final String? code = weAsked
        ? readString(row, <String>['target_company_code'])
        : requesterCode;

    return TaskOption(
      id: id,
      name: name ?? (code == null ? 'Partniyor $id' : 'Şirkət $code'),
      code: code,
      companyId: readInt(row, <String>[
        if (weAsked) 'target_company_id',
        'partner_company_id',
        'company_id',
      ]),
    );
  }
}

/// A file waiting to be uploaded with the task.
@immutable
class PendingUpload {
  const PendingUpload({
    required this.name,
    required this.bytes,
    this.mimeType,
    this.isVoiceNote = false,
    this.duration,
  });

  final String name;
  final List<int> bytes;
  final String? mimeType;

  /// Marks the microphone recording, which the backend files under its own
  /// `audio_recording` category so it reads as `Səs qeydi` rather than as some
  /// music somebody attached.
  final bool isVoiceNote;

  /// How long the recording runs. Null for an ordinary file.
  final Duration? duration;

  int get sizeBytes => bytes.length;
}

/// A `Content-Type` for a file about to be uploaded, worked out from its name.
///
/// The server stores whatever we declare and hands it back as the file's type
/// later, so getting this right is what makes an attachment come back as
/// `PDF faylı` instead of `Fayl`. Null — which becomes
/// `application/octet-stream` — is the honest answer for anything unrecognised,
/// and both clients fall back to the extension in the name anyway.
String? mimeTypeForName(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'svg' => 'image/svg+xml',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' || 'aac' => 'audio/mp4',
    'ogg' || 'oga' || 'opus' => 'audio/ogg',
    'weba' => 'audio/webm',
    'flac' => 'audio/flac',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'rtf' => 'application/rtf',
    'odt' => 'application/vnd.oasis.opendocument.text',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'csv' => 'text/csv',
    'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'odp' => 'application/vnd.oasis.opendocument.presentation',
    'txt' => 'text/plain',
    'json' => 'application/json',
    'xml' => 'application/xml',
    'zip' => 'application/zip',
    'rar' => 'application/vnd.rar',
    '7z' => 'application/x-7z-compressed',
    _ => null,
  };
}
