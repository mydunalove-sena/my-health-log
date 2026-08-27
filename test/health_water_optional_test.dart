import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/services/health_field_visibility_service.dart';
import 'package:my_health_log/services/health_record_service.dart';

void main() {
  testWidgets('saves a visible blank water field as null', (tester) async {
    final service = await _healthService();

    await _pumpForm(tester, service: service);
    await _enterNumber(tester, const Key('health-weight-field'), '54.2');
    await _save(tester);

    expect(service.records, hasLength(1));
    expect(service.records.single.weight, 54.2);
    expect(service.records.single.waterIntake, isNull);
  });

  testWidgets('saves a visible water value', (tester) async {
    final service = await _healthService();

    await _pumpForm(tester, service: service);
    await _enterNumber(tester, const Key('health-water-field'), '1500');
    await _save(tester);

    expect(service.records, hasLength(1));
    expect(service.records.single.waterIntake, 1500);
  });

  testWidgets('clears an existing visible water value when the field is emptied', (
    tester,
  ) async {
    final record = _healthRecord(waterIntake: 1500);
    final service = await _healthService(records: [record]);

    await _pumpForm(tester, service: service, record: record);
    await _enterNumber(tester, const Key('health-water-field'), '');
    await _save(tester);

    expect(service.records, hasLength(1));
    expect(service.records.single.waterIntake, isNull);
    expect(service.records.single.weight, 54.2);
  });

  testWidgets('rejects zero water input without treating it as null', (
    tester,
  ) async {
    final service = await _healthService();

    await _pumpForm(tester, service: service);
    await _enterNumber(tester, const Key('health-weight-field'), '54.2');
    await _enterNumber(tester, const Key('health-water-field'), '0');
    await _save(tester);

    expect(service.records, isEmpty);
  });

  testWidgets('preserves an existing water value while the water field is hidden', (
    tester,
  ) async {
    final record = _healthRecord(waterIntake: 1500);
    final service = await _healthService(records: [record]);
    final visibilityService = await _visibilityService();
    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      false,
    );

    await _pumpForm(
      tester,
      service: service,
      record: record,
      visibilityService: visibilityService,
    );
    await _enterNumber(tester, const Key('health-weight-field'), '55.1');
    await _save(tester);

    expect(service.records, hasLength(1));
    expect(service.records.single.weight, 55.1);
    expect(service.records.single.waterIntake, 1500);
  });

  testWidgets('keeps visible blank, visible value, and hidden value distinct', (
    tester,
  ) async {
    final hiddenRecord = _healthRecord(
      id: 'hidden',
      date: DateTime(2026, 8, 25),
      waterIntake: 1500,
    );
    final service = await _healthService(records: [hiddenRecord]);
    final visibilityService = await _visibilityService();

    await _pumpForm(tester, service: service);
    await _enterNumber(tester, const Key('health-weight-field'), '54.2');
    await _save(tester);

    final blankRecord = service.records.firstWhere(
      (record) => record.id != hiddenRecord.id,
    );
    expect(blankRecord.waterIntake, isNull);

    await _pumpForm(tester, service: service);
    await _enterNumber(tester, const Key('health-water-field'), '1600');
    await _save(tester);

    final valueRecord = service.records.firstWhere(
      (record) => record.waterIntake == 1600,
    );
    expect(valueRecord.waterIntake, 1600);

    await visibilityService.setVisible(
      HealthFieldVisibilityKey.waterIntake,
      false,
    );
    await _pumpForm(
      tester,
      service: service,
      record: hiddenRecord,
      visibilityService: visibilityService,
    );
    await _enterNumber(tester, const Key('health-weight-field'), '55.1');
    await _save(tester);

    final preservedRecord = service.records.firstWhere(
      (record) => record.id == hiddenRecord.id,
    );
    expect(preservedRecord.waterIntake, 1500);
    expect(preservedRecord.waterIntake, isNot(blankRecord.waterIntake));
    expect(preservedRecord.waterIntake, isNot(valueRecord.waterIntake));
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required HealthRecordService service,
  HealthRecord? record,
  HealthFieldVisibilityService? visibilityService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HealthFormScreen(
        service: service,
        record: record,
        healthFieldVisibilityService: visibilityService,
      ),
    ),
  );
}

Future<void> _enterNumber(
  WidgetTester tester,
  Key fieldKey,
  String value,
) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(TextFormField),
    ),
    value,
  );
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('health-save-button')));
  await tester.tap(find.byKey(const Key('health-save-button')));
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<HealthRecordService> _healthService({
  List<HealthRecord>? records,
}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

Future<HealthFieldVisibilityService> _visibilityService() async {
  final service = HealthFieldVisibilityService.inMemory();
  await service.load();
  return service;
}

HealthRecord _healthRecord({
  String id = 'health-1',
  DateTime? date,
  int? waterIntake,
}) {
  final now = DateTime.now();
  return HealthRecord(
    id: id,
    date: date ?? DateTime(now.year, now.month, now.day),
    weight: 54.2,
    systolicBloodPressure: 120,
    diastolicBloodPressure: 80,
    waterIntake: waterIntake,
    steps: 6400,
    sleepHours: 6.5,
    condition: HealthCondition.normal,
    createdAt: now,
    updatedAt: now,
  );
}
