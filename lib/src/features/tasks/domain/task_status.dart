import 'package:flutter/widgets.dart';

/// Every state a task can be in, across all four task tables the backend
/// keeps.
///
/// `TaskStatus` and `PartnerTaskStatus` in the API are two overlapping enums —
/// partner tasks add `assigned`, `on_hold` and `in_review`, internal ones add
/// `approval_overdue`. One enum here covers both, so the card does not care
/// which endpoint a row came from.
enum TaskStatus {
  /// Somebody has been asked to take this on and has not yet said yes.
  pendingApproval,

  /// Nobody answered the request in time.
  approvalOverdue,

  waiting,
  pending,
  assigned,
  inProgress,
  paused,
  onHold,
  inReview,
  completed,
  overdue,
  cancelled,
  rejected,
  archived,

  /// A status string this app has never seen. Shown as a chip with the raw
  /// text rather than hidden, so a new backend state is visible rather than
  /// silently missing.
  unknown;

  static TaskStatus fromRaw(String? raw) {
    final String value = (raw ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return switch (value) {
      'pending_approval' => TaskStatus.pendingApproval,
      'approval_overdue' => TaskStatus.approvalOverdue,
      'waiting' => TaskStatus.waiting,
      'pending' || 'new' || 'created' => TaskStatus.pending,
      'assigned' => TaskStatus.assigned,
      'in_progress' || 'started' || 'active' => TaskStatus.inProgress,
      'paused' => TaskStatus.paused,
      'on_hold' => TaskStatus.onHold,
      'in_review' || 'review' => TaskStatus.inReview,
      'completed' || 'done' || 'finished' => TaskStatus.completed,
      'overdue' => TaskStatus.overdue,
      'cancelled' || 'canceled' => TaskStatus.cancelled,
      'rejected' || 'declined' => TaskStatus.rejected,
      'archived' => TaskStatus.archived,
      _ => TaskStatus.unknown,
    };
  }

  /// What the chip says.
  ///
  /// The one place the app's Azerbaijani status wording lives — change a word
  /// here and it changes on every card, in every tab.
  String get label => switch (this) {
    TaskStatus.pendingApproval => 'Təsdiq gözləyir',
    TaskStatus.approvalOverdue => 'Təsdiq gecikdi',
    TaskStatus.waiting => 'Gözləyir',
    TaskStatus.pending => 'Başlanmayıb',
    TaskStatus.assigned => 'Təyin edilib',
    TaskStatus.inProgress => 'İcra edilir',
    TaskStatus.paused => 'Dayandırılıb',
    TaskStatus.onHold => 'Gözlədilir',
    TaskStatus.inReview => 'Yoxlanılır',
    TaskStatus.completed => 'Tamamlandı',
    TaskStatus.overdue => 'Gecikmə',
    TaskStatus.cancelled => 'Ləğv edildi',
    TaskStatus.rejected => 'İmtina edildi',
    TaskStatus.archived => 'Arxivləndi',
    TaskStatus.unknown => 'Naməlum',
  };

  /// The chip's fill. Flat colours rather than gradients — the gradients on
  /// this screen belong to the buttons, and a chip that wore one would read as
  /// something tappable.
  Color get chipColor => switch (this) {
    TaskStatus.pendingApproval => const Color(0xFF7CC9F5),
    TaskStatus.approvalOverdue => const Color(0xFFF08A5D),
    TaskStatus.waiting || TaskStatus.pending => const Color(0xFFC3CCD8),
    TaskStatus.assigned => const Color(0xFFA8C6F0),
    TaskStatus.inProgress => const Color(0xFF5FC1F2),
    TaskStatus.paused || TaskStatus.onHold => const Color(0xFFFFB35C),
    TaskStatus.inReview => const Color(0xFFB9A6F2),
    TaskStatus.completed => const Color(0xFF6FD07A),
    TaskStatus.overdue => const Color(0xFFEFC020),
    TaskStatus.cancelled || TaskStatus.rejected => const Color(0xFFFF7A7A),
    TaskStatus.archived || TaskStatus.unknown => const Color(0xFFC8CFD8),
  };

  /// True while the task is still something somebody is expected to act on.
  bool get isOpen => switch (this) {
    TaskStatus.completed ||
    TaskStatus.cancelled ||
    TaskStatus.rejected ||
    TaskStatus.archived => false,
    _ => true,
  };
}

/// What the buttons on a card do next.
///
/// The design gives one button pair per state and each press swaps the pair:
/// `Təsdiq et`/`İmtina et` become `Başla`/`Redaktə`, `Başla` becomes `Saxla`,
/// `Saxla` becomes `Davam et`. This enum is that chain.
enum TaskAction {
  /// Accept a task that was handed to us.
  approve,

