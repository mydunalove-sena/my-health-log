import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release keeps ML Kit OCR internals for real-device OCR', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();

    expect(rules, contains('-keep class com.google.mlkit.** { *; }'));
    expect(
      rules,
      contains('-keep class com.google.android.gms.internal.mlkit_** { *; }'),
    );
    expect(
      rules,
      contains(
        '-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }',
      ),
    );
  });
}
