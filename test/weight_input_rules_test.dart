import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/validation/weight_input_rules.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/screens/health/weight_capture_review_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';

void main() {
  group('WeightInputRules formatter', () {
    test('allows ASCII digits, one dot, and up to two decimal places', () {
      for (final text in [
        '51',
        '51.9',
        '51.92',
        '30.25',
        '15',
        '5.25',
        '500',
        '500.0',
        '500.00',
        '51.',
      ]) {
        expect(_format('', text), text);
      }
    });

    test('blocks non-ASCII digits, letters, spaces, and special characters on paste', () {
      for (final text in [
        'abc',
        '한글',
        '日本語',
        '中文',
        '５１.９',
        '51kg',
        '51 kg',
        '51,9',
        '-51',
        '+51',
        '51%',
        '51/9',
        r'51\9',
        '51#9',
        '51@9',
        ' ',
        '51*9',
        '51..9',
        '51.2.3',
        '51.923',
        '51.2345',
      ]) {
        expect(_format('51', text), '51', reason: text);
      }
    });
  });

  group('WeightInputRules range validation', () {
    test('classifies boundary values', () {
      for (final text in ['15', '15.00', '20', '250', '500', '500.00']) {
        expect(
          WeightInputRules.validate(text).status,
          WeightRangeStatus.normal,
          reason: text,
        );
      }
      for (final text in ['0', '14.99', '500.01', '501', '5000']) {
        expect(
          WeightInputRules.validate(text).status,
          WeightRangeStatus.block,
          reason: text,
        );
      }
    });

    test(
      'blocks blank, non-finite, invalid parse, zero, and negative values',
      () {
        expect(WeightInputRules.validate('').status, WeightRangeStatus.block);
        expect(
          WeightInputRules.validate('NaN').status,
          WeightRangeStatus.block,
        );
        expect(
          WeightInputRules.validate('Infinity').status,
          WeightRangeStatus.block,
        );
        expect(
          WeightInputRules.validate('invalid').status,
          WeightRangeStatus.block,
        );
        expect(WeightInputRules.validate('0').status, WeightRangeStatus.block);
        expect(
          WeightInputRules.validateValue(-1).status,
          WeightRangeStatus.block,
        );
        expect(
          WeightInputRules.validateValue(double.nan).status,
          WeightRangeStatus.block,
        );
        expect(
          WeightInputRules.validateValue(double.infinity).status,
          WeightRangeStatus.block,
        );
      },
    );
  });

  group('HealthRecordService weight validation', () {
    test('blocks weights below 15 and allows values from 15 to 500', () async {
      final service = await _healthService();
      final today = DateTime(2026, 9, 15);

      await expectLater(
        service.save(_record(weight: 0, date: today)),
        throwsA(isA<InvalidHealthRecordWeightException>()),
      );
      await expectLater(
        service.save(_record(weight: 14.99, date: today)),
        throwsA(isA<InvalidHealthRecordWeightException>()),
      );
      await expectLater(
        service.save(_record(weight: 500.01, date: today)),
        throwsA(isA<InvalidHealthRecordWeightException>()),
      );

      await service.save(_record(weight: 15, date: today));
      expect(service.records.single.weight, 15);
    });
  });

  group('WeightInputRules screen wiring', () {
    testWidgets('HealthForm and Review share the same formatter instance', (
      tester,
    ) async {
      final service = await _healthService();

      await tester.pumpWidget(
        MaterialApp(home: HealthFormScreen(service: service)),
      );
      final healthField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('health-weight-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        healthField.inputFormatters,
        contains(same(WeightInputRules.formatter)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      final reviewField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('weight-capture-value-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        reviewField.inputFormatters,
        contains(same(WeightInputRules.formatter)),
      );
    });

    testWidgets(
      'Review saves low and high positive values without range warning',
      (tester) async {
        final service = await _healthService();

        await tester.pumpWidget(
          MaterialApp(
            home: WeightCaptureReviewScreen(
              service: service,
              candidate: null,
              initialDate: DateTime(2026, 9, 15),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('weight-capture-value-field')),
          '15',
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('일반적인 범위'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('weight-capture-save-button')),
              )
              .onPressed,
          isNotNull,
        );

        await tester.enterText(
          find.byKey(const Key('weight-capture-value-field')),
          '250.1',
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('일반적인 범위'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('weight-capture-save-button')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('HealthForm blocks out-of-range weight with shared message', (
      tester,
    ) async {
      final service = await _healthService();

      await tester.pumpWidget(
        MaterialApp(home: HealthFormScreen(service: service)),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('health-weight-field')),
          matching: find.byType(TextFormField),
        ),
        '500.01',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-save-button')));
      await tester.pumpAndSettle();

      expect(find.text(WeightInputRules.blockMessage), findsOneWidget);
      expect(service.records, isEmpty);
    });
  });
}

String _format(String oldText, String newText) {
  final result = WeightInputRules.formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    ),
  );
  return result.text;
}

Future<HealthRecordService> _healthService() async {
  final service = HealthRecordService(InMemoryHealthRecordStorage());
  await service.load();
  return service;
}

HealthRecord _record({required double weight, required DateTime date}) {
  final now = DateTime.now();
  return HealthRecord(
    id: 'health-$weight',
    date: date,
    weight: weight,
    createdAt: now,
    updatedAt: now,
  );
}
