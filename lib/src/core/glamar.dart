import 'dart:convert';

import 'glamar_webview_manager.dart';

class GlamAr {
  GlamAr._(this.accessKey);

  static GlamAr? _instance;

  final String accessKey;

  /// Initialize once (mirrors Android GlamAr.init)
  static Future<GlamAr> init({
    required String accessKey,
    bool debug = false,
    GlamAROverrides? overrides,
  }) async {
    _instance ??= GlamAr._(accessKey);

    await GlamArWebViewManager.prepareWebView(
      accessKey: accessKey,
      debug: debug,
      overrides: overrides,
    );
    return _instance!;
  }

  static GlamAr get instance {
    final inst = _instance;
    if (inst == null) {
      throw Exception('GlamAr not initialized. Call GlamAr.init() first.');
    }
    return inst;
  }

  // Simple event bus (align with Android event manager)
  static final Map<String, List<void Function(dynamic)>> _listeners = {};

  static void addEventListener(String event, void Function(dynamic) cb) {
    _listeners.putIfAbsent(event, () => []).add(cb);
  }

  static void addEventListeners(
    List<MapEntry<String, void Function(dynamic)>> entries,
  ) {
    for (final e in entries) {
      addEventListener(e.key, e.value);
    }
  }

  static void removeEventListener(String event) {
    _listeners.remove(event);
  }

  static void _dispatch(String type, dynamic payload) {
    final list = _listeners[type];
    if (list == null) return;
    for (final cb in List.of(list)) {
      cb(payload);
    }
  }

  // Called by WebView bridge when JS sends an event
  static void onJsEvent(String type, dynamic payload) =>
      _dispatch(type, payload);

  // ---- Public JS command helpers (names mirror Android) ----

  static void applyBySku(
    String skuId,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'applyBySku', payload: { skuId: '$skuId' } }, '*');",
  );

  static void applyByCategory(
    String category,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'applyByCategory', payload: '$category' }, '*');",
  );

  static void applyBySubCategory(
    String subCategory,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'applyBySubCategory', payload: '$subCategory' }, '*');",
  );

  static void applyPatternById(
    String patternId,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'applyPatternByID', payload: { patternId: '$patternId' } }, '*');",
  );

  static void applyByMultipleConfigData(dynamic config) {
    final serialized = jsonEncode(config);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyByMultipleConfigData', payload: $serialized }, '*');",
    );
  }

  static void addedToCart(
    String skuId,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'addedToCart', payload: '$skuId' }, '*');",
  );

  static void addedToWishlist(
    String skuId,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'addedToWishlist', payload: '$skuId' }, '*');",
  );

  static void open({String? mode, String? imgURL}) {
    if (mode != null && mode.isNotEmpty) {
      GlamArWebViewManager.evaluateJavascript(
        "window.parent.postMessage({ type: 'openLivePreview', payload: { mode: '$mode', imgURL: '${imgURL ?? ''}' } }, '*');",
      );
    } else {
      GlamArWebViewManager.evaluateJavascript(
        "window.parent.postMessage({ type: 'openLivePreview' }, '*');",
      );
    }
  }

  static void close() => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'closePreview' }, '*');",
  );

  static void back() => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'backPreview' }, '*');",
  );

  static void snapshot() => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'snapshot' }, '*');",
  );

  static void reset() => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'clearSku' }, '*');",
  );

  static void skinAnalysis(
    String options,
  ) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'skinAnalysis', payload: { options: '$options' } }, '*');",
  );

  static void eyePD(String options) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'eyePD', payload: { options: '$options' } }, '*');",
  );

  static void openUI(String name) => GlamArWebViewManager.evaluateJavascript(
    "window.parent.postMessage({ type: 'openUi', payload: { name: '$name' } }, '*');",
  );
}
