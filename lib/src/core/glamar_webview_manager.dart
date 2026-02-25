import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../net/glamar_api.dart';
import '../utils/logger.dart';
import 'glamar.dart';

class GlamAROverrides {
  final Map<String, dynamic>? meta;
  final String? category;
  final Map<String, dynamic>? configuration;

  GlamAROverrides({this.meta, this.category, this.configuration});
}

class GlamArWebViewManager {
  static HeadlessInAppWebView? _headless;
  static InAppWebViewController? _controller;
  static final String _baseUrl = 'https://cdn.glamar.io/sdk';

  static bool _debug = false;
  static String _accessKey = '';
  static GlamAROverrides? _overrides;
  static String _applicationId = '';

  static final ValueNotifier<bool> headlessReady = ValueNotifier(false);
  static final ValueNotifier<bool> isInitCompleted = ValueNotifier(false);

  static final InAppWebViewSettings _settingsIos = InAppWebViewSettings(
    javaScriptEnabled: true,
    transparentBackground: true,
    allowsInlineMediaPlayback: true,
    allowsAirPlayForMediaPlayback: true,
  );

  static final InAppWebViewSettings _settingsAndroid = InAppWebViewSettings(
    javaScriptEnabled: true,
    useHybridComposition: true,
    transparentBackground: true,
    mediaPlaybackRequiresUserGesture: false,
  );

  static InAppWebViewSettings get platformSettings =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _settingsIos
      : _settingsAndroid;

  /// PREPARE: fetch version FIRST, then create+load headless with the final URL.
  static Future<void> prepareWebView({
    required String accessKey,
    bool debug = false,
    GlamAROverrides? overrides,
  }) async {
    _accessKey = accessKey;
    _debug = debug;
    _overrides = overrides;

    headlessReady.value = false;
    isInitCompleted.value = false;
    GLogger.enabled = debug;
    final info = await PackageInfo.fromPlatform();
    _applicationId = info.packageName;

    // 1) resolve version BEFORE creating headless
    final api = GlamArApi(accessKey: accessKey, enableCurlLogging: _debug);

    String? fetched;
    try {
      final appId = _overrides?.configuration?['skinAnalysis']?['appId']
          ?.toString();
      fetched = await api.getVersion(appId: appId);
    } catch (e, st) {
      if (_debug) GLogger.e('GlamAr', e, st);
    }

    final metaVersion = _overrides?.meta?['sdkVersion']?.toString();
    final version = fetched?.isNotEmpty == true
        ? fetched!
        : (metaVersion?.isNotEmpty == true ? metaVersion! : '1.0.0');

    final finalUrl = '$_baseUrl/v$version';

    // 2) now create headless with the FINAL URL (no temp)
    await _headless?.dispose();
    _headless = HeadlessInAppWebView(
      initialSettings: platformSettings,
      initialUrlRequest: URLRequest(url: WebUri(finalUrl)),
    );

    await _headless!.run();
    if (_debug) GLogger.d('GlamAr', 'Headless run with $finalUrl');
  }

  static void wireJsBridge(InAppWebViewController ctrl) {
    _controller = ctrl;
    ctrl.addJavaScriptHandler(
      handlerName: 'onLog',
      callback: (args) {
        try {
          if (args.isEmpty) return null;
          final Map<String, dynamic> obj = (args.first is String)
              ? jsonDecode(args.first)
              : Map<String, dynamic>.from(args.first);
          final type = (obj['type'] as String?) ?? 'unknown';
          if (_debug && type != 'error') GLogger.d('GlamAr', 'event: $type');
          GlamAr.onJsEvent(type, obj);
          if (type.toLowerCase() == 'initcomplete') {
            isInitCompleted.value = true;
          }
        } catch (e, st) {
          if (_debug) GLogger.e('GlamAr', e, st);
        }
        return null;
      },
    );
  }

  /// make public so visible view can call if needed
  static Future<void> initPreview() async {
    final payload = <String, dynamic>{
      'apiKey': _accessKey,
      'platform': 'flutter',
      'parentDomain': _applicationId,
    };
    if (_overrides?.category != null) {
      payload['category'] = _overrides!.category;
    }
    if (_overrides?.configuration != null) {
      payload['configuration'] = _overrides!.configuration;
    }

    if (_overrides?.meta != null) {
      payload['meta'] = _overrides!.meta;
    }

    final js =
        '''
      window.parent.postMessage({
        type: 'initialize',
        payload: ${jsonEncode(payload)}
      }, '*');
    ''';
    if (_debug) GLogger.d('GlamAr', 'eval initialize');
    await _controller?.evaluateJavascript(source: js);
    headlessReady.value = true;
  }

  static Future<void> evaluateJavascript(String js) async {
    if (_debug) GLogger.d('GlamAr', 'eval: $js');
    await _controller?.evaluateJavascript(source: js);
  }

  static HeadlessInAppWebView? getGlamArView() => _headless;

  static Future<void> dispose({bool reloadAgain = false}) async {
    await _headless?.dispose();
    _headless = null;
    _controller = null;
    headlessReady.value = false;
    isInitCompleted.value = false;
    if (reloadAgain) {
      await prepareWebView(
        accessKey: _accessKey,
        debug: _debug,
        overrides: _overrides,
      );
    }
  }
}
