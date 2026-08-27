import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/health/symptom_management_screen.dart';
import 'package:my_health_log/screens/health/symptom_record_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/screens/medication/prn_medication_log_form_screen.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  group('P1-3 symptom definition management', () {
    test('adds a user symptom definition after existing sort order', () async {
      final service = await _symptomService();
      final now = DateTime(2026, 8, 27, 9);

      final definition = await service.addUserDefinition('  목통증  ', now: now);

      expect(definition.id, 'symptom-user-${now.microsecondsSinceEpoch}');
      expect(definition.name, '목통증');
      expect(definition.isDefault, isFalse);
      expect(definition.isActive, isTrue);
      expect(definition.sortOrder, 30);
      expect(definition.createdAt, now);
      expect(definition.updatedAt, now);
      expect(service.definitions.last.id, definition.id);
    });

    test('rejects blank user symptom names', () async {
      final service = await _symptomService();

      expect(
        () => service.addUserDefinition(''),
        throwsA(isA<EmptySymptomDefinitionNameException>()),
      );
      expect(
        () => service.addUserDefinition('   '),
        throwsA(isA<EmptySymptomDefinitionNameException>()),
      );
      expect(service.definitions, hasLength(2));
    });

    test('rejects duplicate user symptom names', () async {
      final service = await _symptomService();

      expect(
        () => service.addUserDefinition('두통'),
        throwsA(isA<DuplicateSymptomDefinitionNameException>()),
      );
      expect(service.definitions, hasLength(2));
    });

    test('renames a user symptom while preserving id and metadata', () async {
      final service = await _symptomService();
      final createdAt = DateTime(2026, 8, 27, 9);
      final updatedAt = DateTime(2026, 8, 27, 10);
      final original = await service.addUserDefinition(
        '목통증',
        now: createdAt,
      );

      final renamed = await service.renameUserDefinition(
        original.id,
        '  목 통증  ',
        now: updatedAt,
      );

      expect(renamed.id, original.id);
      expect(renamed.name, '목 통증');
      expect(renamed.isDefault, original.isDefault);
      expect(renamed.isActive, original.isActive);
      expect(renamed.sortOrder, original.sortOrder);
      expect(renamed.createdAt, original.createdAt);
      expect(renamed.updatedAt, updatedAt);
    });

    test('rejects default symptom rename', () async {
      final service = await _symptomService();

      expect(
        () => service.renameUserDefinition('symptom-headache', '머리통증'),
        throwsA(isA<DefaultSymptomDefinitionRenameException>()),
      );
      expect(service.definitionById('symptom-headache')?.name, '두통');
    });

    test('rejects duplicate rename except current name', () async {
      final service = await _symptomService();
      final definition = await service.addUserDefinition('목통증');

      final same = await service.renameUserDefinition(
        definition.id,
        '목통증',
      );
      expect(same.name, '목통증');

      expect(
        () => service.renameUserDefinition(definition.id, '피로'),
        throwsA(isA<DuplicateSymptomDefinitionNameException>()),
      );
      expect(service.definitionById(definition.id)?.name, '목통증');
    });

    testWidgets('management screen adds and renames a user symptom', (
      tester,
    ) async {
      final service = await _symptomService();

      await tester.pumpWidget(
        MaterialApp(home: SymptomManagementScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('symptom-definition-edit-symptom-headache')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('symptom-definition-name-field')),
        '목통증',
      );
      await tester.tap(find.byKey(const Key('symptom-definition-add-button')));
      await tester.pumpAndSettle();

      final userDefinition = service.definitions.singleWhere(
        (definition) => definition.name == '목통증',
      );
      expect(
        find.byKey(ValueKey('symptom-definition-${userDefinition.id}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey('symptom-definition-edit-${userDefinition.id}')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('symptom-definition-rename-field')),
        '목 통증',
      );
      await tester.tap(
        find.byKey(const Key('symptom-definition-rename-save-button')),
      );
      await tester.pumpAndSettle();

      expect(service.definitionById(userDefinition.id)?.name, '목 통증');
      expect(find.text('목 통증'), findsOneWidget);
    });

    testWidgets('additional symptom appears and saves severity', (
      tester,
    ) async {
      final service = await _symptomService();
      final definition = await service.addUserDefinition('목통증');

      await tester.pumpWidget(
        MaterialApp(home: SymptomRecordScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('symptom-card-${definition.id}')),
        findsOneWidget,
      );

      final dropdown = find.byKey(ValueKey('symptom-severity-${definition.id}'));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('심함').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('symptom-save-button')));
      await tester.tap(find.byKey(const Key('symptom-save-button')));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      expect(
        service.severityForDateAndSymptom(normalizedToday, definition.id),
        SymptomSeverity.severe,
      );
    });

    testWidgets('rename preserves symptom record and shows the new name', (
      tester,
    ) async {
      final service = await _symptomService();
      final definition = await service.addUserDefinition('목통증');
      final date = DateTime(2026, 8, 27);
      await service.saveSeverity(
        date: date,
        symptomDefinitionId: definition.id,
        severity: SymptomSeverity.severe,
        now: DateTime(2026, 8, 27, 10),
      );
      final recordId = service.recordsForDate(date).single.id;

      await service.renameUserDefinition(definition.id, '목 통증');

      final record = service.recordsForDate(date).single;
      expect(record.id, recordId);
      expect(record.symptomDefinitionId, definition.id);
      expect(record.severity, SymptomSeverity.severe);

      await tester.pumpWidget(
        MaterialApp(home: SymptomRecordScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('목 통증'), findsOneWidget);
    });

    testWidgets('additional symptom appears in PRN related symptom selection', (
      tester,
    ) async {
      final symptomService = await _symptomService();
      final definition = await symptomService.addUserDefinition('목통증');
      final medication = _prnMedication();
      final medicationService = await _medicationService(
        medications: [medication],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PrnMedicationLogFormScreen(
            service: medicationService,
            medication: medication,
            symptomService: symptomService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('prn-symptom-${definition.id}')),
        findsOneWidget,
      );
      expect(find.text('목통증'), findsOneWidget);
    });

    testWidgets('rename preserves PRN link and shows the new name', (
      tester,
    ) async {
      final symptomService = await _symptomService();
      final definition = await symptomService.addUserDefinition('목통증');
      final medication = _prnMedication();
      final testDate = DateTime(2026, 8, 27, 9);
      final medicationService = await _medicationService(
        medications: [medication],
        date: testDate,
      );
      final log = await medicationService.recordPrnTaken(
        medication: medication,
        takenAt: testDate,
        symptomDefinitionIds: [definition.id],
        now: DateTime(2026, 8, 27, 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationScreen(
            service: medicationService,
            symptomService: symptomService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('목통증'), findsOneWidget);

      await symptomService.renameUserDefinition(definition.id, '목 통증');
      await tester.pumpAndSettle();

      expect(medicationService.symptomDefinitionIdsForPrnLog(log.id), [
        definition.id,
      ]);
      expect(find.textContaining('목 통증'), findsOneWidget);
      expect(find.textContaining('목통증'), findsNothing);
    });

    test('user-added and renamed definitions survive service reload', () async {
      final storage = InMemorySymptomStorage(definitions: _definitions());
      final service = SymptomService(storage);
      await service.load();
      final definition = await service.addUserDefinition('목통증');
      await service.renameUserDefinition(definition.id, '목 통증');

      final reloaded = SymptomService(storage);
      await reloaded.load();

      expect(reloaded.definitionById(definition.id)?.name, '목 통증');
      expect(reloaded.definitionById(definition.id)?.isDefault, isFalse);
    });
  });
}

Future<SymptomService> _symptomService() async {
  final service = SymptomService(
    InMemorySymptomStorage(definitions: _definitions()),
  );
  await service.load();
  return service;
}

Future<MedicationService> _medicationService({
  required List<Medication> medications,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(medications: medications),
  );
  await service.load(date: date ?? DateTime(2026, 8, 27));
  return service;
}

List<SymptomDefinition> _definitions() {
  final now = DateTime(2026, 8, 27);
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
      id: 'symptom-fatigue',
      name: '피로',
      isDefault: true,
      isActive: true,
      sortOrder: 20,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

Medication _prnMedication() {
  final now = DateTime(2026, 8, 27, 8);
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
