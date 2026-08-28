import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/app.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  testWidgets('Statistics screen opens from bottom navigation', (tester) async {
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: await _healthService(),
        medicationService: await _medicationService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('\uD1B5\uACC4'), findsWidgets);
  });

  testWidgets('Weight tab is selected by default', (tester) async {
    await _pumpStatistics(tester);

    expect(find.text('\uCCB4\uC911'), findsOneWidget);
    expect(
      find.textContaining(
        '\uCCB4\uC911 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Weight empty state is shown', (tester) async {
    await _pumpStatistics(tester);

    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    expect(find.text('\uAC74\uAC15 \uAE30\uB85D\uD558\uAE30'), findsOneWidget);
  });

  testWidgets('Weight empty state button opens Health tab', (tester) async {
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: await _healthService(),
        medicationService: await _medicationService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('\uAC74\uAC15 \uAE30\uB85D\uD558\uAE30'));
    await tester.pumpAndSettle();

    expect(find.text('\uAC74\uAC15 \uAE30\uB85D'), findsWidgets);
  });

  testWidgets('Weight one record displays chart and value', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [
        _healthRecord(id: 'h1', date: DateTime(2026, 8, 14), weight: 54.2),
      ],
    );

    expect(find.text('\uCCB4\uC911 \uBCC0\uD654'), findsOneWidget);
    expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    expect(find.text('54.2 kg'), findsOneWidget);
  });

  testWidgets('Weight multiple records are listed newest first', (
    tester,
  ) async {
    await _pumpStatistics(
      tester,
      healthRecords: [
        _healthRecord(id: 'h1', date: DateTime(2026, 8, 1), weight: 55),
        _healthRecord(id: 'h2', date: DateTime(2026, 8, 14), weight: 54.2),
        _healthRecord(id: 'h3', date: DateTime(2026, 8, 10), weight: 54.4),
      ],
    );

    expect(
      tester.getTopLeft(find.text('08.14')).dy,
      lessThan(tester.getTopLeft(find.text('08.10')).dy),
    );
    expect(
      tester.getTopLeft(find.text('08.10')).dy,
      lessThan(tester.getTopLeft(find.text('08.01')).dy),
    );
  });

  testWidgets('Weight date row stays single line on narrow mobile viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpStatistics(
      tester,
      healthRecords: [
        _healthRecord(id: 'h1', date: DateTime(2026, 8, 28), weight: 54.2),
      ],
    );

    final dateTextFinder = find.text('08.28');
    expect(dateTextFinder, findsOneWidget);

    final dateText = tester.widget<Text>(dateTextFinder);
    expect(dateText.maxLines, 1);
    expect(dateText.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weight same values do not crash chart', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [
        _healthRecord(id: 'h1', date: DateTime(2026, 8, 1), weight: 54.2),
        _healthRecord(id: 'h2', date: DateTime(2026, 8, 5), weight: 54.2),
        _healthRecord(id: 'h3', date: DateTime(2026, 8, 10), weight: 54.2),
      ],
    );

    expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weight stats ignore records without weight', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [
        _healthRecord(id: 'h1', weight: null, systolic: 120, diastolic: 80),
      ],
    );

    expect(
      find.textContaining(
        '\uCCB4\uC911 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Blood pressure tab switches from weight', (tester) async {
    await _pumpStatistics(tester);

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '\uD608\uC555 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Blood pressure empty state is shown', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [_healthRecord(id: 'h1', systolic: null, diastolic: null)],
    );

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('\uAC74\uAC15 \uAE30\uB85D\uD558\uAE30'), findsOneWidget);
  });

  testWidgets('Blood pressure shows systolic and diastolic legends', (
    tester,
  ) async {
    await _pumpStatistics(
      tester,
      healthRecords: [_healthRecord(id: 'h1', systolic: 120, diastolic: 80)],
    );

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();

    expect(find.text('\uC218\uCD95\uAE30'), findsOneWidget);
    expect(find.text('\uC774\uC644\uAE30'), findsOneWidget);
  });

  testWidgets('Blood pressure actual numbers are listed', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [_healthRecord(id: 'h1', systolic: 120, diastolic: 80)],
    );

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();

    expect(find.text('120 / 80 mmHg'), findsOneWidget);
  });

  testWidgets('Blood pressure ignores incomplete records', (tester) async {
    await _pumpStatistics(
      tester,
      healthRecords: [_healthRecord(id: 'h1', systolic: 120, diastolic: null)],
    );

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '\uD608\uC555 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Lab tab switches from weight', (tester) async {
    await _pumpStatistics(tester);

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '\uAC80\uC0AC \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Lab empty state is shown', (tester) async {
    await _pumpStatistics(tester);

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    expect(
      find.text('\uAC80\uC0AC \uACB0\uACFC \uAE30\uB85D\uD558\uAE30'),
      findsOneWidget,
    );
  });

  testWidgets('Lab empty state button opens Lab tab', (tester) async {
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: await _healthService(),
        medicationService: await _medicationService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('\uAC80\uC0AC \uACB0\uACFC \uAE30\uB85D\uD558\uAE30'),
    );
    await tester.pumpAndSettle();

    expect(find.text('\uAC80\uC0AC \uACB0\uACFC'), findsWidgets);
  });

  testWidgets('Lab distinct test names appear in selector', (tester) async {
    await _pumpStatistics(
      tester,
      labResults: [
        _labResult(id: 'l1', testName: '\uC911\uC131\uC9C0\uBC29', value: 185),
        _labResult(id: 'l2', testName: '\uC694\uC0B0', value: 6.2),
      ],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('statistics-lab-test-dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('Selected lab test data is displayed', (tester) async {
    await _pumpStatistics(
      tester,
      labResults: [
        _labResult(
          id: 'l1',
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mg/dL',
        ),
      ],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(find.text('\uC911\uC131\uC9C0\uBC29'), findsWidgets);
    expect(find.text('185 mg/dL'), findsOneWidget);
  });

  testWidgets('Lab one record displays a chart', (tester) async {
    await _pumpStatistics(
      tester,
      labResults: [_labResult(id: 'l1', testName: '\uC694\uC0B0', value: 6.2)],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
  });

  testWidgets('Lab multiple records are listed newest first', (tester) async {
    await _pumpStatistics(
      tester,
      labResults: [
        _labResult(
          id: 'l1',
          date: DateTime(2026, 6, 10),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 220,
        ),
        _labResult(
          id: 'l2',
          date: DateTime(2026, 7, 15),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 205,
        ),
        _labResult(
          id: 'l3',
          date: DateTime(2026, 8, 14),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
        ),
      ],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('08.14')).dy,
      lessThan(tester.getTopLeft(find.text('07.15')).dy),
    );
    expect(
      tester.getTopLeft(find.text('07.15')).dy,
      lessThan(tester.getTopLeft(find.text('06.10')).dy),
    );
  });

  testWidgets('Lab unit null displays value without null', (tester) async {
    await _pumpStatistics(
      tester,
      labResults: [
        _labResult(id: 'l1', testName: '\uBE44\uD0C0\uBBBCD', value: 42),
      ],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('Lab mixed units show neutral notice and no chart', (
    tester,
  ) async {
    await _pumpStatistics(
      tester,
      labResults: [
        _labResult(
          id: 'l1',
          date: DateTime(2026, 7, 15),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 205,
          unit: 'mg/dL',
        ),
        _labResult(
          id: 'l2',
          date: DateTime(2026, 8, 14),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mmol/L',
        ),
      ],
    );

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\uAE30\uB85D\uB41C \uB2E8\uC704\uAC00 \uC11C\uB85C \uB2E4\uB985\uB2C8\uB2E4.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('statistics-chart')), findsNothing);
  });

  testWidgets('Health save refreshes weight statistics', (tester) async {
    final healthService = await _healthService();
    await _pumpStatistics(tester, healthService: healthService);

    await healthService.save(
      _healthRecord(id: 'h1', date: DateTime(2026, 8, 14), weight: 54.2),
    );
    await tester.pumpAndSettle();

    expect(find.text('54.2 kg'), findsOneWidget);
  });

  testWidgets('Health delete refreshes weight statistics', (tester) async {
    final healthService = await _healthService(
      records: [_healthRecord(id: 'h1', weight: 54.2)],
    );
    await _pumpStatistics(tester, healthService: healthService);

    await healthService.delete('h1');
    await tester.pumpAndSettle();

    expect(find.text('54.2 kg'), findsNothing);
    expect(
      find.textContaining(
        '\uCCB4\uC911 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Lab save refreshes lab statistics', (tester) async {
    final labService = await _labService();
    await _pumpStatistics(tester, labService: labService);
    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    await labService.save(
      _labResult(id: 'l1', testName: '\uC694\uC0B0', value: 6.2, unit: 'mg/dL'),
    );
    await tester.pumpAndSettle();

    expect(find.text('6.2 mg/dL'), findsOneWidget);
  });

  testWidgets('Lab delete refreshes lab statistics', (tester) async {
    final labService = await _labService(
      results: [_labResult(id: 'l1', testName: '\uC694\uC0B0', value: 6.2)],
    );
    await _pumpStatistics(tester, labService: labService);
    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();

    await labService.delete('l1');
    await tester.pumpAndSettle();

    expect(find.text('6.2'), findsNothing);
    expect(
      find.textContaining(
        '\uAC80\uC0AC \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpStatistics(
  WidgetTester tester, {
  List<HealthRecord>? healthRecords,
  List<LabResult>? labResults,
  HealthRecordService? healthService,
  LabResultService? labService,
}) async {
  final resolvedHealthService =
      healthService ?? await _healthService(records: healthRecords);
  final resolvedLabService =
      labService ?? await _labService(results: labResults);
  await tester.pumpWidget(
    MaterialApp(
      home: StatisticsScreen(
        healthRecordService: resolvedHealthService,
        labResultService: resolvedLabService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<HealthRecordService> _healthService({
  List<HealthRecord>? records,
}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

Future<MedicationService> _medicationService() async {
  final now = DateTime.now();
  final service = MedicationService(
    InMemoryMedicationStorage(
      medications: [
        Medication(
          id: 'med-1',
          name: '\uD0C0\uD06C\uB85C\uBCA8',
          dose: '1\uC815',
          morning: true,
          lunch: false,
          evening: false,
          bedtime: false,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    ),
  );
  await service.load();
  return service;
}

HealthRecord _healthRecord({
  required String id,
  DateTime? date,
  double? weight = 54.2,
  int? systolic = 120,
  int? diastolic = 80,
}) {
  final now = DateTime.now();
  return HealthRecord(
    id: id,
    date: date ?? DateTime(2026, 8, 14),
    weight: weight,
    systolicBloodPressure: systolic,
    diastolicBloodPressure: diastolic,
    waterIntake: 1200,
    steps: 6400,
    sleepHours: 6.5,
    condition: HealthCondition.normal,
    createdAt: now,
    updatedAt: now,
  );
}

LabResult _labResult({
  required String id,
  DateTime? date,
  required String testName,
  required double value,
  String? unit,
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date ?? DateTime(2026, 8, 14),
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}
