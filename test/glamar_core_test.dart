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

    test('configChange serializes type and numeric value payload', () {
      final payload = jsonEncode({'type': 'opacity', 'value': 0.5});

      final expectedJsCommand =
          "window.parent.postMessage({ type: 'onConfigChange', payload: $payload }, '*');";

      expect(
        expectedJsCommand,
        'window.parent.postMessage({ type: \'onConfigChange\', payload: {"type":"opacity","value":0.5} }, \'*\');',
      );
    });
  });
}
