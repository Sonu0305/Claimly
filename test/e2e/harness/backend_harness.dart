/// Direct HTTP client harness for Supabase PostgREST, Auth, Storage, and Edge Functions.
import 'dart:convert';
import 'dart:io';

class HttpResponseData {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const HttpResponseData({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  dynamic get json {
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'HTTP $statusCode\n$body';
}

class BackendHarness {
  final String projectUrl;
  final String anonKey;
  final String serviceRole;
  final HttpClient _client = HttpClient();

  BackendHarness({
    required this.projectUrl,
    required this.anonKey,
    required this.serviceRole,
  });

  factory BackendHarness.fromEnv([String envPath = '.env']) {
    final envMap = <String, String>{};
    
    // First read system environment
    envMap.addAll(Platform.environment);

    // Then read .env file if it exists
    final envFile = File(envPath);
    if (envFile.existsSync()) {
      for (final line in envFile.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final splitIdx = trimmed.indexOf('=');
        if (splitIdx != -1) {
          final key = trimmed.substring(0, splitIdx).trim();
          final val = trimmed.substring(splitIdx + 1).trim();
          envMap[key] = val;
        }
      }
    }

    final url = envMap['project_url'] ??
        envMap['SUPABASE_URL'] ??
        'https://kvxfkfgzsapvvswjcmzj.supabase.co';
    final anon = envMap['anon_public_key'] ??
        envMap['SUPABASE_ANON_KEY'] ??
        '';
    final service = envMap['service_role'] ??
        envMap['SUPABASE_SERVICE_ROLE_KEY'] ??
        '';

    return BackendHarness(
      projectUrl: url,
      anonKey: anon,
      serviceRole: service,
    );
  }

  void close() {
    _client.close();
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = projectUrl.endsWith('/')
        ? projectUrl.substring(0, projectUrl.length - 1)
        : projectUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final baseUri = Uri.parse('$cleanBase$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return baseUri.replace(queryParameters: queryParams);
    }
    return baseUri;
  }

  Map<String, String> _buildHeaders({
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? customHeaders,
  }) {
    final key = useServiceRole ? serviceRole : anonKey;
    final bearer = jwt ?? (useServiceRole ? serviceRole : anonKey);

    final headers = <String, String>{
      'apikey': key,
      'Authorization': 'Bearer $bearer',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  Future<HttpResponseData> _sendRequest(
    String method,
    String path, {
    dynamic body,
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? queryParams,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(path, queryParams);
    final headers = _buildHeaders(
      jwt: jwt,
      useServiceRole: useServiceRole,
      customHeaders: customHeaders,
    );

    final request = await _client.openUrl(method, uri);
    headers.forEach((k, v) => request.headers.set(k, v));

    if (body != null) {
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      request.headers.contentLength = jsonBytes.length;
      request.add(jsonBytes);
    }

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();

    final respHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      respHeaders[name] = values.join(', ');
    });

    return HttpResponseData(
      statusCode: response.statusCode,
      headers: respHeaders,
      body: responseBody,
    );
  }

  // Generic HTTP calls
  Future<HttpResponseData> get(
    String path, {
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) =>
      _sendRequest(
        'GET',
        path,
        jwt: jwt,
        useServiceRole: useServiceRole,
        queryParams: queryParams,
        customHeaders: headers,
      );

  Future<HttpResponseData> post(
    String path, {
    dynamic body,
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) =>
      _sendRequest(
        'POST',
        path,
        body: body,
        jwt: jwt,
        useServiceRole: useServiceRole,
        queryParams: queryParams,
        customHeaders: headers,
      );

  Future<HttpResponseData> patch(
    String path, {
    dynamic body,
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) =>
      _sendRequest(
        'PATCH',
        path,
        body: body,
        jwt: jwt,
        useServiceRole: useServiceRole,
        queryParams: queryParams,
        customHeaders: headers,
      );

  Future<HttpResponseData> delete(
    String path, {
    String? jwt,
    bool useServiceRole = false,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) =>
      _sendRequest(
        'DELETE',
        path,
        jwt: jwt,
        useServiceRole: useServiceRole,
        queryParams: queryParams,
        customHeaders: headers,
      );

  // PostgREST Database operations
  Future<HttpResponseData> queryTable(
    String table, {
    String query = '',
    String? jwt,
    bool useServiceRole = false,
  }) {
    final path = query.isEmpty ? '/rest/v1/$table' : '/rest/v1/$table?$query';
    return get(path, jwt: jwt, useServiceRole: useServiceRole);
  }

  Future<HttpResponseData> insertRow(
    String table,
    Map<String, dynamic> row, {
    String? jwt,
    bool useServiceRole = false,
  }) {
    return post(
      '/rest/v1/$table',
      body: row,
      jwt: jwt,
      useServiceRole: useServiceRole,
    );
  }

  Future<HttpResponseData> updateRow(
    String table,
    String filterQuery,
    Map<String, dynamic> updateData, {
    String? jwt,
    bool useServiceRole = false,
  }) {
    return patch(
      '/rest/v1/$table?$filterQuery',
      body: updateData,
      jwt: jwt,
      useServiceRole: useServiceRole,
    );
  }

  Future<HttpResponseData> deleteRow(
    String table,
    String filterQuery, {
    String? jwt,
    bool useServiceRole = false,
  }) {
    return delete(
      '/rest/v1/$table?$filterQuery',
      jwt: jwt,
      useServiceRole: useServiceRole,
    );
  }

  // Supabase Auth (GoTrue) operations
  Future<HttpResponseData> createAdminUser({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
    bool emailConfirm = true,
  }) {
    return post(
      '/auth/v1/admin/users',
      body: {
        'email': email,
        'password': password,
        'email_confirm': emailConfirm,
        if (metadata != null) 'user_metadata': metadata,
      },
      useServiceRole: true,
    );
  }

  Future<HttpResponseData> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return post('/auth/v1/signup', body: {
      'email': email,
      'password': password,
      if (data != null) 'data': data,
    });
  }

  Future<HttpResponseData> signIn({
    required String email,
    required String password,
  }) {
    return post('/auth/v1/token?grant_type=password', body: {
      'email': email,
      'password': password,
    });
  }

  Future<HttpResponseData> signOut({required String jwt}) {
    return post('/auth/v1/logout', jwt: jwt);
  }

  Future<HttpResponseData> refreshSession({required String refreshToken}) {
    return post('/auth/v1/token?grant_type=refresh_token', body: {
      'refresh_token': refreshToken,
    });
  }

  Future<HttpResponseData> resetPasswordForEmail({required String email}) {
    return post('/auth/v1/recover', body: {'email': email});
  }

  Future<HttpResponseData> deleteAuthUser(String userId) {
    return delete(
      '/auth/v1/admin/users/$userId',
      useServiceRole: true,
    );
  }

  // Storage operations
  Future<HttpResponseData> listBuckets({bool useServiceRole = false, String? jwt}) {
    return get('/storage/v1/bucket', useServiceRole: useServiceRole, jwt: jwt);
  }

  Future<HttpResponseData> uploadStorageObject(
    String bucket,
    String path,
    List<int> bytes, {
    String contentType = 'image/jpeg',
    String? jwt,
    bool useServiceRole = false,
  }) async {
    final uri = _buildUri('/storage/v1/object/$bucket/$path');
    final key = useServiceRole ? serviceRole : anonKey;
    final bearer = jwt ?? (useServiceRole ? serviceRole : anonKey);

    final request = await _client.openUrl('POST', uri);
    request.headers.set('apikey', key);
    request.headers.set('Authorization', 'Bearer $bearer');
    request.headers.set('Content-Type', contentType);
    request.headers.contentLength = bytes.length;
    request.add(bytes);

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    final respHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      respHeaders[name] = values.join(', ');
    });

    return HttpResponseData(
      statusCode: response.statusCode,
      headers: respHeaders,
      body: body,
    );
  }

  Future<HttpResponseData> getStorageObject(
    String bucket,
    String path, {
    String? jwt,
    bool useServiceRole = false,
  }) {
    return get(
      '/storage/v1/object/$bucket/$path',
      jwt: jwt,
      useServiceRole: useServiceRole,
    );
  }

  // Edge Functions invocation
  Future<HttpResponseData> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    String? jwt,
    bool useServiceRole = false,
  }) {
    return post(
      '/functions/v1/$functionName',
      body: body,
      jwt: jwt,
      useServiceRole: useServiceRole,
    );
  }
}
