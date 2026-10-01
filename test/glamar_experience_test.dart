import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glam_ar_sdk/glam_ar_sdk.dart';

class _RecordingWebViewController extends Fake
    implements InAppWebViewController {
  final List<String> scripts = [];

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {}

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    scripts.add(source);
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingWebViewController controller;
  late List<MapEntry<String, dynamic>> events;

  setUp(() {
    controller = _RecordingWebViewController();
    GlamArWebViewManager.wireJsBridge(controller);
    events = [];
    for (final type in ['error', 'experience-change-failed']) {
      GlamAr.addEventListener(type, (payload) {
        events.add(MapEntry(type, payload));
      });
    }
  });

  tearDown(() async {
    GlamAr.removeEventListener('error');
    GlamAr.removeEventListener('experience-change-failed');
    await GlamArWebViewManager.dispose();
  });

  Map<String, dynamic> sentPayload() {
    expect(controller.scripts, hasLength(1));
    final script = controller.scripts.single;
    const prefix =
        "window.parent.postMessage({ type: 'setExperience', payload: ";
    const suffix = " }, '*');";
    expect(script, startsWith(prefix));
    expect(script, endsWith(suffix));
    return jsonDecode(
          script.substring(prefix.length, script.length - suffix.length),
        )
        as Map<String, dynamic>;
  }

  group('GlamAr.setExperience', () {
    test('sends the trimmed Skin Analysis appId', () {
      GlamAr.setExperience(
        'skinAnalysis',
        const SkinAnalysisExperienceOptions(appId: ' \tapp-123\n '),
      );

      expect(sentPayload(), {
        'experience': 'skinAnalysis',
        'options': {'appId': 'app-123'},
      });
      expect(events, isEmpty);
    });

    final vtoCases =
        <
          ({
            String name,
            VtoExperienceOptions options,
            Map<String, String> expected,
          })
        >[
          (
            name: 'trims category',
            options: const VtoExperienceOptions(category: ' \teyewear\n'),
            expected: {'category': 'eyewear'},
          ),
          (
            name: 'trims subCategory',
            options: const VtoExperienceOptions(subCategory: ' sunglasses '),
            expected: {'subCategory': 'sunglasses'},
          ),
          (
            name: 'trims skuId',
            options: const VtoExperienceOptions(skuId: ' SKU_1 '),
            expected: {'skuId': 'SKU_1'},
          ),
          (
            name: 'prefers category over subCategory and skuId',
            options: const VtoExperienceOptions(
              category: 'eyewear',
              subCategory: 'sunglasses',
              skuId: 'SKU_1',
            ),
            expected: {'category': 'eyewear'},
          ),
          (
            name: 'skips blank category and prefers subCategory over skuId',
            options: const VtoExperienceOptions(
              category: ' \n\t ',
              subCategory: ' sunglasses ',
              skuId: 'SKU_1',
            ),
            expected: {'subCategory': 'sunglasses'},
          ),
          (
            name: 'skips blank category and subCategory to use skuId',
            options: const VtoExperienceOptions(
              category: '',
              subCategory: ' \n ',
              skuId: ' SKU_1 ',
            ),
            expected: {'skuId': 'SKU_1'},
          ),
        ];

    for (final testCase in vtoCases) {
      test('VTO ${testCase.name}', () {
        GlamAr.setExperience('vto', testCase.options);

        expect(sentPayload(), {
          'experience': 'vto',
          'options': testCase.expected,
        });
        expect(events, isEmpty);
      });
    }

    test('JSON-escapes caller values in the actual WebView command', () {
      const value = 'sku_"quoted"\\path\n\'); alert("test"); //';
      GlamAr.setExperience('vto', const VtoExperienceOptions(skuId: value));

      expect(sentPayload(), {
        'experience': 'vto',
        'options': {'skuId': value},
      });
      expect(controller.scripts.single, isNot(contains('\n')));
      expect(events, isEmpty);
    });

    const skinError = 'SkinAnalysis experience requires a valid appId';
    const vtoError = 'VTO experience requires category, subCategory, or skuId';
    const experienceError = 'Experience must be either vto or skinAnalysis';
    final invalidCases =
        <
          ({
            String name,
            String experience,
            ExperienceOptions options,
            String error,
          })
        >[
          (
            name: 'missing appId',
            experience: 'skinAnalysis',
            options: const SkinAnalysisExperienceOptions(),
            error: skinError,
          ),
          (
            name: 'empty appId',
            experience: 'skinAnalysis',
            options: const SkinAnalysisExperienceOptions(appId: ''),
            error: skinError,
          ),
          (
            name: 'whitespace appId',
            experience: 'skinAnalysis',
            options: const SkinAnalysisExperienceOptions(appId: ' \t\n '),
            error: skinError,
          ),
          (
            name: 'VTO options with Skin Analysis',
            experience: 'skinAnalysis',
            options: const VtoExperienceOptions(category: 'eyewear'),
            error: skinError,
          ),
          (
            name: 'missing VTO selectors',
            experience: 'vto',
            options: const VtoExperienceOptions(),
            error: vtoError,
          ),
          (
            name: 'empty VTO selectors',
            experience: 'vto',
            options: const VtoExperienceOptions(
              category: '',
              subCategory: '',
              skuId: '',
            ),
            error: vtoError,
          ),
          (
            name: 'whitespace VTO selectors',
            experience: 'vto',
            options: const VtoExperienceOptions(
              category: ' ',
              subCategory: '\t',
              skuId: '\n',
            ),
            error: vtoError,
          ),
          (
            name: 'Skin Analysis options with VTO',
            experience: 'vto',
            options: const SkinAnalysisExperienceOptions(appId: 'app-123'),
            error: vtoError,
          ),
          for (final experience in [
            '',
            'other',
            'VTO',
            'skinanalysis',
            ' vto ',
          ])
            (
              name: 'unsupported experience "$experience"',
              experience: experience,
              options: const VtoExperienceOptions(category: 'eyewear'),
              error: experienceError,
            ),
        ];

    for (final testCase in invalidCases) {
      test('rejects ${testCase.name} and emits both failure events', () {
        GlamAr.setExperience(testCase.experience, testCase.options);

        expect(controller.scripts, isEmpty);
        expect(events.map((event) => event.key), [
          'error',
          'experience-change-failed',
        ]);
        expect(events[0].value, {'type': 'error', 'message': testCase.error});
        expect(events[1].value, {
          'experience': testCase.experience,
          'error': testCase.error,
        });
      });
    }
  });
}
