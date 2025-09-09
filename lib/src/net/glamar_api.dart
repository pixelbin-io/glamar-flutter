import 'dart:convert';

import 'package:dio/dio.dart';

import 'interceptor.dart';
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
       _apiBaseUrl = apiBaseUrlOverride ?? _defaultApiBaseUrl(development),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: apiBaseUrlOverride ?? _defaultApiBaseUrl(development),
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

  static String _defaultApiBaseUrl(bool dev) =>
      dev ? 'https://api.pixelbin.io' : 'https://api.pixelbin.io';

  String get apiBaseUrl => _apiBaseUrl;

  bool get development => _development;

  /// GET /service/private/misc/v3.0/sdk-settings/versio
  Future<String?> getVersion() async {
    const path = '/service/private/misc/v3.0/sdk-settings/version';
    final headers = {
      'Authorization': 'Bearer ${base64Encode(utf8.encode(accessKey))}',
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(headers: headers),
      );

      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        final data = res.data ?? const {};
        final parsed = VersionResponse.fromJson(data);
        return parsed.sdkVersion;
      }
      return null;
    } on DioException {
      return null;
    }
  }
}
