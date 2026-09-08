/// What `Redaktə` is made of: the two lists it offers, the three ends it can
/// bring a task to, and which of the sheet's rows a given task can actually
/// carry.
///
/// The last of those is not cosmetic. The three task resources are updated
/// through three different schemas, and one of them —
/// `PartnerTaskUpdate` — declares no work type and no visibility flag at all.
/// A field sent to a schema that does not declare it is *dropped in silence*:
/// the request succeeds, the sheet closes, and nothing changed. So a row the
/// backend cannot store is a row this sheet does not draw.
library;

import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'task_item.dart';
import 'task_status.dart';

/// The icons the edit sheet wears that the `Yeni tapşırıq` sheet does not.
///
/// Everything else on this form — `İcra edən`, `İşin növü`, the description,
/// the deadline, `Seçilmiş şirkətə göstər` — is drawn with the very glyph the
/// new-task sheet uses, so the two forms read as one family.
const String kTaskEditNoteIcon =
    'assets/images/icons/edit_icons_different_ones/qeyd.svg';
const String kTaskEditStatusIcon =
    'assets/images/icons/edit_icons_different_ones/status.svg';

/// The fields on the edit sheet that open a list.
///
/// Two, not the new-task sheet's five. A task's company, its department and
/// the other company's watcher are what the task *is*; changing them would be
/// a different task, and the design draws neither. What can be changed is who
/// carries it out and what kind of work it is.
enum TaskEditField {
  executor(
    icon: 'assets/images/icons/new_task_icons/icra_eden.svg',
    label: 'İcra edən',
    hint: 'İşçi seçin',
    emptyMessage: 'İşçi tapılmadı',
  ),
  workType(
    icon: 'assets/images/icons/new_task_icons/isin_novu.svg',
    label: 'İşin növü',
    hint: 'İş növü seçin',
    emptyMessage: 'İş növü tapılmadı',
  );

  const TaskEditField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.emptyMessage,
  });

  final String icon;
  final String label;

  /// What the row says while nothing has been chosen.
  final String hint;

  /// What an empty list says, which is never the same as "not chosen yet".
  final String emptyMessage;
}

/// The three answers the sheet's `Status` field offers.
///
/// All three are ends of the line, which is why the field opens with nothing
/// selected rather than with the task's current state ticked: it is not a
/// display of where the task is, it is the question "should this stop here?".
/// Leaving it alone leaves the status exactly as it was.
enum TaskEditStatus {
  /// The work is done.
  complete('Tamamla', TaskStatus.completed),

  /// The work is refused — the task was not taken on.
  reject('İmtina et', TaskStatus.rejected),

  /// The work is called off — it was taken on and is no longer wanted.
  cancel('Ləğv et', TaskStatus.cancelled);

  const TaskEditStatus(this.label, this.status);

  /// What the row says.
  final String label;

  /// The state the task is in once this has been applied. The card shows it
  /// the moment the sheet closes, before the list has been fetched again.
  final TaskStatus status;

  /// What the backend calls it. The three names are spelled the same in
  /// `TaskStatus` and `PartnerTaskStatus`, so one mapping covers both.
  String get raw => switch (this) {
    TaskEditStatus.complete => 'completed',
    TaskEditStatus.reject => 'rejected',
    TaskEditStatus.cancel => 'cancelled',
  };
}

/// Which rows a task of this source can carry — see the note at the top of
/// this file for why a row that cannot be stored is not drawn.
extension TaskEditCapabilities on TaskSource {
  /// Whether this resource's update endpoint takes a free-form object.
  ///
  /// `PATCH /tasks/{id}` and `PATCH /tasks-external/{id}` both declare their
  /// body as a bare `Update Data` dict and store whatever column the key names.
  /// `PUT /partner-tasks/{id}` is the odd one out: it is typed as
  /// `PartnerTaskUpdate`, it refuses a body with no `updated_by`, and it drops
  /// every field that schema does not declare **without saying so**.
  ///
  /// Internal and cross-company tasks are still two different *tables* — see
  /// `TaskEditApi._base`, which addresses each at its own path.
  bool get hasFreeFormUpdate =>
      this == TaskSource.internal || this == TaskSource.external;

  /// `İşin növü`. `PartnerTaskUpdate` has no `work_type_id`;
  /// `TaskExternalCreate` and `TaskCreate` both do.
  bool get canEditWorkType => hasFreeFormUpdate;

