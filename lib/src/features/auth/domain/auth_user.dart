import '../../../core/json.dart';

/// Which profile the app opens into.
///
/// The backend spells the same two roles a dozen ways across tables and JWT
/// claims — `ceo`, `owner`, `company_admin`, `business_admin` on one side,
/// `employee`, `worker`, `staff`, `user` on the other. They collapse to these
/// two here exactly as the website's `normalizeRole` collapses them, so the
/// mobile app and the site agree on who sees what.
enum UserRole {
  /// Sahibkar — the company's owner. `owner/owp.html` on the site.
  owner,

  /// Əməkdaş — an employee of a company. `worker/wp.html` on the site.
  worker,

  /// Platform staff. No mobile profile of their own yet; treated as an
  /// employee so they at least get a working home screen.
  admin;

  /// Null — rather than a guess — when [raw] says nothing recognisable, so a
  /// response that simply omitted the role cannot silently demote an owner.
  static UserRole? fromRaw(String? raw) {
    final String value = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    return switch (value) {
      'ceo' ||
      'owner' ||
      'company_admin' ||
      'companyadmin' ||
      'business_admin' ||
      'company' =>
        UserRole.owner,
      'admin' || 'superadmin' || 'super_admin' => UserRole.admin,
      'employee' || 'worker' || 'staff' || 'user' => UserRole.worker,
      _ => null,
    };
  }
}

/// The signed-in person, as much of them as the home screen needs.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.statedRole,
    required this.companyCode,
    this.firstName,
    this.lastName,
    this.email,
    this.companyId,
    this.companyName,
  });

  final int? id;

  /// The role a response actually named, or null when none has — see
  /// [UserRole.fromRaw].
  final UserRole? statedRole;

  /// The profile to open. An account whose role never arrived is treated as an
  /// employee: the narrower of the two, and the home screen is the same either
  /// way.
  UserRole get role => statedRole ?? UserRole.worker;

  /// The company this account belongs to. Every dashboard query is scoped by
  /// it, so a session without one can only show empty counts.
  final String? companyCode;

  final String? firstName;
  final String? lastName;
  final String? email;
  final int? companyId;
  final String? companyName;

  /// What the home screen greets them with.
  ///
  /// Given name only — "Salam, Muhəmməd", not the full legal name. Falls back
  /// through surname and the local part of the email before giving up on
  /// "İstifadəçi", so the greeting is never blank.
  String get greetingName {
    final String? first = firstName;
    if (first != null && first.isNotEmpty) return first;
    final String? last = lastName;
    if (last != null && last.isNotEmpty) return last;
    final String? mail = email;
    if (mail != null && mail.contains('@')) {
      final String local = mail.split('@').first;
      if (local.isNotEmpty) {
        return local[0].toUpperCase() + local.substring(1);
      }
    }
    return 'İstifadəçi';
  }

  /// Both names when there are both.
  String get fullName =>
      <String?>[firstName, lastName].whereType<String>().join(' ').trim();

  /// Reads a user out of whichever envelope the backend used.
  ///
  /// `/auth/login` and `/auth/me` both answer `{success, user_service: {…}}`,
  /// but other call sites in the web client have seen `user`, `user_info` and
  /// a bare object, so all four are accepted. [claims] is the access token's
  /// decoded payload, used only to fill gaps the body left — on some accounts
  /// `company_code` is in the token and nowhere else.
  factory AuthUser.fromResponse(
    Object? response, {
    Map<String, Object?> claims = const <String, Object?>{},
  }) {
    final Map<String, Object?> envelope = asMap(response);
    final Map<String, Object?> user = <String, Object?>{
      for (final String key in <String>[
        'user_service',
        'user',
        'user_info',
        'profile',
      ])
        if (envelope[key] is Map) ...asMap(envelope[key]),
    };
    // A bare user object with no envelope at all.
    final Map<String, Object?> row = user.isEmpty ? envelope : user;

    String? pick(List<String> keys) =>
        readString(row, keys) ?? readString(claims, keys);
    int? pickInt(List<String> keys) =>
        readInt(row, keys) ?? readInt(claims, keys);

    return AuthUser(
      id: pickInt(<String>['id', 'user_id', 'sub']),
      statedRole: UserRole.fromRaw(
        pick(<String>['role', 'user_role', 'user_type']),
      ),
      companyCode: pick(<String>['company_code', 'companyCode']),
      firstName: pick(<String>['first_name', 'ceo_name', 'name', 'firstName']),
      lastName: pick(
        <String>['last_name', 'ceo_lastname', 'surname', 'lastName'],
      ),
      email: pick(<String>['email', 'ceo_email']),
      companyId: pickInt(<String>['company_id']),
      companyName: pick(<String>['company_name']),
    );
  }

  /// This user updated with everything [other] actually knows.
  ///
  /// Field-by-field rather than wholesale, because `/auth/me` and the login
  /// body each carry things the other leaves out — and a role the newer
  /// response never stated must not overwrite one that was.
  AuthUser mergeWith(AuthUser other) {
    return AuthUser(
      id: other.id ?? id,
      statedRole: other.statedRole ?? statedRole,
      companyCode: other.companyCode ?? companyCode,
      firstName: other.firstName ?? firstName,
      lastName: other.lastName ?? lastName,
      email: other.email ?? email,
      companyId: other.companyId ?? companyId,
      companyName: other.companyName ?? companyName,
    );
  }
}
