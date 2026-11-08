import 'package:flutter/widgets.dart';

import '../application/attendance_controller.dart';
import '../domain/attendance.dart';
import 'widgets/attendance_prompt.dart';

/// The 09:00 and 18:00 reminders.
///
/// The site raises them once a day per browser. Here they are raised once
/// per *visit*: the first time the home screen is on view after the hour
/// with the button still unpressed — opening the app is when someone is
/// looking, which is the point of a reminder. `Sonra` puts it away until
/// the app is next opened.
class AttendanceReminder {
  AttendanceReminder(this.controller);

  final AttendanceController controller;

  /// `in:2026-11-08`, `out:2026-11-08` — what has already been shown.
  final Set<String> _shown = <String>{};

  bool _showing = false;

  /// Which reminder is due right now, by the last known state — before any
  /// network is spent confirming it.
  AttendanceKind? _due() {
    if (controller.load != AttendanceLoad.ready || controller.isBusy) {
      return null;
    }
    final DateTime now = controller.baku;
    final String day = attendanceDateKey(now);
    if (controller.day == AttendanceDay.notEntered &&
        AttendanceRules.entryReminderDue(now) &&
        !_shown.contains('in:$day')) {
      return AttendanceKind.entry;
    }
    if (controller.day == AttendanceDay.atWork &&
        AttendanceRules.exitReminderDue(now) &&
        !_shown.contains('out:$day')) {
      return AttendanceKind.exit;
    }
    return null;
  }

  /// Shows the reminder that is due, if any. [canShow] is asked twice —
  /// before and after the re-read — because the screen may have been left
  /// while the request was out.
  Future<void> check(BuildContext context, bool Function() canShow) async {
    if (_showing || !canShow() || _due() == null) return;
    _showing = true;
    try {
      // Confirm with the server first: the button may have been pressed on
      // the website since this screen last looked.
      await controller.refresh();
      final AttendanceKind? kind = _due();
      if (kind == null || !context.mounted || !canShow()) return;
      final String day = attendanceDateKey(controller.baku);
      _shown.add(kind == AttendanceKind.entry ? 'in:$day' : 'out:$day');
      await showAttendancePrompt(
        context,
        controller: controller,
        kind: kind,
        start: PromptStage.reminder,
      );
    } finally {
      _showing = false;
    }
  }
}
