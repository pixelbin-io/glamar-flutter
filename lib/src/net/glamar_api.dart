import 'dart:convert';

import 'package:dio/dio.dart';

import 'interceptor.dart';
import 'model/version_api_response.dart';
import 'model/version_response.dart';

class GlamArApi {
  GlamArApi({
    required this.accessKey,
    bool development = false,
    Dio? dio,
    String? apiBaseUrlOverride,
    this.enableCurlLogging = false,
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 20000,
  }) : _development = development,
       _apiBaseUrl = apiBaseUrlOverride ?? _defaultApiBaseUrl,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: apiBaseUrlOverride ?? _defaultApiBaseUrl,
               connectTimeout: Duration(milliseconds: connectTimeoutMs),
               receiveTimeout: Duration(milliseconds: receiveTimeoutMs),
             ),
           ) {
    if (enableCurlLogging) {
      _dio.interceptors.add(CurlLogger(logResponse: true));
    }
    _dio.interceptors.add(RequestSigningInterceptor());
  }

  final String accessKey;
  final bool _development;
  final bool enableCurlLogging;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;

  final String _apiBaseUrl;
  final Dio _dio;

  static const String _defaultApiBaseUrl = 'https://api.glamar.fynd.com';
  static const String _fallbackApiBaseUrl = 'https://api.pixelbin.io';

  String get apiBaseUrl => _apiBaseUrl;

  bool get development => _development;

  /// Resolve the version from GlamAR, retrying PixelBin if the request fails.
  Future<String?> getVersion({
    String? appId,
    void Function(VersionApiResponse response)? onResponse,
  }) async {
    final trimmed = appId?.trim();
    final query = (trimmed != null && trimmed.isNotEmpty)
        ? '?appId=${Uri.encodeQueryComponent(trimmed)}'
        : '';
    final urls = [
      '$_apiBaseUrl/service/private/glamar/v3.0/sdk-settings/version$query',
      '$_fallbackApiBaseUrl/service/private/misc/v3.0/sdk-settings/version$query',
    ];

    final headers = <String, String>{
      'Authorization': 'Bearer ${base64Encode(utf8.encode(accessKey))}',
    };

    for (final url in urls) {
      try {
        final res = await _dio.get<dynamic>(
          url,
          options: Options(headers: headers),
        );

        _reportResponse(
          onResponse,
          VersionApiResponse(
            url: url,
            statusCode: res.statusCode,
            body: res.data,
          ),
        );
        final code = res.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          final data = res.data;
          return data is Map<String, dynamic> && data['sdkVersion'] is String
              ? VersionResponse.fromJson(data).sdkVersion
              : null;
        }
      } on DioException catch (error) {
        _reportResponse(
          onResponse,
          VersionApiResponse(
            url: url,
            statusCode: error.response?.statusCode,
            body: error.response?.data,
            error:
                '${error.type.name}: ${error.message ?? error.error ?? 'Request failed'}',
          ),
        );
        // Try the next endpoint; the caller handles the final version fallback.
      }
    }
    return null;
  }

  void _reportResponse(
    void Function(VersionApiResponse response)? callback,
    VersionApiResponse response,
  ) {
    try {
      callback?.call(response);
    } catch (_) {
      // A diagnostics callback must not affect version lookup or fallback.
    }
  }
}
