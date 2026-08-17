/// A request that did not come back with usable data.
///
/// Carries the HTTP [status] where there was one (0 for a transport failure)
/// so callers can tell "the server said no" from "the server never answered",
/// and a [message] already in Azerbaijani — the backend's own `detail` when it
/// sent one, because those are written for this app's users.
class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0, this.body});

  /// Ready to show to the user.
  final String message;

  /// HTTP status, or 0 when the request never reached the server.
  final int status;

  /// The decoded response body, when there was one. For diagnostics only.
  final Object? body;

  /// The session is gone or was never valid — the caller should sign out.
  bool get isUnauthorized => status == 401;

  /// The server was never reached: no network, DNS failure, timeout.
  bool get isOffline => status == 0;

  @override
  String toString() => 'ApiException($status): $message';
}
