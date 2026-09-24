/// Where the app talks to the backend.
///
/// The same PostgreSQL Service API the web platform at guvenfinans.az uses.
/// The website reaches it through `guvenfinans.az/proxy.php` because a browser
/// on an https page may not call an http origin; a native app has no such
/// rule, so it goes straight to the VPS the way the site's own local-dev mode
/// does.
///
/// That origin is plain **http** on a non-standard port, which both iOS (App
/// Transport Security) and Android (cleartext policy) refuse by default —
/// `ios/Runner/Info.plist` and `android/.../network_security_config.xml` carry
/// an exception for this one host. If the backend ever gets a certificate,
/// change [origin] to https and delete both exceptions.
library;

/// Scheme, host and port of the API. No trailing slash.
const String kApiOrigin = 'http://212.64.211.194:8008';

/// The 1C bridge — the second service the app talks to, and the whole of the
/// `Baza` section: products, customers, orders and the snapshot tables 1C
/// syncs into PostgreSQL.
///
/// Published as `vps.guvenfinans.az:8005`; written as the IP for the same
/// reason [kApiOrigin] is, which is also what lets it share that origin's
/// cleartext exceptions on both platforms. It takes the same bearer token as
/// [kApiOrigin] and reads the company's 1C database (`baza_id`) out of it, so
/// nothing here names a company.
const String kOnecApiOrigin = 'http://212.64.211.194:8005';

/// Version prefix every endpoint in this app sits under.
const String kApiPrefix = '/api/v1';

/// Resolves an endpoint written the way the web client writes them —
/// `/auth/login`, `/users/company/GF44` — into a full URI on [origin].
///
/// A path that already carries the version prefix is passed through, so
/// callers may write either form.
Uri apiUri(
  String endpoint, [
  Map<String, String>? query,
  String origin = kApiOrigin,
]) {
  final String path =
      endpoint.startsWith(kApiPrefix) ? endpoint : '$kApiPrefix$endpoint';
  return Uri.parse('$origin$path').replace(
    queryParameters: query == null || query.isEmpty ? null : query,
  );
}

/// How long a single request may take before it is abandoned.
///
/// The dashboard fires its four calls concurrently, so this is the worst case
/// for the whole screen rather than for each hop in turn.
const Duration kApiTimeout = Duration(seconds: 20);
