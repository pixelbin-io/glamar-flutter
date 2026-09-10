import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:glam_ar_sdk/src/net/glamar_api.dart';
import 'package:glam_ar_sdk/src/net/model/version_api_response.dart';

void main() {
  group('GlamArApi.getVersion', () {
    const primaryUrl =
        'https://api.glamar.fynd.com/service/private/glamar/v3.0/sdk-settings/version';
    const fallbackUrl =
        'https://api.pixelbin.io/service/private/misc/v3.0/sdk-settings/version';

    late Dio dio;
    late DioAdapter dioAdapter;
    late GlamArApi api;
    late List<RequestOptions> requests;

    void recordRequests() {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
    }

    setUp(() {
      dio = Dio();
      dioAdapter = DioAdapter(dio: dio);
      api = GlamArApi(accessKey: 'test_key', dio: dio);
      requests = [];
      recordRequests();
    });

    tearDown(() => dio.close(force: true));

    List<String> requestedUrls() =>
        requests.map((request) => request.uri.toString()).toList();

    for (final appId in <String?>[null, '', '   ']) {
      test('uses only GlamAR and omits blank appId: "$appId"', () async {
        dioAdapter.onGet(
          primaryUrl,
          (server) => server.reply(200, {'sdkVersion': '1.2.3'}),
        );

        expect(await api.getVersion(appId: appId), '1.2.3');
        expect(requestedUrls(), [primaryUrl]);
      });
    }

    for (final status in [401, 403, 404, 500, 503]) {
      test('falls back to PixelBin after HTTP $status', () async {
        dioAdapter.onGet(primaryUrl, (server) => server.reply(status, {}));
        dioAdapter.onGet(
          fallbackUrl,
          (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
        );

        expect(await api.getVersion(), '2.0.0');
        expect(requestedUrls(), [primaryUrl, fallbackUrl]);
      });
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('falls back to PixelBin after $type', () async {
        dioAdapter.onGet(
          primaryUrl,
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: primaryUrl),
              type: type,
            ),
          ),
        );
        dioAdapter.onGet(
          fallbackUrl,
          (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
        );

        expect(await api.getVersion(), '2.0.0');
        expect(requestedUrls(), [primaryUrl, fallbackUrl]);
      });
    }

    test('preserves encoded appId and signs each host independently', () async {
      const appId = 'skin analysis/a+b&c=?';
      final query = '?appId=${Uri.encodeQueryComponent(appId)}';
      dioAdapter.onGet('$primaryUrl$query', (server) => server.reply(500, {}));
      dioAdapter.onGet(
        '$fallbackUrl$query',
        (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
      );

      expect(await api.getVersion(appId: '  $appId  '), '2.0.0');
      expect(requestedUrls(), ['$primaryUrl$query', '$fallbackUrl$query']);
      for (final request in requests) {
        expect(request.uri.queryParameters, {'appId': appId});
        expect(
          request.headers['Authorization'],
          'Bearer ${base64Encode(utf8.encode('test_key'))}',
        );
        expect(request.headers['host'], request.uri.host);
        expect(request.headers['x-ebg-param'], isNotEmpty);
        expect(request.headers['x-ebg-signature'], startsWith('v1:'));
      }
      expect(
        requests.first.headers['x-ebg-signature'],
        isNot(requests.last.headers['x-ebg-signature']),
      );
    });

    test('returns null when both endpoints fail', () async {
      dioAdapter.onGet(primaryUrl, (server) => server.reply(500, {}));
      dioAdapter.onGet(fallbackUrl, (server) => server.reply(503, {}));

      expect(await api.getVersion(), isNull);
      expect(requestedUrls(), [primaryUrl, fallbackUrl]);
    });

    test('returns null when fallback also has a transport failure', () async {
      dioAdapter.onGet(primaryUrl, (server) => server.reply(500, {}));
      dioAdapter.onGet(
        fallbackUrl,
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: fallbackUrl),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      expect(await api.getVersion(), isNull);
      expect(requestedUrls(), [primaryUrl, fallbackUrl]);
    });

    test('falls back even if injected Dio accepts error statuses', () async {
      dio.options.validateStatus = (_) => true;
      dioAdapter.onGet(primaryUrl, (server) => server.reply(500, {}));
      dioAdapter.onGet(
        fallbackUrl,
        (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
      );

      expect(await api.getVersion(), '2.0.0');
      expect(requestedUrls(), [primaryUrl, fallbackUrl]);
    });

    test(
      'leaves missing-version fallback to the caller like the web SDK',
      () async {
        dioAdapter.onGet(primaryUrl, (server) => server.reply(200, {}));

        expect(await api.getVersion(), isNull);
        expect(requestedUrls(), [primaryUrl]);
      },
    );

    test(
      'uses the primary host override and keeps the fallback private',
      () async {
        dio.interceptors.clear();
        api = GlamArApi(
          accessKey: 'test_key',
          development: true,
          dio: dio,
          apiBaseUrlOverride: 'https://primary.example',
        );
        recordRequests();
        const overriddenUrl =
            'https://primary.example/service/private/glamar/v3.0/sdk-settings/version';
        dioAdapter.onGet(overriddenUrl, (server) => server.reply(500, {}));
        dioAdapter.onGet(
          fallbackUrl,
          (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
        );

        expect(api.apiBaseUrl, 'https://primary.example');
        expect(await api.getVersion(), '2.0.0');
        expect(requestedUrls(), [overriddenUrl, fallbackUrl]);
      },
    );

    test('reports both HTTP responses in request order', () async {
      final responses = <VersionApiResponse>[];
      dioAdapter.onGet(
        primaryUrl,
        (server) => server.reply(401, {'message': 'Access denied'}),
      );
      dioAdapter.onGet(
        fallbackUrl,
        (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
      );
      expect(await api.getVersion(onResponse: responses.add), '2.0.0');
      expect(responses.map((response) => response.url), [
        primaryUrl,
        fallbackUrl,
      ]);
      expect(responses.first.statusCode, 401);
      expect(responses.first.body, {'message': 'Access denied'});
      expect(responses.first.error, contains('badResponse'));
      expect(responses.last.statusCode, 200);
      expect(responses.last.body, {'sdkVersion': '2.0.0'});
      expect(responses.last.error, isNull);
    });

    test(
      'reports transport failures without fabricating HTTP responses',
      () async {
        final responses = <VersionApiResponse>[];
        dioAdapter.onGet(
          primaryUrl,
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: primaryUrl),
              type: DioExceptionType.connectionTimeout,
              message: 'Timed out',
            ),
          ),
        );
        dioAdapter.onGet(
          fallbackUrl,
          (server) => server.reply(503, 'Service unavailable'),
        );
        expect(await api.getVersion(onResponse: responses.add), isNull);
        expect(responses, hasLength(2));
        expect(responses.first.statusCode, isNull);
        expect(responses.first.body, isNull);
        expect(responses.first.error, startsWith('connectionTimeout:'));
        expect(responses.last.statusCode, 503);
        expect(responses.last.body, 'Service unavailable');
      },
    );

    for (final body in <Object>[
      'Unexpected response',
      {'sdkVersion': 123},
    ]) {
      test('retains unexpected response body for inspection: $body', () async {
        final responses = <VersionApiResponse>[];
        dioAdapter.onGet(primaryUrl, (server) => server.reply(200, body));
        expect(await api.getVersion(onResponse: responses.add), isNull);
        expect(responses, hasLength(1));
        expect(responses.single.statusCode, 200);
        expect(responses.single.body, body);
        expect(requestedUrls(), [primaryUrl]);
      });
    }

    test('diagnostics callback errors do not change version lookup', () async {
      dioAdapter.onGet(
        primaryUrl,
        (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
      );
      expect(
        await api.getVersion(
          onResponse: (_) {
            throw StateError('UI disposed');
          },
        ),
        '2.0.0',
      );
      expect(requestedUrls(), [primaryUrl]);
    });
  });
}
