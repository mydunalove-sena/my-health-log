import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_health_log/core/widgets/health_summary_card.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/home_mock_state.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_field_visibility_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults every P1-1 health field to visible', () async {
    final service = await _visibilityService();

    expect(service.weightVisible, isTrue);
    expect(service.bloodPressureVisible, isTrue);
    expect(service.waterIntakeVisible, isTrue);
    expect(service.stepsVisible, isTrue);
    expect(service.sleepHoursVisible, isTrue);
    expect(service.conditionVisible, isTrue);
  });

  testWidgets('hides only the selected field UI', (tester) async {
    final visibilityService = await _visibilityService();
    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthFormScreen(
          service: await _healthService(records: [_healthRecord()]),
          healthFieldVisibilityService: visibilityService,
        ),
      ),
    );

    expect(find.byKey(const Key('health-water-field')), findsNothing);
    expect(find.byKey(const Key('health-weight-field')), findsOneWidget);
    expect(find.byKey(const Key('health-steps-field')), findsNothing);
  });

  test('persists field visibility after service reload', () async {
    final service = await _visibilityService();
    await service.setVisible(HealthFieldVisibilityKey.waterIntake, false);

    final reloaded = await _visibilityService();

    expect(reloaded.waterIntakeVisible, isFalse);
    expect(reloaded.weightVisible, isTrue);
  });

  testWidgets('shows a field again after it is re-enabled', (tester) async {
    final visibilityService = await _visibilityService();
    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      false,
    );
    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthFormScreen(
          service: await _healthService(records: [_healthRecord()]),
          healthFieldVisibilityService: visibilityService,
        ),
      ),
    );

    expect(find.byKey(const Key('health-water-field')), findsOneWidget);
  });

  testWidgets('preserves hidden existing field data when editing', (
    tester,
  ) async {
    final record = _healthRecord(waterIntake: 1200);
    final healthService = await _healthService(records: [record]);
    final visibilityService = await _visibilityService();
    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthFormScreen(
          service: healthService,
          record: record,
          healthFieldVisibilityService: visibilityService,
        ),
      ),
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('health-weight-field')),
        matching: find.byType(TextFormField),
      ),
      '55.1',
    );
    await tester.ensureVisible(find.byKey(const Key('health-save-button')));
    await tester.tap(find.byKey(const Key('health-save-button')));
    await tester.pumpAndSettle();

    expect(healthService.records.single.weight, 55.1);
    expect(healthService.records.single.waterIntake, 1200);

    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      true,
    );
    expect(healthService.records.single.waterIntake, 1200);
  });

  testWidgets('filters weight and blood pressure statistics tabs only', (
    tester,
  ) async {
    final visibilityService = await _visibilityService();
    await _pumpStatistics(tester, visibilityService: visibilityService);

    expect(find.widgetWithText(ChoiceChip, '\uCCB4\uC911'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '\uD608\uC555'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '\uAC80\uC0AC'), findsOneWidget);

    await visibilityService.setVisible(HealthFieldVisibilityKey.weight, false);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '\uCCB4\uC911'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '\uD608\uC555'), findsOneWidget);

    await visibilityService.setVisible(
      HealthFieldVisibilityKey.bloodPressure,
      false,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '\uD608\uC555'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '\uAC80\uC0AC'), findsOneWidget);
    expect(
      find.byKey(const Key('statistics-lab-test-dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('keeps visible home health cards and omits legacy steps card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          mockState: const HomeMockState.withData(),
          healthFieldVisibilityService: await _visibilityService(),
        ),
      ),
    );

    expect(find.byType(HealthSummaryCard), findsNWidgets(5));
    expect(find.byKey(const Key('home-weight-card')), findsOneWidget);
    expect(find.byKey(const Key('home-blood-pressure-card')), findsOneWidget);
    expect(find.byKey(const Key('home-water-card')), findsOneWidget);
    expect(find.byKey(const Key('home-steps-card')), findsNothing);
    expect(find.byKey(const Key('home-sleep-card')), findsOneWidget);
    expect(find.byKey(const Key('home-condition-card')), findsOneWidget);
  });
}

Future<HealthFieldVisibilityService> _visibilityService() async {
  final service = HealthFieldVisibilityService();
  await service.load();
  return service;
}

Future<HealthRecordService> _healthService({
  List<HealthRecord>? records,
}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

Future<LabResultService> _labService() async {
  final service = LabResultService(
    InMemoryLabResultStorage([
      LabResult(
        id: 'lab-1',
        date: DateTime(2026, 8, 14),
        testName: '\uC694\uC0B0',
        value: 6.2,
        unit: 'mg/dL',
        createdAt: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
      ),
    ]),
  );
  await service.load();
  return service;
}

Future<void> _pumpStatistics(
  WidgetTester tester, {
  required HealthFieldVisibilityService visibilityService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StatisticsScreen(
        healthRecordService: await _healthService(records: [_healthRecord()]),
        labResultService: await _labService(),
        healthFieldVisibilityService: visibilityService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

HealthRecord _healthRecord({int? waterIntake = 1200}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return HealthRecord(
    id: 'health-1',
    date: today,
    weight: 54.2,
    systolicBloodPressure: 120,
    diastolicBloodPressure: 80,
    waterIntake: waterIntake,
    steps: 6400,
    sleepHours: 6.5,
    condition: HealthCondition.normal,
    createdAt: today,
    updatedAt: today,
  );
}
