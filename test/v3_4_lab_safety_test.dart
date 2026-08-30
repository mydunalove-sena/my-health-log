import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/lab/lab_result_batch_form_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  group('V3.4 lab batch input safety', () {
    testWidgets(
      'compact viewport keeps full decimal and integer strings while focused',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final labService = await _labService();
        final settings = await _settings(ids: ['bun']);
        await _pumpBatchForm(tester, labService, settings);

        final fieldFinder = find.byKey(const Key('lab-batch-value-bun'));
        expect(fieldFinder, findsOneWidget);
        expect(tester.getSize(fieldFinder).width, greaterThanOrEqualTo(120));

        await tester.tap(fieldFinder);
        await tester.pump();
        final editableFinder = find.descendant(
          of: fieldFinder,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editableFinder).focusNode.hasFocus,
          isTrue,
        );

        const values = [
          '22.3',
          '25.2',
          '1.31',
          '1.37',
          '10.4',
          '6.79',
          '4.51',
          '164',
          '241',
          '292',
        ];
        for (final value in values) {
          await tester.enterText(fieldFinder, value);
          await tester.pump();
          expect(tester.widget<TextField>(fieldFinder).controller!.text, value);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'normal phone viewport does not squeeze a long-unit value row',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final labService = await _labService();
        final settings = await _settings(ids: ['egfr']);
        await _pumpBatchForm(tester, labService, settings);

        final fieldFinder = find.byKey(const Key('lab-batch-value-egfr'));
        await tester.tap(fieldFinder);
        await tester.enterText(fieldFinder, '292');
        await tester.pump();

        expect(tester.widget<TextField>(fieldFinder).controller!.text, '292');
        expect(tester.getSize(fieldFinder).width, greaterThanOrEqualTo(120));
        expect(find.text('mL/min/1.73m²'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('saving 22.3 keeps the same double meaning', (tester) async {
      final labService = await _labService();
      final settings = await _settings(ids: ['bun']);
      await _pumpBatchForm(tester, labService, settings);

      await tester.enterText(
        find.byKey(const Key('lab-batch-value-bun')),
        '22.3',
      );
      await tester.tap(find.byKey(const Key('lab-batch-save-button')));
      await tester.pumpAndSettle();

      expect(labService.results, hasLength(1));
      expect(labService.results.single.testName, 'BUN');
      expect(labService.results.single.value, 22.3);
    });
  });

  group('V3.4 statistics aliases', () {
    testWidgets('canonical HDL name remains canonical', (tester) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-canonical',
            date: DateTime(year, 2, 3),
            testName: 'HDL Cholesterol',
            value: 52,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('HDL Cholesterol'), findsWidgets);
      expect(find.text('52 mg/dL'), findsOneWidget);
    });

    testWidgets('HDL hyphen alias is displayed under canonical name', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-alias',
            date: DateTime(year, 2, 3),
            testName: 'HDL-Cholesterol',
            value: 51,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('HDL Cholesterol'), findsWidgets);
      expect(find.text('HDL-Cholesterol'), findsNothing);
      expect(find.text('51 mg/dL'), findsOneWidget);
    });

    testWidgets('HDL aliases on different dates form one sorted series', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-old',
            date: DateTime(year, 2, 3),
            testName: 'HDL-Cholesterol',
            value: 49,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'hdl-new',
            date: DateTime(year, 8, 11),
            testName: 'HDL Cholesterol',
            value: 55,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('49 mg/dL'), findsOneWidget);
      expect(find.text('55 mg/dL'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('08.11')).dy,
        lessThan(tester.getTopLeft(find.text('02.03')).dy),
      );
      expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    });

    testWidgets('canonical P name remains canonical', (tester) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'p-canonical',
            date: DateTime(year, 2, 3),
            testName: 'P(인)',
            value: 3.4,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('P(인)'), findsWidgets);
      expect(find.text('3.4 mg/dL'), findsOneWidget);
    });

    testWidgets('Inorganic P alias is displayed under P canonical name', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'p-alias',
            date: DateTime(year, 5, 12),
            testName: 'Inorganic P(인)',
            value: 3.6,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('P(인)'), findsWidgets);
      expect(find.text('Inorganic P(인)'), findsNothing);
      expect(find.text('3.6 mg/dL'), findsOneWidget);
    });

    testWidgets('P aliases on different dates form one sorted series', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'p-old',
            date: DateTime(year, 2, 3),
            testName: 'Inorganic P(인)',
            value: 3.1,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'p-new',
            date: DateTime(year, 8, 11),
            testName: 'P(인)',
            value: 3.7,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('3.1 mg/dL'), findsOneWidget);
      expect(find.text('3.7 mg/dL'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('08.11')).dy,
        lessThan(tester.getTopLeft(find.text('02.03')).dy),
      );
    });

    testWidgets('alias series keeps selected-year filtering', (tester) async {
      final currentYear = DateTime.now().year;
      final previousYear = currentYear - 1;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-prev',
            date: DateTime(previousYear, 12, 20),
            testName: 'HDL-Cholesterol',
            value: 44,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'hdl-current',
            date: DateTime(currentYear, 5, 12),
            testName: 'HDL Cholesterol',
            value: 54,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('54 mg/dL'), findsOneWidget);
      expect(find.text('44 mg/dL'), findsNothing);

      await tester.tap(find.byKey(const Key('statistics-lab-year-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(previousYear.toString()).last);
      await tester.pumpAndSettle();

      expect(find.text('44 mg/dL'), findsOneWidget);
      expect(find.text('54 mg/dL'), findsNothing);
    });

    testWidgets('all alias results are retained without a recent-N limit', (
      tester,
    ) async {
      final year = DateTime.now().year;
      final results = <LabResult>[
        for (var i = 0; i < 12; i++)
          _labResult(
            id: 'hdl-$i',
            date: DateTime(year, 1, i + 1),
            testName: i.isEven ? 'HDL Cholesterol' : 'HDL-Cholesterol',
            value: 40 + i.toDouble(),
            unit: 'mg/dL',
          ),
      ];
      await _pumpStatistics(tester, labResults: results);
      await _openLabTab(tester);

      for (var i = 0; i < 12; i++) {
        expect(find.text('${40 + i} mg/dL'), findsOneWidget);
      }
    });

    testWidgets('exact-name Creatinine BUN and Tacrolimus stay unchanged', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'bun',
            date: DateTime(year, 2, 3),
            testName: 'BUN',
            value: 22.3,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'creatinine',
            date: DateTime(year, 2, 3),
            testName: 'Creatinine',
            value: 1.31,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'tacrolimus',
            date: DateTime(year, 2, 3),
            testName: 'Tacrolimus',
            value: 4.6,
            unit: 'ng/mL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('22.3 mg/dL'), findsOneWidget);
      await _selectLabTest(tester, 'Creatinine');
      expect(find.text('1.31 mg/dL'), findsOneWidget);
      await _selectLabTest(tester, 'Tacrolimus');
      expect(find.text('4.6 ng/mL'), findsOneWidget);
    });

    testWidgets('custom names are not merged by punctuation similarity', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'custom-space',
            date: DateTime(year, 2, 3),
            testName: 'Custom Test',
            value: 1,
          ),
          _labResult(
            id: 'custom-hyphen',
            date: DateTime(year, 5, 12),
            testName: 'Custom-Test',
            value: 2,
          ),
        ],
      );
      await _openLabTab(tester);

      await tester.tap(find.byKey(const Key('statistics-lab-test-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Custom Test'), findsWidgets);
      expect(find.text('Custom-Test'), findsWidgets);
    });

    testWidgets('merged aliases keep the existing mixed-unit policy', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-mg',
            date: DateTime(year, 2, 3),
            testName: 'HDL Cholesterol',
            value: 52,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'hdl-mmol',
            date: DateTime(year, 5, 12),
            testName: 'HDL-Cholesterol',
            value: 1.4,
            unit: 'mmol/L',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('기록된 단위가 서로 다릅니다.'), findsOneWidget);
      expect(find.byKey(const Key('statistics-chart')), findsNothing);
      expect(find.text('52 mg/dL'), findsOneWidget);
      expect(find.text('1.4 mmol/L'), findsOneWidget);
    });

    testWidgets('same-date aliases preserve both stored results', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-a',
            date: DateTime(year, 5, 12),
            testName: 'HDL Cholesterol',
            value: 52,
            unit: 'mg/dL',
          ),
          _labResult(
            id: 'hdl-b',
            date: DateTime(year, 5, 12),
            testName: 'HDL-Cholesterol',
            value: 53,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('52 mg/dL'), findsOneWidget);
      expect(find.text('53 mg/dL'), findsOneWidget);
      expect(find.text('05.12'), findsNWidgets(2));
      expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    });

    testWidgets('explicit aliases allow trim and case-insensitive comparison', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await _pumpStatistics(
        tester,
        labResults: [
          _labResult(
            id: 'hdl-case',
            date: DateTime(year, 2, 3),
            testName: '  hDl-ChOlEsTeRoL  ',
            value: 50,
            unit: 'mg/dL',
          ),
        ],
      );
      await _openLabTab(tester);

      expect(find.text('HDL Cholesterol'), findsWidgets);
      expect(find.text('50 mg/dL'), findsOneWidget);
    });
  });
}

Future<void> _pumpBatchForm(
  WidgetTester tester,
  LabResultService labService,
  LabTestSettingsService settings,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabResultBatchFormScreen(
        labResultService: labService,
        labTestSettingsService: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpStatistics(
  WidgetTester tester, {
  required List<LabResult> labResults,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StatisticsScreen(
        healthRecordService: await _healthService(),
        labResultService: await _labService(results: labResults),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openLabTab(WidgetTester tester) async {
  await tester.tap(find.text('검사').first);
  await tester.pumpAndSettle();
}

Future<void> _selectLabTest(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('statistics-lab-test-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<LabTestSettingsService> _settings({required List<String> ids}) async {
  final service = LabTestSettingsService.inMemory();
  await service.load();
  await service.setEnabledLabTestIds(ids);
  return service;
}

Future<HealthRecordService> _healthService() async {
  final service = HealthRecordService(InMemoryHealthRecordStorage());
  await service.load();
  return service;
}

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

LabResult _labResult({
  required String id,
  required DateTime date,
  required String testName,
  required double value,
  String? unit,
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date,
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}
