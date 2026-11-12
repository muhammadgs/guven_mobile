/// What the unlock screen says before the name, by the phone's own clock.
///
/// The user gave the four phrases and left the hours to us (2026-11-12):
///
/// * 05:00–11:59 — `Sabahınız xeyir`
/// * 12:00–17:59 — `Hər vaxtınız xeyir`
/// * 18:00–22:59 — `Axşamınız xeyir`
/// * 23:00–04:59 — `Gecəniz xeyir`
///
/// Local time rather than Baku time on purpose: a greeting is about the
/// person's own morning, wherever they are.
String passcodeGreeting(DateTime now) {
  final int hour = now.hour;
  if (hour >= 5 && hour < 12) return 'Sabahınız xeyir';
  if (hour >= 12 && hour < 18) return 'Hər vaxtınız xeyir';
  if (hour >= 18 && hour < 23) return 'Axşamınız xeyir';
  return 'Gecəniz xeyir';
}

/// `Sabahınız xeyir, Məhəmməd.` — or without the name when there is none.
String passcodeGreetingLine(DateTime now, String? name) =>
    _withName(passcodeGreeting(now), name);

/// `Xoş Gəldiniz, Məhəmməd.` — the first screen after signing in.
String passcodeWelcomeLine(String? name) => _withName('Xoş Gəldiniz', name);

String _withName(String phrase, String? name) {
  final String trimmed = (name ?? '').trim();
  return trimmed.isEmpty ? '$phrase.' : '$phrase, $trimmed.';
}
