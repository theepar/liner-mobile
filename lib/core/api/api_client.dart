import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show HttpDate, HttpException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/connection_report.dart';
import '../models/json_helpers.dart';
import '../models/liner_user.dart';
import '../utils/auth_validation.dart';
import '../utils/uuid.dart';
import 'request_signer.dart';

const _apiUrlPrefKey = 'liner_api_url';
const _sessionStorageKey = 'liner_session';
const _authPathPrefix = '/v1/auth/';
const _refreshLeeway = Duration(minutes: 2);
const _failedOverKey = 'failedOver';
const _retriedAuthKey = 'retriedAuth';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.requestId,
  });

  factory ApiException.fromDio(DioException error) {
    final body = asMap(error.response?.data);
    return ApiException(
      asString(body?['message']) ?? error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
      code: asString(body?['code']),
      requestId: error.response?.headers.value('x-request-id'),
    );
  }

  final String message;

  final int? statusCode;

  final String? code;

  final String? requestId;

  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() =>
      'ApiException($statusCode${code == null ? '' : ' $code'}): $message'
      '${requestId == null ? '' : ' [reqId: $requestId]'}';
}

class _Session {
  const _Session({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  static _Session? tryParse(JsonMap json) {
    final access = asString(json['accessToken']);
    final refresh = asString(json['refreshToken']);
    if (access == null || refresh == null) return null;
    return _Session(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.tryParse(
        asString(json['accessTokenExpiresAt']) ?? '',
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  bool get expiresSoon {
    final expiry = expiresAt;
    return expiry != null && expiry.difference(DateTime.now()) < _refreshLeeway;
  }

  JsonMap toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': expiresAt?.toIso8601String(),
  };
}

class ApiClient {
  ApiClient._(this._dio, this._storage) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  @visibleForTesting
  factory ApiClient.withDio(
    Dio dio, {
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) => ApiClient._(dio, storage);

  static final ApiClient instance = ApiClient._(
    _createDio(),
    const FlutterSecureStorage(),
  );

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final _userChanges = StreamController<LinerUser?>.broadcast();

  String _baseUrl = AppConfig.initialApiUrl;
  _Session? _session;
  LinerUser? _currentUser;
  Future<bool>? _refreshing;
  int _serverClockOffsetMs = 0;

  RequestSigner? signer;

  String get baseUrl => _baseUrl;
  bool get isUsingFallback => _baseUrl == AppConfig.fallbackApiUrl;
  LinerUser? get currentUser => _currentUser;

  Stream<LinerUser?> get userChanges => _userChanges.stream;

  static Dio _createDio() => Dio(
    BaseOptions(
      baseUrl: AppConfig.initialApiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'x-client-version': '${AppConfig.clientVersion}-mobile',
        'x-platform': AppConfig.clientPlatform,
      },
    ),
  );

  Future<void> init() async {
    if (!AppConfig.hasCustomApiUrl) {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_apiUrlPrefKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _applyBaseUrl(savedUrl);
      } else {
        await probeEndpoint();
      }
    }

    await _restoreSession();
    if (_session != null) unawaited(_refreshUser());
  }

  Future<void> setBaseUrl(String url) async {
    _applyBaseUrl(url.replaceAll(RegExp(r'/+$'), ''));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlPrefKey, _baseUrl);
  }

  /// Keeps custom API URLs fixed; otherwise falls back when the primary health check fails.
  Future<String> probeEndpoint() async {
    if (AppConfig.hasCustomApiUrl) return _baseUrl;
    try {
      final probe = Dio(
        BaseOptions(
          connectTimeout: AppConfig.probeTimeout,
          receiveTimeout: AppConfig.probeTimeout,
        ),
      );
      final res = await probe.get<Object?>('${AppConfig.primaryApiUrl}/health');
      if (res.statusCode == 200) {
        _applyBaseUrl(AppConfig.primaryApiUrl);
        return _baseUrl;
      }
    } on DioException catch (error) {
      _log('probeEndpoint', error);
    }
    _applyBaseUrl(AppConfig.fallbackApiUrl);
    return _baseUrl;
  }

  Future<ConnectionReport> checkConnection() async {
    final probe = Dio(
      BaseOptions(
        connectTimeout: AppConfig.probeTimeout,
        receiveTimeout: AppConfig.probeTimeout,
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = _dio.httpClientAdapter;
    final clock = Stopwatch()..start();
    try {
      final res = await probe.get<Object?>('$_baseUrl/health');
      return ConnectionReport(
        baseUrl: _baseUrl,
        statusCode: res.statusCode,
        latency: clock.elapsed,
      );
    } on DioException catch (error) {
      return ConnectionReport(
        baseUrl: _baseUrl,
        failure: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => 'Timed out',
          DioExceptionType.connectionError => 'Could not connect',
          _ => 'Request failed',
        },
      );
    }
  }

  void _applyBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  String resolveUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return '$_baseUrl${pathOrUrl.startsWith('/') ? '' : '/'}$pathOrUrl';
  }

  Future<LinerUser> login(String email, String password) => _authenticate(
    '${_authPathPrefix}login',
    {'email': AuthValidation.normalizeEmail(email), 'password': password},
  );

  Future<LinerUser> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) => _authenticate('${_authPathPrefix}register', {
    'email': AuthValidation.normalizeEmail(email),
    'password': password,
    'username': AuthValidation.normalizeUsername(username),
    'displayName': displayName.trim(),
  });

  Future<void> logout() async {
    final session = _session;
    await _clearSession();
    if (session == null) return;
    try {
      await _dio.post<Object?>(
        '${_authPathPrefix}logout',
        data: {'refreshToken': session.refreshToken},
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
    } on DioException catch (error) {
      _log('logout', error);
    }
  }

  Future<Object?> get(String path, {JsonMap? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Object?> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<Object?> put(String path) => _send('PUT', path);

  Future<Object?> delete(String path) => _send('DELETE', path);

  /// Reassembles fragmented SSE chunks into complete data payloads.
  Stream<String> getEventStream(
    String path, {
    Duration receiveTimeout = const Duration(seconds: 30),
  }) async* {
    final ResponseBody body;
    try {
      final res = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
      body = res.data!;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }

    var buffer = '';
    await for (final chunk in body.stream.cast<List<int>>().transform(
      utf8.decoder,
    )) {
      buffer = (buffer + chunk).replaceAll('\r\n', '\n');
      int boundary;
      while ((boundary = buffer.indexOf('\n\n')) != -1) {
        final event = buffer.substring(0, boundary);
        buffer = buffer.substring(boundary + 2);
        final data = _eventData(event);
        if (data.isNotEmpty) yield data;
      }
    }
    final trailing = _eventData(buffer);
    if (trailing.isNotEmpty) yield trailing;
  }

  static String _eventData(String event) => event
      .split('\n')
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .join('\n');

  Future<Object?> _send(
    String method,
    String path, {
    JsonMap? query,
    Object? body,
  }) async {
    try {
      final res = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LinerUser> _authenticate(String path, JsonMap body) async {
    try {
      final res = await _dio.post<Object?>(path, data: body);
      final data = asMap(res.data);
      final session = data == null ? null : _Session.tryParse(data);
      final userJson = asMap(data?['user']);
      if (session == null || userJson == null) {
        throw const AuthException('The server returned an invalid session.');
      }
      final user = LinerUser.fromJson(userJson);
      await _storeSession(session, user);
      return user;
    } on DioException catch (error) {
      _log('authenticate', error);
      throw AuthException(_authMessage(error));
    }
  }

  /// Prioritizes API error codes because gateway 401s are not invalid credentials.
  static String _authMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) {
      return 'Cannot reach the server. Check your connection.';
    }

    final code = asString(asMap(error.response?.data)?['code']);
    return switch (code) {
      'INVALID_CREDENTIALS' => 'Email or password is incorrect.',
      'EMAIL_ALREADY_USED' => 'This email is already in use.',
      'USERNAME_TAKEN' =>
        'This username is already taken. Please choose another.',
      'INVALID_USERNAME' =>
        'Username must be 3-30 lowercase characters (a-z, 0-9, _).',
      'INVALID_INPUT' => 'Please check the details you entered.',
      _ => switch (status) {
        429 => 'Too many attempts. Try again in a moment.',
        >= 500 => 'The server is having problems. Try again later.',
        401 || 403 =>
          'The Liner server rejected this app (HTTP $status). The API only '
              'accepts requests signed by an authorized client.'
              '${_requestIdSuffix(error)}',
        _ => 'Something went wrong (HTTP $status). Please try again.',
      },
    };
  }

  static String _requestIdSuffix(DioException error) {
    final id = error.response?.headers.value('x-request-id');
    return id == null ? '' : ' [reqId: $id]';
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['x-request-id'] ??= newUuid();
    _attachUserHeaders(options);

    if (!options.path.startsWith(_authPathPrefix)) {
      if (_session?.expiresSoon ?? false) await _refreshSession();
      final token = _session?.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    await _sign(options);
    handler.next(options);
  }

  void _attachUserHeaders(RequestOptions options) {
    final user = _currentUser;
    if (user == null) return;
    options.headers['x-user-id'] ??= user.id;
    final username = user.username;
    if (username != null && username.isNotEmpty) {
      options.headers['x-user-name'] ??= username;
    }
  }

  /// Signs the exact serialized JSON body that Dio sends.
  Future<void> _sign(RequestOptions options) async {
    final signer = this.signer;
    if (signer == null) return;

    final data = options.data;
    final String? body;
    if (data == null) {
      body = null;
    } else if (data is String) {
      body = data;
    } else {
      body = jsonEncode(data);
      options
        ..data = body
        ..contentType = Headers.jsonContentType;
    }

    try {
      options.headers.addAll(
        await signer.sign(
          method: options.method.toUpperCase(),
          path: options.path.split('?').first.trim(),
          timestamp: _serverTimestampSeconds(),
          body: body,
        ),
      );
    } on Exception catch (error) {
      _log('sign', error);
    }
  }

  void _onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _syncClock(response.headers);
    handler.next(response);
  }

  /// Aligns timestamps with the server to keep request signatures valid.
  void _syncClock(Headers? headers) {
    final seconds = int.tryParse(headers?.value('x-liner-server-time') ?? '');
    final dateHeader = headers?.value('date');
    DateTime? serverTime;
    if (seconds != null) {
      serverTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } else if (dateHeader != null) {
      try {
        serverTime = HttpDate.parse(dateHeader);
      } on HttpException {
        serverTime = null;
      }
    }
    if (serverTime != null) {
      _serverClockOffsetMs =
          serverTime.millisecondsSinceEpoch -
          DateTime.now().millisecondsSinceEpoch;
    }
  }

  int _serverTimestampSeconds() =>
      (DateTime.now().millisecondsSinceEpoch + _serverClockOffsetMs) ~/ 1000;

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    _syncClock(error.response?.headers);
    final options = error.requestOptions;
    try {
      final isAuthPath = options.path.startsWith(_authPathPrefix);
      if (error.response?.statusCode == 401 &&
          !isAuthPath &&
          options.extra[_retriedAuthKey] != true &&
          _session != null &&
          await _refreshSession()) {
        options.extra[_retriedAuthKey] = true;
        return handler.resolve(await _dio.fetch<Object?>(options));
      }
      if (_isConnectionFailure(error) &&
          options.extra[_failedOverKey] != true) {
        final failover = _failoverBaseUrl();
        if (failover != null) {
          return handler.resolve(await _retryOn(failover, options));
        }
      }
    } on DioException catch (retryError) {
      return handler.reject(retryError);
    }
    handler.next(error);
  }

  static bool _isConnectionFailure(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout;

  String? _failoverBaseUrl() {
    if (_baseUrl == AppConfig.primaryApiUrl) return AppConfig.fallbackApiUrl;
    if (_baseUrl == AppConfig.fallbackApiUrl) return AppConfig.primaryApiUrl;
    return null;
  }

  Future<Response<Object?>> _retryOn(
    String baseUrl,
    RequestOptions options,
  ) async {
    final previous = _baseUrl;
    _applyBaseUrl(baseUrl);
    try {
      return await _dio.fetch<Object?>(
        options.copyWith(
          baseUrl: baseUrl,
          extra: {...options.extra, _failedOverKey: true},
        ),
      );
    } on DioException {
      _applyBaseUrl(previous);
      rethrow;
    }
  }

  Future<bool> _refreshSession() =>
      _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _performRefresh() async {
    final current = _session;
    if (current == null) return false;
    try {
      final res = await _dio.post<Object?>(
        '${_authPathPrefix}refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final data = asMap(res.data);
      final session = data == null ? null : _Session.tryParse(data);
      if (session == null) return false;
      final userJson = asMap(data?['user']);
      await _storeSession(
        session,
        userJson == null ? _currentUser : LinerUser.fromJson(userJson),
      );
      return true;
    } on DioException catch (error) {
      _log('refresh', error);
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) await _clearSession();
      return false;
    }
  }

  Future<void> _refreshUser() async {
    try {
      final data = asMap(await get('/v1/me'));
      if (data == null || _session == null) return;
      await _storeSession(_session!, LinerUser.fromJson(data));
    } on ApiException catch (error) {
      _log('refreshUser', error);
    }
  }

  Future<void> _restoreSession() async {
    try {
      final raw = await _storage.read(key: _sessionStorageKey);
      final stored = raw == null ? null : asMap(jsonDecode(raw));
      if (stored == null) return;
      final session = _Session.tryParse(stored);
      final userJson = asMap(stored['user']);
      if (session == null || userJson == null) return;
      _session = session;
      _currentUser = LinerUser.fromJson(userJson);
    } on Exception catch (error) {
      _log('restoreSession', error);
      await _clearSession();
    }
  }

  void _setUser(LinerUser? user) {
    if (user == _currentUser) return;
    _currentUser = user;
    _userChanges.add(user);
  }

  Future<void> _storeSession(_Session session, LinerUser? user) async {
    _session = session;
    if (user == null) return;
    _setUser(user);
    try {
      await _storage.write(
        key: _sessionStorageKey,
        value: jsonEncode({...session.toJson(), 'user': user.toJson()}),
      );
    } on Exception catch (error) {
      _log('storeSession', error);
    }
  }

  Future<void> _clearSession() async {
    _session = null;
    _setUser(null);
    try {
      await _storage.delete(key: _sessionStorageKey);
    } on Exception catch (error) {
      _log('clearSession', error);
    }
  }

  static void _log(String operation, Object error) {
    developer.log('$operation failed: $error', name: 'ApiClient');
  }
}
