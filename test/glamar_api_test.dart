import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:glam_ar_sdk/src/net/glamar_api.dart';

void main() {
  group('GlamArApi.getVersion', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late GlamArApi api;

    setUp(() {
      dio = Dio();
      dioAdapter = DioAdapter(dio: dio);
      api = GlamArApi(accessKey: 'test_key', dio: dio);
    });

    test('constructs query without appId if null', () async {
      const path = '/service/private/misc/v3.0/sdk-settings/version';

      dioAdapter.onGet(
        path,
        (server) => server.reply(200, {'sdkVersion': '1.2.3'}),
      );

      final version = await api.getVersion();
      expect(version, '1.2.3');
    });

    test('constructs query without appId if empty string', () async {
      const path = '/service/private/misc/v3.0/sdk-settings/version';

      dioAdapter.onGet(
        path,
        (server) => server.reply(200, {'sdkVersion': '1.2.3'}),
      );

      final version = await api.getVersion(appId: '   ');
      expect(version, '1.2.3');
    });

    test('constructs query with appId if provided', () async {
      const basePath = '/service/private/misc/v3.0/sdk-settings/version';
      const appId = 'app-123-xyz';

      // The DioAdapter expects the exact path match if query parameters are appended to the path string manually
      // in our implementation of `glamar_api.dart`.
      final fullPath = '$basePath?appId=$appId';

      dioAdapter.onGet(
        fullPath,
        (server) => server.reply(200, {'sdkVersion': '2.0.0'}),
      );

      final version = await api.getVersion(appId: appId);
      expect(version, '2.0.0');
    });

    test('returns null on DioException', () async {
      const path = '/service/private/misc/v3.0/sdk-settings/version';

      dioAdapter.onGet(
        path,
        (server) => server.throws(
          404,
          DioException(
            requestOptions: RequestOptions(path: path),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      final version = await api.getVersion();
      expect(version, isNull);
    });
  });
}
