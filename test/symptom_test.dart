import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/health/symptom_record_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  group('Symptom P0-4 service', () {
    test('severity has exactly four fixed levels', () {
      expect(SymptomSeverity.values, hasLength(4));
      expect(SymptomSeverity.values.map((severity) => severity.label), [
        '없음',
        '약함',
        '보통',
        '심함',
      ]);
      expect(SymptomSeverity.values.map((severity) => severity.value), [
        'none',
        'mild',
        'moderate',
        'severe',
      ]);
    });

    test('saves and reads symptom records by date', () async {
      final service = await _symptomService();
      final date = DateTime(2026, 8, 25);

      await service.saveSeverity(
        date: date,
        symptomDefinitionId: 'symptom-headache',
        severity: SymptomSeverity.moderate,
        now: DateTime(2026, 8, 25, 9),
      );

      final records = service.recordsForDate(date);
      expect(records, hasLength(1));
      expect(records.single.symptomDefinitionId, 'symptom-headache');
      expect(records.single.severity, SymptomSeverity.moderate);
      expect(
        service.severityForDateAndSymptom(date, 'symptom-headache'),
        SymptomSeverity.moderate,
      );
    });

    test('same date and same symptom updates without a duplicate', () async {
      final service = await _symptomService();
      final date = DateTime(2026, 8, 25);

      await service.saveSeverity(
        date: date,
        symptomDefinitionId: 'symptom-fatigue',
        severity: SymptomSeverity.mild,
        now: DateTime(2026, 8, 25, 9),
      );
      final originalId = service.recordsForDate(date).single.id;

      await service.saveSeverity(
        date: date,
        symptomDefinitionId: 'symptom-fatigue',
        severity: SymptomSeverity.severe,
        now: DateTime(2026, 8, 25, 10),
      );

      final records = service.recordsForDate(date);
      expect(records, hasLength(1));
      expect(records.single.id, originalId);
      expect(records.single.severity, SymptomSeverity.severe);
    });

    test('different dates are kept separately', () async {
      final service = await _symptomService();
      final firstDate = DateTime(2026, 8, 24);
      final secondDate = DateTime(2026, 8, 25);

      await service.saveSeverity(
        date: firstDate,
        symptomDefinitionId: 'symptom-nausea',
        severity: SymptomSeverity.none,
        now: DateTime(2026, 8, 25, 9),
      );
      await service.saveSeverity(
        date: secondDate,
        symptomDefinitionId: 'symptom-nausea',
        severity: SymptomSeverity.severe,
        now: DateTime(2026, 8, 25, 10),
      );

      expect(
        service.severityForDateAndSymptom(firstDate, 'symptom-nausea'),
        SymptomSeverity.none,
      );
      expect(
        service.severityForDateAndSymptom(secondDate, 'symptom-nausea'),
        SymptomSeverity.severe,
      );
      expect(service.records, hasLength(2));
    });

    test(
      'does not collide with existing health medication and lab services',
      () async {
        final symptomService = await _symptomService();
        final healthService = HealthRecordService(
          InMemoryHealthRecordStorage(),
        );
        final medicationService = MedicationService(
          InMemoryMedicationStorage(),
        );
        final labService = LabResultService(InMemoryLabResultStorage());
        await Future.wait([
          healthService.load(),
          medicationService.load(),
          labService.load(),
        ]);
        final now = DateTime(2026, 8, 25, 9);

        await healthService.save(_healthRecord(now));
        await medicationService.saveMedication(_medication(now));
        await labService.save(_labResult(now));
        await symptomService.saveSeverity(
          date: now,
          symptomDefinitionId: 'symptom-dizziness',
          severity: SymptomSeverity.mild,
          now: now,
        );

        expect(healthService.records, hasLength(1));
        expect(medicationService.activeMedications, hasLength(1));
        expect(labService.results, hasLength(1));
        expect(symptomService.recordsForDate(now), hasLength(1));
      },
    );
  });

  testWidgets('Symptom screen saves and reloads an existing date record', (
    tester,
  ) async {
    final service = await _symptomService();

    await tester.pumpWidget(
      MaterialApp(home: SymptomRecordScreen(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('symptom-severity-symptom-headache')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('심함').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('symptom-save-button')),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('symptom-save-button')));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    expect(
      service.severityForDateAndSymptom(normalizedToday, 'symptom-headache'),
      SymptomSeverity.severe,
    );

    await tester.pumpWidget(
      MaterialApp(home: SymptomRecordScreen(service: service)),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<SymptomSeverity>>(
      find.byKey(const Key('symptom-severity-symptom-headache')),
    );
    expect(dropdown.initialValue, SymptomSeverity.severe);
  });
}

Future<SymptomService> _symptomService() async {
  final service = SymptomService(InMemorySymptomStorage());
  await service.load();
  return service;
}

HealthRecord _healthRecord(DateTime now) {
  return HealthRecord(
    id: 'health',
    date: now,
    weight: 54.2,
    createdAt: now,
    updatedAt: now,
  );
}

Medication _medication(DateTime now) {
  return Medication(
    id: 'med',
    name: '테스트약',
    morning: true,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

LabResult _labResult(DateTime now) {
  return LabResult(
    id: 'lab',
    date: now,
    testName: '테스트',
    value: 1,
    createdAt: now,
    updatedAt: now,
  );
}