  /// Refuse it.
  reject,

  /// Begin work. Also the button an accepted-but-not-started task shows.
  start,

  /// Pause work — the design calls it `Saxla`.
  pause,

  /// Pick it back up.
  resume,

  /// Opens `Redaktə` — the task editor, which grows out of this very button.
  edit;

  String get label => switch (this) {
    TaskAction.approve => 'Təsdiq et',
    TaskAction.reject => 'İmtina et',
    TaskAction.start => 'Başla',
    TaskAction.pause => 'Saxla',
    TaskAction.resume => 'Davam et',
    TaskAction.edit => 'Redaktə',
  };

  /// The two-or-three stop linear gradient the design specifies, left to
  /// right. These are the exact Figma stops.
  List<Color> get gradient => switch (this) {
    TaskAction.approve => const <Color>[Color(0xFF2BF07E), Color(0xFF00E0EB)],
    TaskAction.reject => const <Color>[Color(0xFFFE8750), Color(0xFFFF0048)],
    TaskAction.start => const <Color>[
      Color(0xFFFF6184),
      Color(0xFFA66EFF),
      Color(0xFF4AB6FF),
    ],
    TaskAction.edit => const <Color>[Color(0xFFFEE450), Color(0xFFABD769)],
    TaskAction.pause => const <Color>[Color(0xFFFFA04D), Color(0xFFFFD43A)],
    TaskAction.resume => const <Color>[Color(0xFF61BD67), Color(0xFF58FF6E)],
  };
}

/// The buttons a card offers, or an empty list when it offers none.
///
/// Only the person carrying the task out gets the *verbs*; everybody else sees
/// the status chip, which is exactly how the design reads — the one card with
/// buttons is the one whose executor name is in bold.
///
/// [canEdit] is the one thing that crosses that line. `Redaktə` belongs to two
/// people, the executor and whoever raised the task
/// (`TaskItem.canEdit`), so a creator who is not the executor gets that button
/// beside their status chip and nothing else. A task waiting to be accepted
/// keeps its `Təsdiq et`/`İmtina et` pair untouched: answering a request is
/// not the same question as changing what was asked for.
List<TaskAction> actionsFor(
  TaskStatus status, {
  required bool mine,
  bool canEdit = false,
}) {
  const List<TaskAction> editOnly = <TaskAction>[TaskAction.edit];
  if (!mine) return canEdit ? editOnly : const <TaskAction>[];
  return switch (status) {
    TaskStatus.pendingApproval => const <TaskAction>[
      TaskAction.approve,
      TaskAction.reject,
    ],
    TaskStatus.pending ||
    TaskStatus.waiting ||
    TaskStatus.assigned ||
    TaskStatus.overdue => const <TaskAction>[TaskAction.start, TaskAction.edit],
    TaskStatus.inProgress => const <TaskAction>[
      TaskAction.pause,
      TaskAction.edit,
    ],
    TaskStatus.paused ||
    TaskStatus.onHold => const <TaskAction>[TaskAction.resume, TaskAction.edit],
    _ => canEdit ? editOnly : const <TaskAction>[],
  };
}
