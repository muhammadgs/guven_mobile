import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/activity.dart';
import '../domain/home_snapshot.dart';

/// The four calls behind the home screen.
///
/// The same four the website's owner and worker dashboards make — they share
/// one `dashboard.js`, which is why both profiles' home screens are identical
/// here too. The endpoints are taken from that file rather than invented, so
/// the counts on the phone match the counts on the site.
class HomeApi {
  const HomeApi(this._client);

  final ApiClient _client;

  /// Task states that count as "aktiv": everything the task manager still
  /// expects someone to act on. The complement — completed, cancelled,
  /// rejected, archived — is done with.
  static const List<String> activeTaskStatuses = <String>[
    'pending',
    'in_progress',
    'overdue',
    'pending_approval',
    'waiting',
    'paused',
  ];

  /// Loads the whole screen.
  ///
  /// The four requests run concurrently, and each one falls back to empty on
  /// its own rather than taking the screen down with it: a company with no
  /// partner relationships legitimately 404s on `parent-companies`, and one
  /// dead section should not blank the other two. A total failure — nothing
  /// came back at all — is rethrown so the screen can show a retry.
  Future<HomeSnapshot> load({required String? companyCode}) async {
    if (companyCode == null || companyCode.isEmpty) {
      // Nothing is scoped without it; the task list is the only thing the
      // backend can still answer, since it scopes by token.
      final List<Map<String, Object?>> tasks = await _activeTasks();
      return HomeSnapshot(
        employeeCount: 0,
        companyCount: 0,
        activeTaskCount: tasks.length,
        activities: _buildFeed(tasks: tasks),
      );
    }

    final List<_Section> sections = await Future.wait<_Section>(<Future<_Section>>[
      _section(() => _employees(companyCode)),
      _section(() => _customerCompanies(companyCode)),
      _section(() => _executorCompanies(companyCode)),
      _section(_activeTasks),
    ]);

    if (sections.every((_Section s) => s.failure != null)) {
      throw sections.first.failure!;
    }

    final List<Map<String, Object?>> employees = sections[0].rows;
    final List<Map<String, Object?>> companies = _distinctCompanies(
      <Map<String, Object?>>[...sections[1].rows, ...sections[2].rows],
      excluding: companyCode,
    );
    final List<Map<String, Object?>> tasks = sections[3].rows;

    return HomeSnapshot(
      employeeCount: employees.length,
      companyCount: companies.length,
      activeTaskCount: tasks.length,
      activities: _buildFeed(
        tasks: tasks,
        employees: employees,
        companies: companies,
      ),
    );
  }

  /// Active people in this company.
  Future<List<Map<String, Object?>>> _employees(String companyCode) async {
    final Object? payload = await _client.get(
      '/users/company/$companyCode',
      query: <String, String>{'include_inactive': 'false'},
    );
    // `include_inactive=false` is honoured by most deployments but not all —
    // the website filters again client-side for the same reason.
    return asRows(payload, keys: <String>['users', 'employees'])
        .where(isActiveRow)
        .toList(growable: false);
  }

  /// Sifarişçi şirkətlər — the companies this one works *for*, which the
  /// backend models as its sub-companies.
  Future<List<Map<String, Object?>>> _customerCompanies(String companyCode) async {
    final Object? payload =
        await _client.get('/companies/$companyCode/sub-companies');
    return asRows(payload, keys: <String>['sub_companies']);
  }

  /// İcraçı şirkətlər — the companies that carry work out for this one.
  Future<List<Map<String, Object?>>> _executorCompanies(String companyCode) async {
    final Object? payload =
        await _client.get('/companies/$companyCode/parent-companies');
    return asRows(payload, keys: <String>['parent_companies']);
  }

  /// Everything still open in the internal task manager.
  Future<List<Map<String, Object?>>> _activeTasks() async {
    final Object? payload = await _client.get(
      '/tasks/detailed',
      query: <String, String>{
        'page': '1',
        'limit': '100',
        'status': activeTaskStatuses.join(','),
      },
    );
    // The endpoint takes `status` as a hint, not a guarantee — a deployment
    // that ignores it would otherwise inflate the count with finished work.
    return asRows(payload, keys: <String>['tasks']).where((row) {
      final String? status = readString(row, <String>['status', 'task_status']);
      return status == null || activeTaskStatuses.contains(status);
    }).toList(growable: false);
  }

  /// One entry per company, own company removed.
  ///
  /// A partner can be both an executor and a customer, and the two endpoints
  /// then return it twice; counting it twice would overstate the total.
  List<Map<String, Object?>> _distinctCompanies(
    List<Map<String, Object?>> rows, {
    required String excluding,
  }) {
    final Set<String> seen = <String>{excluding.toLowerCase()};
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    for (final Map<String, Object?> row in rows) {
      final String key = (readString(row, <String>[
                'company_code',
                'companyCode',
                'code',
              ]) ??
              readString(row, <String>['id', 'company_id']) ??
              '')
          .toLowerCase();
      if (key.isEmpty || seen.add(key)) out.add(row);
    }
    return out;
  }

