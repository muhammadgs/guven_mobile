/// What kind of thing happened. Only used to pick the row's icon.
enum ActivityKind { task, employee, company }

/// One line in the "son aktivliklər" feed.
///
/// Two strings and a time, because that is what the row draws: what happened,
/// who it belongs to, and how long ago.
class Activity {
  const Activity({
    required this.kind,
    required this.title,
    required this.happenedAt,
    this.subtitle,
  });

  final ActivityKind kind;

  /// The event, already phrased — `"Natural Meat MMC" tapşırığı icra edilir`.
  final String title;

  /// Who it belongs to: the task's creator, the employee's position, the
  /// company's code. Null when the record did not say.
  final String? subtitle;

  final DateTime happenedAt;
}

/// "4 saat əvvəl", "dünən", "2 həftə əvvəl" — the same ladder the website's
/// `getTimeAgo` walks, so the two products describe the same event the same
/// way.
String timeAgo(DateTime moment, {DateTime? now}) {
  final Duration gap = (now ?? DateTime.now()).difference(moment);

  // A clock skew between the phone and the server can put a fresh record a
  // few seconds in the future. That is still "just now", not "in -3 minutes".
  if (gap.inSeconds < 60) return 'bir neçə saniyə əvvəl';
  if (gap.inMinutes < 60) return '${gap.inMinutes} dəqiqə əvvəl';
  if (gap.inHours < 24) return '${gap.inHours} saat əvvəl';
  if (gap.inDays == 1) return 'dünən';
  if (gap.inDays < 7) return '${gap.inDays} gün əvvəl';
  if (gap.inDays < 30) return '${gap.inDays ~/ 7} həftə əvvəl';
  if (gap.inDays < 365) return '${gap.inDays ~/ 30} ay əvvəl';
  return '${gap.inDays ~/ 365} il əvvəl';
}
