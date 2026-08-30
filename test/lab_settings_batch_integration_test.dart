import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/lab/lab_result_batch_form_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_field_visibility_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  testWidgets('batch screen shows enabled definitions only', (tester) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatch(tester, labService, settings);

    expect(find.text('Creatinine'), findsOneWidget);
    expect(find.text('BUN'), findsNothing);
    expect(find.byKey(const Key('lab-batch-value-creatinine')), findsOneWidget);
    expect(find.byKey(const Key('lab-batch-value-bun')), findsNothing);
  });

  testWidgets('custom enabled definition appears in batch with default unit', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = LabTestSettingsService.inMemory();
    await settings.load();
    final custom = await settings.addCustomDefinition(
      displayName: 'CRP',
      defaultUnit: 'mg/L',
    );
    await settings.setEnabledLabTestIds([custom.id]);

    await _pumpBatch(tester, labService, settings);

    expect(find.text('CRP'), findsOneWidget);
    expect(find.text('mg/L'), findsOneWidget);
    expect(find.byKey(Key('lab-batch-value-${custom.id}')), findsOneWidget);
  });

  testWidgets('batch screen reflects setting changes on next entry', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine', 'bun']);

    await _pumpBatch(tester, labService, settings);
    expect(find.text('BUN'), findsOneWidget);

    await settings.setEnabledLabTestIds(['creatinine']);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpBatch(tester, labService, settings);

    expect(find.text('Creatinine'), findsOneWidget);
    expect(find.text('BUN'), findsNothing);
  });

  testWidgets('disabled existing lab result remains in list and detail', (
    tester,
  ) async {
    final date = _today();
    final labService = await _labService(
      results: [
        _result(
          id: 'lab-wbc',
          date: date,
          testName: 'WBC',
          value: 5.5,
          unit: '×10³/µL',
        ),
      ],
    );
    final settings = await _settings(ids: ['creatinine']);

    await tester.pumpWidget(
      MaterialApp(
        home: LabScreen(service: labService, labTestSettingsService: settings),
      ),
    );

    expect(find.text('WBC'), findsOneWidget);
    expect(find.text('5.5 ×10³/µL'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('lab-group-${LabResult.formatDateKey(date)}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lab-result-lab-wbc')), findsOneWidget);
    expect(find.text('WBC'), findsOneWidget);
    expect(labService.results.single.testName, 'WBC');
  });

  testWidgets('disabled existing lab result remains in statistics', (
    tester,
  ) async {
    final labService = await _labService(
      results: [
        _result(id: 'lab-wbc', testName: 'WBC', value: 5.5, unit: '×10³/µL'),
      ],
    );
    final healthService = HealthRecordService(InMemoryHealthRecordStorage());
    await healthService.load();
    final visibility = HealthFieldVisibilityService.inMemory();
    await visibility.load();

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          healthRecordService: healthService,
          labResultService: labService,
          healthFieldVisibilityService: visibility,
          onOpenHealth: () {},
          onOpenLab: () {},
        ),
      ),
    );
    await tester.tap(find.text('검사'));
    await tester.pumpAndSettle();

    expect(find.text('WBC'), findsWidgets);
    expect(find.textContaining('5.5'), findsWidgets);
  });
}

Future<void> _pumpBatch(
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

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

Future<LabTestSettingsService> _settings({required List<String> ids}) async {
  final service = LabTestSettingsService.inMemory();
  await service.load();
  await service.setEnabledLabTestIds(ids);
  return service;
}

LabResult _result({
  required String id,
  DateTime? date,
  required String testName,
  required double value,
  String? unit,
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date ?? _today(),
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
