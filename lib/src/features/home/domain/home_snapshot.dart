import 'activity.dart';

/// Everything the home screen shows, as of one refresh.
class HomeSnapshot {
  const HomeSnapshot({
    required this.employeeCount,
    required this.companyCount,
    required this.activeTaskCount,
    required this.activities,
  });

  const HomeSnapshot.empty()
      : employeeCount = 0,
        companyCount = 0,
        activeTaskCount = 0,
        activities = const <Activity>[];

  /// Active people in the user's own company.
  final int employeeCount;

  /// İcraçı + sifarişçi companies, deduplicated, excluding the user's own.
  final int companyCount;

  /// Everything in the task manager that is not finished, cancelled or
  /// archived.
  final int activeTaskCount;

  /// Newest first.
  final List<Activity> activities;
}
