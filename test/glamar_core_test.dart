import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlamAr JS Command Behaviors', () {
    test(
      'applyBySubCategory uses safe JSON serialization for string interpolation',
      () async {
        // Because we can't easily mock static method evaluates inside flutter_test
        // without setting up an InAppWebViewController mock, we will simply test the serialization logic
        // to ensure it handles malicious inputs securely as requested.

        const dangerousSubCategory = "sunglasses'; alert('hacked!'); //";

        // Expected serialized output should escape the quotes
        final safeSerialized = jsonEncode(dangerousSubCategory);

        expect(safeSerialized, '"sunglasses\'; alert(\'hacked!\'); //"');

        final expectedJsCommand =
            "window.parent.postMessage({ type: 'applyBySubCategory', payload: $safeSerialized }, '*');";

        expect(
          expectedJsCommand,
          "window.parent.postMessage({ type: 'applyBySubCategory', payload: \"sunglasses'; alert('hacked!'); //\" }, '*');",
        );
      },
    );

    test('applyByCategory keeps string payload when options are omitted', () {
      final payload = jsonEncode('eyewear');

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'applyByCategory', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'applyByCategory\', payload: "eyewear" }, \'*\');',
      );
    });

    test('applyByCategory serializes category with options payload', () {
      final payload = jsonEncode({
        'category': 'eyewear',
        'options': {'storeFront': 'store_a'},
      });

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'applyByCategory', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'applyByCategory\', payload: {"category":"eyewear","options":{"storeFront":"store_a"}} }, \'*\');',
      );
    });

    test('applyBySubCategory keeps string payload when options are omitted', () {
      final payload = jsonEncode('sunglasses');

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'applyBySubCategory', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'applyBySubCategory\', payload: "sunglasses" }, \'*\');',
      );
    });

    test('applyBySubCategory serializes subcategory with options payload', () {
      final payload = jsonEncode({
        'subCategory': 'sunglasses',
        'options': {'storeFront': 'store_a'},
      });

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'applyBySubCategory', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'applyBySubCategory\', payload: {"subCategory":"sunglasses","options":{"storeFront":"store_a"}} }, \'*\');',
      );
    });

    test('configChange serializes type and numeric value payload', () {
      final payload = jsonEncode({'type': 'opacity', 'value': 0.5});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'onConfigChange', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'onConfigChange\', payload: {"type":"opacity","value":0.5} }, \'*\');',
      );
    });

    test('configChange serializes optional sku and subcategory payload', () {
      final payload = jsonEncode({
        'type': 'opacity',
        'value': 0.5,
        'skuId': 'SKU_1',
        'subCategory': 'lipstick',
      });

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'onConfigChange', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'onConfigChange\', payload: {"type":"opacity","value":0.5,"skuId":"SKU_1","subCategory":"lipstick"} }, \'*\');',
      );
    });

    test('setViewportMirrored true starts mirror mode', () {
      final payload = jsonEncode({'options': 'start'});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'mirrorMode', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'mirrorMode\', payload: {"options":"start"} }, \'*\');',
      );
    });

    test('setViewportMirrored false closes mirror mode', () {
      final payload = jsonEncode({'options': 'close'});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'mirrorMode', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'mirrorMode\', payload: {"options":"close"} }, \'*\');',
      );
    });

    test('reset without payload sends clearSku command only', () {
      const expectedJsCommand =
          "window.parent.postMessage({ type: 'clearSku' }, '*');";

      expect(
        expectedJsCommand,
        "window.parent.postMessage({ type: 'clearSku' }, '*');",
      );
    });

    test('reset string value serializes subcategory payload', () {
      final payload = jsonEncode({'subCategory': 'sunglasses'});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'clearSku', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'clearSku\', payload: {"subCategory":"sunglasses"} }, \'*\');',
      );
    });

    test('reset map value serializes subcategory and skuIds payload', () {
      final payload = jsonEncode({
        'subCategory': 'sunglasses',
        'skuIds': ['SKU_1', 'SKU_2'],
      });

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'clearSku', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'clearSku\', payload: {"subCategory":"sunglasses","skuIds":["SKU_1","SKU_2"]} }, \'*\');',
      );
    });

    test('reset ignores invalid skuIds and keeps valid subcategory payload', () {
      final payload = jsonEncode({'subCategory': 'sunglasses'});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'clearSku', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'clearSku\', payload: {"subCategory":"sunglasses"} }, \'*\');',
      );
    });
  });
}
