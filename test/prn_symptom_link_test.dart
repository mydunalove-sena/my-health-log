import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/screens/medication/prn_medication_log_form_screen.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  group('PRN symptom links', () {
    test('PRN log can be saved without symptoms', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);

      await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        now: DateTime(2026, 8, 26, 10),
      );

      expect(await service.allPrnLogsForTest(), hasLength(1));
      expect(await service.allPrnSymptomLinksForTest(), isEmpty);
    });

    test('PRN log can be linked to one symptom', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);

      final log = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache'],
        now: DateTime(2026, 8, 26, 10),
      );

      expect(service.symptomDefinitionIdsForPrnLog(log.id), [
        'symptom-headache',
      ]);
    });

    test('PRN log can be linked to multiple symptoms', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);

      final log = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache', 'symptom-dizziness'],
        now: DateTime(2026, 8, 26, 10),
      );

      expect(service.symptomDefinitionIdsForPrnLog(log.id), [
        'symptom-dizziness',
        'symptom-headache',
      ]);
    });

    test('duplicate symptom IDs do not create duplicate links', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);

      final log = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: [
          'symptom-headache',
          'symptom-headache',
          ' symptom-headache ',
        ],
        now: DateTime(2026, 8, 26, 10),
      );

      expect(service.symptomDefinitionIdsForPrnLog(log.id), [
        'symptom-headache',
      ]);
      expect(await service.allPrnSymptomLinksForTest(), hasLength(1));
    });

    test('links for different PRN logs are not mixed', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);

      final first = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache'],
        now: DateTime(2026, 8, 26, 10),
      );
      final second = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 11),
        symptomDefinitionIds: ['symptom-dizziness'],
        now: DateTime(2026, 8, 26, 12),
      );

      expect(service.symptomDefinitionIdsForPrnLog(first.id), [
        'symptom-headache',
      ]);
      expect(service.symptomDefinitionIdsForPrnLog(second.id), [
        'symptom-dizziness',
      ]);
    });

    test('saving links does not create or edit symptom records', () async {
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
      );
      final symptomService = await _symptomService();

      await medicationService.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache'],
        now: DateTime(2026, 8, 26, 10),
      );

      expect(symptomService.records, isEmpty);
    });

    test('links survive service reload', () async {
      final medication = _prnMedication();
      final storage = InMemoryMedicationStorage(medications: [medication]);
      final service = MedicationService(storage);
      await service.load(date: DateTime(2026, 8, 26));

      final log = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache'],
        now: DateTime(2026, 8, 26, 10),
      );

      final reloaded = MedicationService(storage);
      await reloaded.load(date: DateTime(2026, 8, 26));

      expect(reloaded.symptomDefinitionIdsForPrnLog(log.id), [
        'symptom-headache',
      ]);
    });

    test('deleting a PRN log deletes its links', () async {
      final medication = _prnMedication();
      final service = await _medicationService(medications: [medication]);
      final log = await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 26, 9),
        symptomDefinitionIds: ['symptom-headache'],
        now: DateTime(2026, 8, 26, 10),
      );

      await service.deletePrnLog(log.id);

      expect(await service.allPrnLogsForTest(), isEmpty);
      expect(await service.allPrnSymptomLinksForTest(), isEmpty);
    });

    test('legacy PRN logs without links are still readable', () async {
      final medication = _prnMedication();
      final log = _prnLog(medicationId: medication.id);
      final service = await _medicationService(
        medications: [medication],
        prnLogs: [log],
        date: log.date,
      );

      expect(service.prnLogsForMedication(medication.id), hasLength(1));
      expect(service.symptomDefinitionIdsForPrnLog(log.id), isEmpty);
    });
  });

  group('PRN symptom link UI', () {
    testWidgets('form shows optional related symptoms', (tester) async {
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
      );
      final symptomService = await _symptomService();

      await tester.pumpWidget(
        MaterialApp(
          home: PrnMedicationLogFormScreen(
            service: medicationService,
            medication: medication,
            symptomService: symptomService,
          ),
        ),
      );

      expect(find.byKey(const Key('prn-related-symptoms')), findsOneWidget);
      expect(find.text('관련 증상 (선택)'), findsOneWidget);
    });

    testWidgets('form allows selecting multiple symptoms', (tester) async {
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
      );
      final symptomService = await _symptomService();

      await tester.pumpWidget(
        MaterialApp(
          home: PrnMedicationLogFormScreen(
            service: medicationService,
            medication: medication,
            symptomService: symptomService,
          ),
        ),
      );

      final headache = find.byKey(const Key('prn-symptom-symptom-headache'));
      final dizziness = find.byKey(const Key('prn-symptom-symptom-dizziness'));
      await tester.ensureVisible(headache);
      await tester.pumpAndSettle();
      await tester.tap(headache);
      await tester.pumpAndSettle();
      await tester.ensureVisible(dizziness);
      await tester.pumpAndSettle();
      await tester.tap(dizziness);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('prn-save-button')));
      await tester.tap(find.byKey(const Key('prn-save-button')));
      await tester.pumpAndSettle();

      expect(await medicationService.allPrnSymptomLinksForTest(), hasLength(2));
    });

    testWidgets('form saves without selecting symptoms', (tester) async {
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
      );
      final symptomService = await _symptomService();

      await tester.pumpWidget(
        MaterialApp(
          home: PrnMedicationLogFormScreen(
            service: medicationService,
            medication: medication,
            symptomService: symptomService,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('prn-save-button')));
      await tester.tap(find.byKey(const Key('prn-save-button')));
      await tester.pumpAndSettle();

      expect(await medicationService.allPrnLogsForTest(), hasLength(1));
      expect(await medicationService.allPrnSymptomLinksForTest(), isEmpty);
    });

    testWidgets('linked symptom names appear on PRN record display', (
      tester,
    ) async {
      final testDate = DateTime(2026, 8, 26, 9);
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
        date: testDate,
      );
      final symptomService = await _symptomService();
      await medicationService.recordPrnTaken(
        medication: medication,
        takenAt: testDate,
        symptomDefinitionIds: ['symptom-headache', 'symptom-dizziness'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationScreen(
            service: medicationService,
            symptomService: symptomService,
          ),
        ),
      );

      expect(find.text('관련 증상: 두통 · 어지러움'), findsOneWidget);
    });

    testWidgets(
      'older linked PRN log remains visible after unlinked latest log',
      (tester) async {
        final medication = _prnMedication();
        final medicationService = await _medicationService(
          medications: [medication],
        );
        final symptomService = await _symptomService();

        final olderLog = await medicationService.recordPrnTaken(
          medication: medication,
          takenAt: DateTime(2026, 8, 26, 2, 16),
          symptomDefinitionIds: ['symptom-headache', 'symptom-dizziness'],
          now: DateTime(2026, 8, 26, 2, 16, 30),
        );
        final latestLog = await medicationService.recordPrnTaken(
          medication: medication,
          takenAt: DateTime(2026, 8, 26, 2, 22),
          now: DateTime(2026, 8, 26, 2, 22, 30),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MedicationScreen(
              service: medicationService,
              symptomService: symptomService,
            ),
          ),
        );

        expect(find.text('오늘 2회 복용 · 02:22'), findsOneWidget);
        expect(
          find.byKey(ValueKey('prn-log-entry-${latestLog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('prn-log-time-${latestLog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('prn-log-detail-${latestLog.id}')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('prn-log-entry-${olderLog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('prn-log-time-${olderLog.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('prn-log-detail-${olderLog.id}')),
          findsOneWidget,
        );
        expect(find.text('관련 증상: 두통 · 어지러움'), findsOneWidget);
        expect(
          medicationService.symptomDefinitionIdsForPrnLog(latestLog.id),
          isEmpty,
        );
        expect(medicationService.symptomDefinitionIdsForPrnLog(olderLog.id), [
          'symptom-dizziness',
          'symptom-headache',
        ]);
      },
    );
  });
}

