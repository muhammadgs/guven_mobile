import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../domain/database_overview.dart';

/// The calls behind the `Baza` tab, all of them to the 1C bridge.
///
/// None of them names a company: the bridge reads the company's 1C database
/// out of the bearer token, the same one the main API issued, and answers for
/// that company alone.
class DatabaseApi {
  const DatabaseApi(this._client);

  final ApiClient _client;

  /// A list asked for only for its `total`. One row is the least a page can
  /// hold; the rows themselves are thrown away.
  static const Map<String, String> _totalOnly = <String, String>{
    'page': '1',
    'page_size': '1',
  };

  /// Everything `Əsas panel` shows.
  ///
  /// The four requests run concurrently and each one falls back to nothing on
  /// its own, the way the home screen's do: a bridge whose `orders` table is
  /// mid-sync should not blank the other nine figures. Only when all four fail
  /// is the failure passed on — the summary's, which is the one that says the
  /// most.
  Future<DatabaseOverview> overview() async {
    final List<_Part> parts = await Future.wait<_Part>(<Future<_Part>>[
      _part(() => _get('/onec-data/summary/')),
      _part(() => _get('/products/', query: _totalOnly)),
      _part(() => _get('/customers/', query: _totalOnly)),
      _part(() => _get('/orders/', query: _totalOnly)),
    ]);

    if (parts.every((_Part part) => part.failure != null)) {
      throw parts.first.failure!;
    }

    return DatabaseOverview.fromResponses(
      summary: parts[0].payload,
      products: parts[1].payload,
      customers: parts[2].payload,
      orders: parts[3].payload,
    );
  }

  /// The trailing slashes are the bridge's own: FastAPI answers the bare path
  /// with a redirect, which costs a round trip for nothing.
  Future<Object?> _get(String endpoint, {Map<String, String>? query}) =>
      _client.get(endpoint, query: query, origin: kOnecApiOrigin);

  Future<_Part> _part(Future<Object?> Function() request) async {
    try {
      return _Part(payload: await request());
    } on ApiException catch (error) {
      return _Part(failure: error);
    }
  }
}

/// One of the concurrent loads: what came back, or why nothing did.
class _Part {
  const _Part({this.payload, this.failure});

  final Object? payload;
  final ApiException? failure;
}
