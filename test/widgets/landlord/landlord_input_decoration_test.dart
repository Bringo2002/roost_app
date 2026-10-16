import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/landlord/landlord_input_decoration.dart';

void main() {
  group('landlordInputDecoration', () {
    test('uses the label and a filled surface', () {
      final decoration = landlordInputDecoration('Title');

      expect(decoration.labelText, 'Title');
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, AppColors.surfaceContainer);
    });

    test('passes through the optional error text, prefix icon and counter', () {
      const icon = Icon(Icons.home);

      final decoration = landlordInputDecoration(
        'Title',
        errorText: 'Required',
        prefixIcon: icon,
        counterText: '',
      );

      expect(decoration.errorText, 'Required');
      expect(decoration.prefixIcon, icon);
      expect(decoration.counterText, '');
    });

    test('has no error text, prefix icon or counter by default', () {
      final decoration = landlordInputDecoration('Title');

      expect(decoration.errorText, isNull);
      expect(decoration.prefixIcon, isNull);
      expect(decoration.counterText, isNull);
    });

    test('draws the error borders in the destructive color', () {
      final decoration = landlordInputDecoration('Title');

      final error = decoration.errorBorder! as OutlineInputBorder;
      final focusedError = decoration.focusedErrorBorder! as OutlineInputBorder;
      expect(error.borderSide.color, AppColors.destructive);
      expect(focusedError.borderSide.color, AppColors.destructive);
    });
  });
}
