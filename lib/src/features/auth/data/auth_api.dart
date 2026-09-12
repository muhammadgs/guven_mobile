import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_store.dart';
import '../domain/auth_user.dart';
import '../domain/login_identifier.dart';

/// The `/auth` endpoints, plus the token bookkeeping around them.
class AuthApi {
  const AuthApi(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  /// Signs in and stores the token pair.
  ///
  /// [login] is an email or a phone number that has already been checked and
  /// normalised — the backend's `username` field accepts either. Returns
  /// whatever the login body said about the user; [currentUser] fills in the
  /// rest.
  Future<AuthUser> signIn({
    required LoginIdentifier login,
    required String password,
  }) async {
    final Object? payload;
    try {
      payload = await _client.post(
        '/auth/login',
        authenticated: false,
        body: <String, String>{
          'username': login.username,
          'password': password,
        },
      );
    } on ApiException catch (error) {
      // The backend answers a bad password with
      // "Invalid credentials - user_service not found" — English, and about
      // its own internals. Everywhere else its `detail` is Azerbaijani prose
      // written for these users, so only this one case is rewritten.
      if (error.status == 401 || error.status == 400) {
        throw const ApiException(
          'Email/nömrə və ya şifrə yanlışdır.',
          status: 401,
        );
      }
      rethrow;
    }

    final Map<String, Object?> body = asMap(payload);
    final Object? access = body['access_token'];
    if (access is! String || access.isEmpty) {
      throw const ApiException('Server token qaytarmadı.', status: 200);
    }
    final Object? refresh = body['refresh_token'];
    await _tokens.save(
      access: access,
      refresh: refresh is String && refresh.isNotEmpty ? refresh : null,
    );

    return AuthUser.fromResponse(
      body,
      claims: decodeJwtPayload(access) ?? const <String, Object?>{},
    );
  }

  /// The signed-in user, straight from the server.
  Future<AuthUser> currentUser() async {
    final Object? payload = await _client.get('/auth/me');
    return AuthUser.fromResponse(
      payload,
      claims: decodeJwtPayload(_tokens.accessToken) ?? const <String, Object?>{},
    );
  }

  /// Ends the session on the server, then locally.
  ///
  /// The local half happens regardless: if the server cannot be reached the
  /// user still expects to be signed out of this device.
  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout');
    } on ApiException {
      // Already invalid, or offline. Either way the tokens go.
    }
    await _tokens.clear();
  }
}
