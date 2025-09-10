import 'package:flutter/cupertino.dart';

class GLogger {
  static bool enabled = false;

  static void d(String tag, String msg) {
    if (enabled) debugPrint('[$tag] $msg');
  }

  static void e(String tag, Object err, [StackTrace? st]) {
    if (enabled) debugPrint('[$tag][e] $err ${st ?? ''}');
  }
}
