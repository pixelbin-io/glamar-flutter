# GlamAR Flutter SDK

## Overview

The **GlamAR Flutter SDK** provides an easy way to embed GlamAR’s WebView-based Augmented Reality experience inside your Flutter applications. It enables virtual try-on for categories like makeup, jewelry, and eyewear with:

* Real-time AR preview
* Face tracking and analysis
* SKU/category application
* Snapshot support
* Simple Flutter APIs that mirror the native Android SDK

## Features

* Real-time virtual try-on for multiple categories
* Camera and image-based preview modes
* WebView-based rendering (headless preload + visible attach)
* Snapshot functionality
* Configurable parameters (disable back/close, open live on init, etc.)
* Event handling (listen to `init-complete`, `loaded`, and custom events)
* Cross-platform Flutter API surface similar to native Android

## Installation

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  glam_ar_sdk: ^1.0.0
```

Run:

```bash
flutter pub get
```

## Required Permissions

### Android (in `AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS (in `Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR try-on</string>
```

### iOS (in `ios/Podfile`) — Required for `permission_handler` to grant camera:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:glam_ar_sdk/glam_ar_sdk.dart';
import 'package:glam_ar_sdk/src/core/glamar_webview_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlamAr.init(
    accessKey: 'YOUR_ACCESS_KEY', // Replace with your actual key
    debug: true,
  );

  GlamAr.addEventListener('init-complete', (payload) {
    debugPrint('GlamAR SDK Initialized: \$payload');
    GlamAr.applyByCategory('sunglasses');
  });

  GlamAr.addEventListener('loaded', (payload) {
    debugPrint('GlamAR content loaded.');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlamAR Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GlamArScreen(),
    );
  }
}

class GlamArScreen extends StatelessWidget {
  const GlamArScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: GlamArView()),
    );
  }
}

class GlamArView extends StatefulWidget {
  const GlamArView({super.key});

  @override
  State<GlamArView> createState() => _GlamArViewState();
}

class _GlamArViewState extends State<GlamArView> {
  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      headlessWebView: GlamArWebViewManager.getGlamArView(),
      initialSettings: GlamArWebViewManager.platformSettings,
      onWebViewCreated: (controller) {
        GlamArWebViewManager.wireJsBridge(controller);
      },
      onLoadStop: (controller, url) async {
        await GlamArWebViewManager.initPreview();
      },
      onPermissionRequest: (controller, request) async {
        debugPrint('[GlamAR] onPermissionRequest');
        return PermissionResponse(
          action: PermissionResponseAction.GRANT,
          resources: request.resources,
        );
      },
    );
  }
}
```

## API Methods

```dart
GlamAr.applyBySku("SKU_ID");
GlamAr.applyByCategory("sunglasses");
GlamAr.applyByMultipleConfigData({
  "category": "sunglasses",
  "options": {
    "color": "black",
    "lens": "polarized",
  },
});
GlamAr.open(mode: "live");
GlamAr.close();
GlamAr.back();
GlamAr.snapshot();
GlamAr.reset();
```

## Event Handling

```dart
GlamAr.addEventListener('init-complete', (payload) {
  debugPrint('SDK initialized: \$payload');
});

GlamAr.addEventListener('loaded', (payload) {
  debugPrint('SDK content loaded: \$payload');
});

GlamAr.removeEventListener('loaded');
```

## Best Practices

1. Always call `await GlamAr.init(...)` before using any APIs
2. Handle camera/microphone permissions properly (iOS + Android)
3. Add listeners early (`init-complete`, `loaded`)
4. Keep your `accessKey` secure
5. Use `dispose()` on manager if you need to reset/reload the SDK

## Version History

* **1.0.0** (Latest)

  * New Flutter SDK structure
  * Headless WebView preload + attach
  * Added multiple config API

* **1.0.x**

  * Initial Flutter integration

## Support

For support and bug reports, please create an issue in our GitHub repository or contact support at [support@pixelbin.io](mailto:support@pixelbin.io).
