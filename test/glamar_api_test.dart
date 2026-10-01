import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:glam_ar_sdk/src/net/glamar_api.dart';
import 'package:glam_ar_sdk/src/net/model/version_api_response.dart';

void main() {
  group('GlamArApi.getVersion', () {
    const versionUrl =
        'https://api.glamar.fynd.com/service/private/glamar/v3.0/sdk-settings/version';

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
      test('uses only Fynd GlamAR and omits blank appId: "$appId"', () async {
        dioAdapter.onGet(
          versionUrl,
          (server) => server.reply(200, {'sdkVersion': '1.2.3'}),
        );

        expect(await api.getVersion(appId: appId), '1.2.3');
        expect(requestedUrls(), [versionUrl]);
      });
    }

    for (final status in [401, 403, 404, 429, 500, 503]) {
      test('returns null after HTTP $status without another request', () async {
        dioAdapter.onGet(versionUrl, (server) => server.reply(status, {}));

        expect(await api.getVersion(), isNull);
        expect(requestedUrls(), [versionUrl]);
      });
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('returns null after $type without another request', () async {
        dioAdapter.onGet(
          versionUrl,
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: versionUrl),
              type: type,
            ),
          ),
        );

        expect(await api.getVersion(), isNull);
        expect(requestedUrls(), [versionUrl]);
      });
    }

    test(
      'preserves encoded appId, authorization, and Fynd host signing',
      () async {
        const appId = 'skin analysis/a+b&c=?';
        final url = '$versionUrl?appId=${Uri.encodeQueryComponent(appId)}';
        dioAdapter.onGet(
          url,
          (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
        );

        expect(await api.getVersion(appId: '  $appId  '), '2.0.0');
        expect(requestedUrls(), [url]);
        final request = requests.single;
        expect(request.uri.queryParameters, {'appId': appId});
        expect(
          request.headers['Authorization'],
          'Bearer ${base64Encode(utf8.encode('test_key'))}',
        );
        expect(request.headers['host'], 'api.glamar.fynd.com');
        expect(request.headers['x-ebg-param'], isNotEmpty);
        expect(request.headers['x-ebg-signature'], startsWith('v1:'));
      },
    );

    test(
      'does not retry even if injected Dio accepts error statuses',
      () async {
        dio.options.validateStatus = (_) => true;
        dioAdapter.onGet(versionUrl, (server) => server.reply(500, {}));

        expect(await api.getVersion(), isNull);
        expect(requestedUrls(), [versionUrl]);
      },
    );

    test('leaves missing-version handling to the caller', () async {
      dioAdapter.onGet(versionUrl, (server) => server.reply(200, {}));

      expect(await api.getVersion(), isNull);
      expect(requestedUrls(), [versionUrl]);
    });

    for (final status in [200, 503]) {
      test(
        'uses only the host override with a private path: HTTP $status',
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
          dioAdapter.onGet(
            overriddenUrl,
            (server) => server.reply(status, {'sdkVersion': '2.0.0'}),
          );

          expect(api.apiBaseUrl, 'https://primary.example');
          expect(await api.getVersion(), status == 200 ? '2.0.0' : isNull);
          expect(requestedUrls(), [overriddenUrl]);
        },
      );
    }

    for (final status in [200, 401]) {
      test('reports the single HTTP $status response', () async {
        final responses = <VersionApiResponse>[];
        final body = status == 200
            ? {'sdkVersion': '2.0.0'}
            : {'message': 'Access denied'};
        dioAdapter.onGet(versionUrl, (server) => server.reply(status, body));

        expect(
          await api.getVersion(onResponse: responses.add),
          status == 200 ? '2.0.0' : isNull,
        );
        expect(requestedUrls(), [versionUrl]);
        expect(responses, hasLength(1));
        expect(responses.single.url, versionUrl);
        expect(responses.single.statusCode, status);
        expect(responses.single.body, body);
        expect(
          responses.single.error,
          status == 200 ? isNull : contains('badResponse'),
        );
      });
    }

    test(
      'reports transport failure without fabricating an HTTP response',
      () async {
        final responses = <VersionApiResponse>[];
        dioAdapter.onGet(
          versionUrl,
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: versionUrl),
              type: DioExceptionType.connectionTimeout,
            ),
          ),
        );

        expect(await api.getVersion(onResponse: responses.add), isNull);
        expect(requestedUrls(), [versionUrl]);
        expect(responses, hasLength(1));
        expect(responses.single.url, versionUrl);
        expect(responses.single.statusCode, isNull);
        expect(responses.single.body, isNull);
        expect(responses.single.error, startsWith('connectionTimeout:'));
      },
    );

    for (final body in <Object>[
      'Unexpected response',
      {'sdkVersion': 123},
    ]) {
      test('retains unexpected response body for inspection: $body', () async {
        final responses = <VersionApiResponse>[];
        dioAdapter.onGet(versionUrl, (server) => server.reply(200, body));

        expect(await api.getVersion(onResponse: responses.add), isNull);
        expect(responses, hasLength(1));
        expect(responses.single.statusCode, 200);
        expect(responses.single.body, body);
        expect(requestedUrls(), [versionUrl]);
      });
    }

    test('diagnostics callback errors do not change version lookup', () async {
      dioAdapter.onGet(
        versionUrl,
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
      expect(requestedUrls(), [versionUrl]);
    });
  });
}