Future<MedicationService> _medicationService({
  List<Medication>? medications,
  List<PrnMedicationLog>? prnLogs,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(medications: medications, prnLogs: prnLogs),
  );
  await service.load(date: date ?? DateTime(2026, 8, 26));
  return service;
}

Future<SymptomService> _symptomService() async {
  final service = SymptomService(
    InMemorySymptomStorage(definitions: _symptomDefinitions()),
  );
  await service.load();
  return service;
}

List<SymptomDefinition> _symptomDefinitions() {
  final now = DateTime(2026, 8, 26);
  return [
    SymptomDefinition(
      id: 'symptom-headache',
      name: '두통',
      isDefault: true,
      isActive: true,
      sortOrder: 10,
      createdAt: now,
      updatedAt: now,
    ),
    SymptomDefinition(
      id: 'symptom-dizziness',
      name: '어지러움',
      isDefault: true,
      isActive: true,
      sortOrder: 20,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

Medication _prnMedication() {
  final now = DateTime(2026, 8, 26, 8);
  return Medication(
    id: 'prn-med',
    name: 'PRN 약',
    type: MedicationType.prn,
    morning: false,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

PrnMedicationLog _prnLog({required String medicationId}) {
  final now = DateTime(2026, 8, 26, 9);
  return PrnMedicationLog(
    id: 'legacy-prn-log',
    medicationId: medicationId,
    date: DateTime(2026, 8, 26),
    takenAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
