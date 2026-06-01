import 'package:flutter/foundation.dart';

/// Debug-only logger. The body runs inside an `assert`, so in release builds
/// the closure — and the string literals it builds — are removed entirely by
/// the Dart compiler (assert statements are stripped). This keeps diagnostic
/// tag strings out of the shipped binary.
void hubLog(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}
