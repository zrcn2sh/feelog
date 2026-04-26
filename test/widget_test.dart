import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feelog_app/main.dart';

void main() {
  test('AppColors primary color is stable', () {
    expect(AppColors.primary, const Color(0xFF8B5CF6));
  });
}
