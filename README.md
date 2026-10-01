# GlamAR Flutter SDK

## Overview

The **GlamAR Flutter SDK** provides an easy way to embed GlamAR’s WebView-based Augmented Reality experience inside your Flutter applications. It enables virtual try-on for categories like makeup, jewelry, and eyewear with:

- Real-time AR preview
- Face tracking and analysis
- SKU/category application
- Snapshot support
- Simple Flutter APIs that mirror the native Android SDK

## Features

- Real-time virtual try-on for multiple categories
- Camera and image-based preview modes
- WebView-based rendering (headless preload + visible attach)
- Snapshot functionality
- Configurable parameters (disable back/close, open live on init, etc.)
- Event handling (listen to `init-complete`, `loaded`, and custom events)
- Cross-platform Flutter API surface similar to native Android

## SDK version lookup

The SDK checks the version using only the Fynd GlamAR endpoint:
`https://api.glamar.fynd.com/service/private/glamar/v3.0/sdk-settings/version`.
For Skin Analysis, it includes the configured `appId`. If this request fails or returns no usable version, initialization uses `overrides.meta.sdkVersion` when provided, otherwise `1.0.0`.

## Installation

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  glam_ar_sdk: ^3.0.0
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

    //required for skin analysis.
    overrides: GlamAROverrides(
      configuration: {
        'skinAnalysis': {
          'appId': 'YOUR_SKIN_ANALYSIS_APP_ID',
        },
      },
    ),
  );

  GlamAr.addEventListener('init-complete', (payload) {
    debugPrint('GlamAR SDK Initialized: \$payload');
    GlamAr.applyByCategory('eyewear');
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
GlamAr.applyByCategory("eyewear");
GlamAr.applyByCategory("eyewear", {"storeFront": "store_a"});
GlamAr.applyBySubCategory("sunglasses");
GlamAr.applyBySubCategory("sunglasses", {"storeFront": "store_a"});
GlamAr.applyByMultipleConfigData({
  "category": "sunglasses",
  "options": {
    "color": "black",
    "lens": "polarized",
  },
});
GlamAr.configChange("opacity", value: 0.5);
GlamAr.configChange(
  "opacity",
  value: 0.5,
  skuId: "SKU_1",
  subCategory: "lipstick",
);
GlamAr.setViewportMirrored(true);
GlamAr.setViewportMirrored(false);
GlamAr.open(mode: "live");
GlamAr.close();
GlamAr.back();
GlamAr.snapshot();
GlamAr.reset();
GlamAr.reset("sunglasses");
GlamAr.reset({
  "subCategory": "sunglasses",
  "skuIds": ["SKU_1", "SKU_2"],
});
```

## Switching experiences

After SDK initialization, use `GlamAr.setExperience` to switch experiences:

```dart
import 'package:glam_ar_sdk/glam_ar_sdk.dart';

GlamAr.setExperience(
  'vto',
  const VtoExperienceOptions(category: 'eyewear'),
);
GlamAr.setExperience(
  'vto',
  const VtoExperienceOptions(subCategory: 'sunglasses'),
);
GlamAr.setExperience(
  'vto',
  const VtoExperienceOptions(skuId: 'SKU_ID'),
);
GlamAr.setExperience(
  'skinAnalysis',
  const SkinAnalysisExperienceOptions(appId: 'YOUR_SKIN_ANALYSIS_APP_ID'),
);
```

Experience names are case-sensitive: `vto` and `skinAnalysis`. Option values are
trimmed. Skin Analysis requires a nonblank `appId`. VTO requires at least one
nonblank selector; when several are supplied, only the first is sent in this
order: `category`, `subCategory`, `skuId`.

Invalid input (including an option type that does not match the experience)
sends no WebView command. It emits an `error` event with `{type: 'error',
message: ...}` and an `experience-change-failed` event with `{experience: ...,
error: ...}`. Register listeners before calling the method:

```dart
GlamAr.addEventListener('experience-change-failed', (payload) {
  debugPrint('Experience ${payload['experience']} failed: ${payload['error']}');
});
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

- **3.0.0** (Unreleased)
  - Added `setExperience` with typed VTO and Skin Analysis options
  - SDK version checks use only the private Fynd GlamAR API
  - Upgrade existing `^1.x` dependency constraints to `^3.0.0` to adopt this version

- **1.0.2**
  - Security patch: Fixed unsafe JSON string evaluation blocks
  - Fixed `getVersion` URL construction

- **1.0.1**
  - Added `applyBySubCategory` method
  - Added version changes for skin analysis

- **1.0.0**
  - New Flutter SDK structure
  - Headless WebView preload + attach
  - Added multiple config API

- **1.0.x**
  - Initial Flutter integration

## Support

For support and bug reports, please create an issue in our GitHub repository or contact support at [support@glamar.io](mailto:support@glamar.io).
