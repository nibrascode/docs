import 'dart:io';
import 'package:docspro/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings version matches pubspec', () {
    final m = RegExp(r'^version:\s*([\d.]+)', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(kAppVersion, m!.group(1));
  });
}
