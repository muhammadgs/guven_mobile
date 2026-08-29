import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// Called when the session is beyond saving — a 401 that a refresh could not
/// rescue. The app signs out in response.
typedef SessionExpiredCallback = void Function();

/// Every HTTP call the app makes goes through here.
///
/// Mirrors the web client's contract, because it talks to the same backend:
/// `Authorization: Bearer …` on everything, and a 401 on a normal endpoint
/// buys exactly one silent refresh-and-retry before the session is declared
/// dead. The refresh is single-flight — four dashboard calls racing on a
/// just-expired token produce one refresh, not four.
class ApiClient {
  ApiClient({
    required this.tokens,
    http.Client? httpClient,
    this.onSessionExpired,
  }) : _http = httpClient ?? http.Client();

  final TokenStore tokens;
  final http.Client _http;

  /// Invoked once when a refresh fails and the session cannot be recovered.
  SessionExpiredCallback? onSessionExpired;

  /// The refresh currently in flight, if any. Non-null only between the first
  /// caller starting a refresh and it completing.
  Future<bool>? _refreshing;

  /// Refresh this far before the token actually lapses, rather than spending a
  /// request to discover it has.
  static const Duration _renewMargin = Duration(seconds: 45);

  void close() => _http.close();

  Future<Object?> get(String endpoint, {Map<String, String>? query}) =>
      _send('GET', endpoint, query: query);

  /// Set [authenticated] false for a call that is *obtaining* credentials
  /// rather than using them. Signing in with a stale token still in the store
  /// would otherwise attach it, and a rejected password would be read as an
  /// expired session — refreshing, retrying, and finally signing out a user
  /// who was only ever trying to sign in.
  Future<Object?> post(
    String endpoint, {
    Object? body,
    bool authenticated = true,
  }) =>
      _send('POST', endpoint, body: body, authenticated: authenticated);

  /// Sends a request whose *response* is the payload rather than its JSON.
  ///
  /// Two things on this backend need it: a file's type and name, which come
  /// back in the `Content-Type` and `Content-Disposition` headers of
  /// `/files/{id}/download` because the `/files/{id}` metadata endpoint 500s,
  /// and the file's bytes themselves. Everything else should use [get] or
  /// [post] — this one hands back the raw response and leaves the status code
  /// to the caller.
  ///
  /// [timeout] is separate from [kApiTimeout] because a download is not a
  /// dashboard call and should be given longer.
  Future<http.Response> rawRequest(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _sendRaw(
    method,
    endpoint,
    query: query,
    extraHeaders: headers,
    timeout: timeout,
  );

  /// Sends one request, refreshing the token around it when needed.
  ///
  /// [authenticated] is false for the login and refresh calls themselves —
  /// they must not try to attach or renew a token they are in the business of
  /// obtaining.
  Future<Object?> _send(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final http.Response response = await _sendRaw(
      method,
      endpoint,
      query: query,
      body: body,
      authenticated: authenticated,
    );
    return _decode(response);
  }

  /// The transport [_send] and [rawRequest] share: auth header, one silent
  /// refresh-and-retry on a 401, and this app's error wording for a dead
  /// connection.
  Future<http.Response> _sendRaw(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
    bool authenticated = true,
    bool isRetry = false,
  }) async {
    if (authenticated && !isRetry && _tokenIsAboutToLapse) {
      await _refreshOnce();
    }

    final Uri uri = apiUri(endpoint, query);
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?extraHeaders,
    };
    final String? token = tokens.accessToken;
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      final http.Request request = http.Request(method, uri)
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout ?? kApiTimeout),
      );
    } on TimeoutException {
      throw const ApiException('Server cavab vermədi. Yenidən cəhd edin.');
    } catch (error) {
      throw ApiException('İnternet bağlantısını yoxlayın.', body: '$error');
    }

    if (response.statusCode == 401 && authenticated && !isRetry) {
      if (await _refreshOnce()) {
        return _sendRaw(
          method,
          endpoint,
          query: query,
          body: body,
          extraHeaders: extraHeaders,
          timeout: timeout,
          isRetry: true,
        );
      }
      onSessionExpired?.call();
    }

    return response;
  }

  bool get _tokenIsAboutToLapse {
    final DateTime? expiry = jwtExpiry(tokens.accessToken);
    if (expiry == null) return false;
    return expiry.difference(DateTime.now()) < _renewMargin;
  }

  /// Exchanges the refresh token for a new pair. At most one runs at a time;
  /// concurrent callers await the same attempt.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _performRefresh() async {
    final String? refresh = tokens.refreshToken;
    if (refresh == null) return false;

    try {
      final Object? payload = await _send(
        'POST',
        '/auth/refresh',
        body: <String, String>{'refresh_token': refresh},
        authenticated: false,
      );
      if (payload is! Map) return false;
      final Object? access = payload['access_token'];
      if (access is! String || access.isEmpty) return false;
      final Object? next = payload['refresh_token'];
      await tokens.save(
        access: access,
        refresh: next is String && next.isNotEmpty ? next : null,
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Turns a response into decoded JSON, or throws with the backend's own
  /// error text.
  ///
  /// FastAPI reports failures as `{"detail": …}`, where `detail` is a string
  /// for hand-written errors and a list of field objects for validation ones;
  /// both shapes are flattened to a single line here.
  Object? _decode(http.Response response) {
    final int status = response.statusCode;
    if (status == 204 || response.bodyBytes.isEmpty) {
      if (status >= 400) throw ApiException(_statusText(status), status: status);
      return null;
    }

    Object? payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      if (status >= 400) throw ApiException(_statusText(status), status: status);
      return null;
    }

    if (status >= 400) {
      throw ApiException(
        _errorMessage(payload) ?? _statusText(status),
        status: status,
        body: payload,
      );
    }
    return payload;
  }

  String? _errorMessage(Object? payload) {
    if (payload is! Map) return null;
    final Object? detail = payload['detail'] ?? payload['message'] ??
        payload['error'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final Object? first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    return null;
  }

  String _statusText(int status) {
    return switch (status) {
      400 => 'Göndərilən məlumat düzgün deyil.',
      401 => 'Giriş məlumatları yanlışdır.',
      403 => 'Bu əməliyyat üçün icazəniz yoxdur.',
      404 => 'Məlumat tapılmadı.',
      >= 500 => 'Serverdə xəta baş verdi. Bir azdan yenidən cəhd edin.',
      _ => 'Xəta baş verdi ($status).',
    };
  }
}