  /// Merges the three record types into one reverse-chronological feed.
  ///
  /// Records with no timestamp are dropped rather than dated to now — an
  /// undated row floating at the top of "son aktivliklər" is worse than an
  /// absent one.
  List<Activity> _buildFeed({
    required List<Map<String, Object?>> tasks,
    List<Map<String, Object?>> employees = const <Map<String, Object?>>[],
    List<Map<String, Object?>> companies = const <Map<String, Object?>>[],
  }) {
    const List<String> createdKeys = <String>[
      'created_at',
      'createdAt',
      'created_date',
      'joined_date',
    ];
    final List<Activity> feed = <Activity>[];

    for (final Map<String, Object?> task in tasks) {
      final DateTime? at = readDate(task, createdKeys);
      if (at == null) continue;
      final String title =
          readString(task, <String>['task_title', 'title', 'name']) ?? 'Tapşırıq';
      final String? status = readString(task, <String>['status', 'task_status']);
      feed.add(Activity(
        kind: ActivityKind.task,
        title: '"$title" tapşırığı ${_taskPhrase(status)}',
        subtitle: readString(task, <String>[
          'creator_name',
          'assigned_by_name',
          'assigned_to_name',
        ]),
        happenedAt: at,
      ));
    }

    for (final Map<String, Object?> employee in employees) {
      final DateTime? at = readDate(employee, createdKeys);
      if (at == null) continue;
      final String name = _personName(employee) ?? 'İşçi';
      final String role = _isAdmin(employee) ? 'admin' : 'işçi';
      feed.add(Activity(
        kind: ActivityKind.employee,
        title: '$name $role kimi əlavə edildi',
        subtitle: readString(employee, <String>[
          'position',
          'position_name',
          'department_name',
        ]),
        happenedAt: at,
      ));
    }

    for (final Map<String, Object?> company in companies) {
      final DateTime? at = readDate(company, createdKeys);
      if (at == null) continue;
      final String name = readString(company, <String>[
            'company_name',
            'name',
            'companyName',
          ]) ??
          'Şirkət';
      feed.add(Activity(
        kind: ActivityKind.company,
        title: '$name şirkəti qeydiyyatdan keçdi',
        subtitle: readString(company, <String>['company_code', 'code', 'voen']),
        happenedAt: at,
      ));
    }

    feed.sort((Activity a, Activity b) => b.happenedAt.compareTo(a.happenedAt));
    // The list scrolls, but it is a *recent* activity feed — past a few dozen
    // rows nobody is reading, and every extra row is a live glass lens.
    return feed.length > 40 ? feed.sublist(0, 40) : feed;
  }

  String _taskPhrase(String? status) {
    return switch (status) {
      'in_progress' => 'icra edilir',
      'pending' => 'gözləmə vəziyyətindədir',
      'overdue' => 'müddəti bitmişdir',
      'pending_approval' => 'təsdiq gözləyir',
      'approval_overdue' => 'təsdiq müddəti bitmişdir',
      'waiting' => 'gözləyir',
      'paused' => 'dayandırılıb',
      'completed' => 'tamamlandı',
      'rejected' => 'imtina edildi',
      _ => 'yaradıldı',
    };
  }

  String? _personName(Map<String, Object?> row) {
    final String? first =
        readString(row, <String>['first_name', 'ceo_name', 'name']);
    final String? last =
        readString(row, <String>['last_name', 'ceo_lastname', 'surname']);
    final String joined =
        <String?>[first, last].whereType<String>().join(' ').trim();
    if (joined.isNotEmpty) return joined;
    return readString(row, <String>['full_name', 'email', 'ceo_email']);
  }

  bool _isAdmin(Map<String, Object?> row) {
    final String role =
        (readString(row, <String>['user_type', 'role', 'position']) ?? '')
            .toLowerCase();
    return role.contains('admin') || role == 'ceo' || role == 'owner';
  }

  /// Runs one section, capturing its failure instead of propagating it.
  Future<_Section> _section(
    Future<List<Map<String, Object?>>> Function() request,
  ) async {
    try {
      return _Section(rows: await request());
    } on ApiException catch (error) {
      return _Section(rows: const <Map<String, Object?>>[], failure: error);
    }
  }
}

/// One of the four concurrent loads: what came back, or why nothing did.
class _Section {
  const _Section({required this.rows, this.failure});

  final List<Map<String, Object?>> rows;
  final ApiException? failure;
}
