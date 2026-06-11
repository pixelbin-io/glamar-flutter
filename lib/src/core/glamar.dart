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

  static void applyBySku(String skuId) {
    final payload = jsonEncode({'skuId': skuId});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyBySku', payload: $payload }, '*');",
    );
  }

  static void applyByCategory(String category) {
    final payload = jsonEncode(category);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyByCategory', payload: $payload }, '*');",
    );
  }

  static void applyBySubCategory(String subCategory) {
    final payload = jsonEncode(subCategory);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyBySubCategory', payload: $payload }, '*');",
    );
  }

  static void applyPatternById(String patternId) {
    final payload = jsonEncode({'patternId': patternId});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyPatternByID', payload: $payload }, '*');",
    );
  }

  static void applyByMultipleConfigData(dynamic config) {
    final serialized = jsonEncode(config);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'applyByMultipleConfigData', payload: $serialized }, '*');",
    );
  }

  static void configChange(String type, num value) {
    final payload = jsonEncode({'type': type, 'value': value});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'onConfigChange', payload: $payload }, '*');",
    );
  }

  static void comparison(String state, List<String> skus) {
    final payload = jsonEncode({'state': state, 'skus': skus});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'comparison', payload: $payload }, '*');",
    );
  }

  static void onNailColorEvents({String? options, dynamic value}) {
    final payload = <String, dynamic>{};
    if (options != null) {
      payload['options'] = options;
    }
    if (value != null) {
      payload['value'] = value;
    }

    final serialized = jsonEncode(payload);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'nailColor', payload: $serialized }, '*');",
    );
  }

  static void addedToCart(String skuId) {
    final payload = jsonEncode(skuId);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'addedToCart', payload: $payload }, '*');",
    );
  }

  static void addedToWishlist(String skuId) {
    final payload = jsonEncode(skuId);
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'addedToWishlist', payload: $payload }, '*');",
    );
  }

  static void open({String? mode, String? imgURL}) {
    if (mode != null && mode.isNotEmpty) {
      final payload = jsonEncode({'mode': mode, 'imgURL': imgURL ?? ''});
      GlamArWebViewManager.evaluateJavascript(
        "window.parent.postMessage({ type: 'openLivePreview', payload: $payload }, '*');",
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

  static void skinAnalysis(String options) {
    final payload = jsonEncode({'options': options});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'skinAnalysis', payload: $payload }, '*');",
    );
  }

  static void eyePD(String options) {
    final payload = jsonEncode({'options': options});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'eyePD', payload: $payload }, '*');",
    );
  }

  static void openUI(String name) {
    final payload = jsonEncode({'name': name});
    GlamArWebViewManager.evaluateJavascript(
      "window.parent.postMessage({ type: 'openUi', payload: $payload }, '*');",
    );
  }
}