  /// `Seçilmiş şirkətə göstər`. `PartnerTaskUpdate` has no
  /// `is_company_viewable` either — and on a partner task the question does
  /// not arise anyway: the company the work was handed to has to see it, or it
  /// could not carry it out.
  bool get canEditVisibility => hasFreeFormUpdate;

  /// Where a finished task's archive copy is posted.
  ///
  /// Three endpoints, one per kind, because `Arxiv` keeps three lists and the
  /// screens read them separately — `/task-archive/`, `…/external`,
  /// `…/partners`. The site's three edit modals each post to their own; this
  /// is that same mapping, in one place.
  String get archivePath => switch (this) {
    TaskSource.partner => '/task-archive/archive-partner',
    TaskSource.external => '/task-archive/archive-external',
    _ => '/task-archive/archive',
  };

  /// What the archive's own `task_source` column calls this kind of task.
  ///
  /// Spelled the way the site spells it, transliteration and all: these three
  /// words are what its archive screens badge and filter on, and a fourth
  /// spelling would file the row where nothing looks for it.
  String get archiveSource => switch (this) {
    TaskSource.partner => 'partnyor',
    TaskSource.external => 'sifarishci',
    _ => 'daxili',
  };

  /// The prefix of the code an archived task is given when its own row never
  /// carried one. `task_code` is a required archive column.
  String get archivePrefix => switch (this) {
    TaskSource.partner => 'PT',
    TaskSource.external => 'EXT',
    _ => 'TASK',
  };

  /// The line the archive stores as `archive_reason`, in the site's wording —
  /// it is shown as-is in the archived task's details.
  String get archiveReason => switch (this) {
    TaskSource.partner => 'Partner task tamamlandığı üçün arxivləndi',
    TaskSource.external => 'External task tamamlandı',
    _ => 'Tamamlandığı üçün arxivləndi',
  };

  /// Which column the sheet's `Qeyd` is written to. All three resources have
  /// one; they simply do not agree on its name — the site's own external edit
  /// modal PATCHes plain `notes` at `/tasks-external/{id}` too.
  String get noteField =>
      this == TaskSource.partner ? 'partner_notes' : 'notes';
}

/// The task as the edit sheet needs it, read back from the single-task
/// endpoint.
///
/// The card is built from a *list* row, and the list rows carry none of
/// `notes`, `work_type_id` or `is_company_viewable` — three of the seven
/// things this sheet asks about. So opening `Redaktə` fetches the task itself
/// once, and the form is seeded from whichever of the two knows each answer.
@immutable
class TaskEditSnapshot {
  const TaskEditSnapshot({
    this.assignedToId,
    this.assignedToName,
    this.workTypeId,
    this.workTypeName,
    this.description,
    this.note,
    this.dueDate,
    this.showToCompany,
  });

  final int? assignedToId;
  final String? assignedToName;
  final int? workTypeId;
  final String? workTypeName;
  final String? description;
  final String? note;
  final DateTime? dueDate;
  final bool? showToCompany;

  factory TaskEditSnapshot.fromRow(Map<String, Object?> row) {
    // Some of these endpoints answer `{task: {…}}` and some answer the task
    // itself; the outer keys win where both carry one, exactly as
    // `TaskItem.fromRow` resolves it.
    final Map<String, Object?> data = row['task'] is Map
        ? <String, Object?>{...asMap(row['task']), ...row}
        : row;

    return TaskEditSnapshot(
      assignedToId: readInt(data, <String>[
        'assigned_to',
        'assignee_id',
        'executor_id',
      ]),
      assignedToName: readString(data, <String>[
        'assigned_to_name',
        'assignee_name',
        'executor_name',
      ]),
      workTypeId: readInt(data, <String>['work_type_id', 'worktype_id']),
      workTypeName: readString(data, <String>['work_type_name', 'work_type']),
      description: readString(data, <String>[
        'task_description',
        'description',
      ]),
      note: readString(data, <String>['notes', 'partner_notes', 'note']),
      dueDate: readDate(data, <String>['due_date', 'deadline']),
      showToCompany: readBool(data, <String>[
        'is_company_viewable',
        'is_visible_to_company',
      ]),
    );
  }
}
