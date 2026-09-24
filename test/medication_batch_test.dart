import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/medication_service.dart';

final past = DateTime(2026, 9, 10);
final now = DateTime(2026, 9, 24, 15, 37);

void main() {
  group('scheduled snapshot correction', () {
    test('new single correction refuses an existing row instead of silently editing it', () async {
      final med = medication('a');
      final original = logFor(med);
      final storage = InMemoryMedicationStorage(
        medications: [med],
        logs: [original],
      );
      await expectLater(
        MedicationService(storage).saveScheduledCorrection(
          medication: med,
          date: past,
          timeSlot: original.timeSlot,
          isTaken: false,
          now: now,
        ),
        throwsA(isA<DuplicateMedicationLogException>()),
      );
      expect((await storage.fetchAllLogs()).single.toMap(), original.toMap());
      await expectLater(
        storage.upsertMedicationLog(
          original.copyWith(id: 'new-id'),
          insertOnly: true,
        ),
        throwsA(isA<DuplicateMedicationLogException>()),
      );
      expect((await storage.fetchAllLogs()).single.toMap(), original.toMap());
    });

    test(
      'slot change with no target row is rejected and creates nothing',
      () async {
        final med = medication('a');
        final original = logFor(med);
        final storage = InMemoryMedicationStorage(
          medications: [med],
          logs: [original],
        );
        await expectLater(
          MedicationService(storage).saveScheduledCorrection(
            medication: med,
            existingLog: original,
            date: past,
            timeSlot: MedicationTimeSlot.evening,
            isTaken: true,
            takenAt: DateTime(2026, 9, 10, 21),
            now: now,
          ),
          throwsArgumentError,
        );
        expect((await storage.fetchAllLogs()).single.toMap(), original.toMap());
      },
    );
    test(
      'existing edit rejects slot change without touching either row',
      () async {
        final med = medication('a');
        final original = logFor(med);
        final other = original.copyWith(
          id: 'other',
          timeSlot: MedicationTimeSlot.evening,
        );
        final storage = InMemoryMedicationStorage(
          medications: [med],
          logs: [original, other],
        );
        final service = MedicationService(storage);
        await expectLater(
          service.saveScheduledCorrection(
            medication: med,
            existingLog: original,
            date: past,
            timeSlot: MedicationTimeSlot.evening,
            isTaken: true,
            takenAt: DateTime(2026, 9, 10, 21),
            now: now,
          ),
          throwsArgumentError,
        );
        expect((await storage.fetchAllLogs()).map((e) => e.toMap()), [
          original.toMap(),
          other.toMap(),
        ]);
      },
    );
    for (final known in [true, false]) {
      test(
        'true to true preserves ${known ? "known" : "unknown"} snapshot',
        () async {
          final med = medication('a');
          final original = logFor(med, known: known);
          final storage = InMemoryMedicationStorage(
            medications: [med],
            logs: [original],
          );
          final service = MedicationService(storage);
          final changed = await service.saveScheduledCorrection(
            medication: med,
            existingLog: original,
            date: past,
            timeSlot: original.timeSlot,
            isTaken: true,
            takenAt: DateTime(2026, 9, 10, 10),
            now: now,
          );
          expect(changed.doseSnapshot, original.doseSnapshot);
          expect(changed.doseValueSnapshot, original.doseValueSnapshot);
          expect(changed.doseUnitSnapshot, original.doseUnitSnapshot);
          expect(changed.takenAt, DateTime(2026, 9, 10, 10));
          expect(changed.id, original.id);
          expect(changed.createdAt, original.createdAt);
        },
      );
    }
    test('true to false clears time and all snapshots; false to true captures current dose', () async {
      final med = medication('a');
      final storage = InMemoryMedicationStorage(
        medications: [med],
        logs: [logFor(med)],
      );
      final service = MedicationService(storage);
      final cleared = await service.saveScheduledCorrection(
        medication: med,
        existingLog: logFor(med),
        date: past,
        timeSlot: MedicationTimeSlot.morning,
        isTaken: false,
        now: now,
      );
      expect(cleared.takenAt, isNull);
      expect(cleared.doseSnapshot, isNull);
      expect(cleared.doseValueSnapshot, isNull);
      expect(cleared.doseUnitSnapshot, isNull);
      final taken = await service.saveScheduledCorrection(
        medication: med,
        existingLog: cleared,
        date: past,
        timeSlot: MedicationTimeSlot.morning,
        isTaken: true,
        takenAt: DateTime(2026, 9, 10, 9),
        now: now,
      );
      expect(taken.doseSnapshot, med.dose);
      expect(taken.doseValueSnapshot, med.doseValue);
      expect(taken.doseUnitSnapshot, med.doseUnit);
    });
  });

  group('missing scheduled batch', () {
    test('ID conflict on the second staged row leaves storage and cache unchanged', () async {
      final a = medication('a');
      final b = medication('b');
      // Obtain the generated ID through the public API, then seed a conflicting
      // fixture on another date. This checks the in-memory atomic contract.
      final probe = MedicationService(
        InMemoryMedicationStorage(medications: [b]),
      );
      await probe.addMissingScheduledLogs(
        date: past,
        items: [item(b)],
        now: now,
      );
      final conflict = (await probe.allLogsForTest()).single.copyWith(
        date: DateTime(2026, 9, 9),
      );
      final storage = InMemoryMedicationStorage(
        medications: [a, b],
        logs: [conflict],
      );
      final service = MedicationService(storage);
      await service.load(date: past);
      await expectLater(
        service.addMissingScheduledLogs(
          date: past,
          items: [item(a), item(b)],
          now: now,
        ),
        throwsA(isA<DuplicateMedicationLogException>()),
      );
      expect((await storage.fetchAllLogs()).single.toMap(), conflict.toMap());
      expect(service.todayDoseItems.where((e) => e.log != null), isEmpty);
    });

    test('request copies selection and date; completing it cannot pollute another loaded day', () async {
      final med = medication('a');
      final storage = GatedMedicationStorage(medications: [med]);
      final service = MedicationService(storage);
      await service.load(date: past);
      final selected = [item(med)];
      final request = service.addMissingScheduledLogs(
        date: past,
        items: selected,
        now: now,
      );
      selected.clear();
      await service.load(date: now);
      storage.gate.complete();
      await request;
      expect((await storage.fetchAllLogs()).single.date, past);
      expect(service.todayDoseItems.where((e) => e.log != null), isEmpty);
      expect(
        (await service.scheduledItemsForDate(past)).where((e) => e.log != null),
        hasLength(1),
      );
    });
    test('lists current active schedule with DB records, independent of loaded date', () async {
      final a = medication('a').copyWith(lunch: true, bedtime: true);
      final b = medication('b');
      final old = logFor(a, known: false);
      final storage = InMemoryMedicationStorage(
        medications: [
          a,
          b,
          medication('inactive').copyWith(isActive: false),
          medication('prn').copyWith(type: MedicationType.prn),
        ],
        logs: [old],
      );
      final service = MedicationService(storage);
      await service.load(date: now);
      final items = await service.scheduledItemsForDate(past);
      expect(items, hasLength(6));
      expect(
        items.where((e) => e.log != null).single.log!.toMap(),
        old.toMap(),
      );
      expect(service.logFor(a.id, past, MedicationTimeSlot.morning), isNull);
    });

    test('selects two of three missing; fixed local times, current snapshots and one notification', () async {
      final a = medication('a').copyWith(evening: false);
      final b = medication('b').copyWith(morning: false);
      final c = medication('c').copyWith(evening: false);
      final storage = InMemoryMedicationStorage(medications: [a, b, c]);
      final service = MedicationService(storage);
      await service.load(date: past);
      var notifications = 0;
      service.addListener(() => notifications++);
      await service.addMissingScheduledLogs(
        date: DateTime(2026, 9, 10, 16),
        items: [item(a), item(b, MedicationTimeSlot.evening)],
        now: now,
      );
      final logs = await storage.fetchAllLogs();
      expect(logs, hasLength(2));
      expect(logs.map((e) => e.medicationId), ['a', 'b']);
      expect(logs.map((e) => e.takenAt), [
        DateTime(2026, 9, 10, 9),
        DateTime(2026, 9, 10, 21),
      ]);
      for (final log in logs) {
        expect(log.date, past);
        expect(log.isTaken, isTrue);
        expect(log.doseSnapshot, a.dose);
        expect(log.doseValueSnapshot, a.doseValue);
        expect(log.doseUnitSnapshot, a.doseUnit);
        expect(
          service.logFor(log.medicationId, past, log.timeSlot)!.toMap(),
          log.toMap(),
        );
      }
      expect(notifications, 1);
    });

    test('existing true known, true unknown and false rows remain byte-for-byte unchanged despite stale cache', () async {
      final meds = [medication('a'), medication('b'), medication('c')];
      final storage = InMemoryMedicationStorage(medications: meds);
      final service = MedicationService(storage);
      await service.load(date: past);
      final existing = [
        logFor(meds[0]),
        logFor(meds[1], known: false),
        logFor(meds[2], taken: false, known: false),
      ];
      for (final log in existing) {
        await storage.upsertMedicationLog(log);
      }
      await service.addMissingScheduledLogs(
        date: past,
        items: meds.map((e) => item(e)).toList(),
        now: now,
      );
      expect(
        (await storage.fetchAllLogs()).map((e) => e.toMap()),
        existing.map((e) => e.toMap()),
      );
      expect(
        service.logFor('b', past, MedicationTimeSlot.morning)!.doseSnapshot,
        isNull,
      );
    });

    test('same-slot IDs are unique with identical clocks; retry and repeated selections are no-ops', () async {
      final meds = List.generate(10, (i) => medication('$i'));
      final storage = InMemoryMedicationStorage(medications: meds);
      final service = MedicationService(storage);
      final selected = meds.map((e) => item(e)).toList();
      await service.addMissingScheduledLogs(
        date: past,
        items: [...selected, selected.first],
        now: now,
      );
      final before = await storage.fetchAllLogs();
      expect(before, hasLength(10));
      expect(before.map((e) => e.id).toSet(), hasLength(10));
      expect(before.map((e) => e.takenAt).toSet(), {DateTime(2026, 9, 10, 9)});
      await service.addMissingScheduledLogs(
        date: past,
        items: selected,
        now: now,
      );
      expect(
        (await storage.fetchAllLogs()).map((e) => e.toMap()),
        before.map((e) => e.toMap()),
      );
    });

    test(
      'snapshots use persisted medication values, not stale request objects',
      () async {
        final med = medication('a');
        final storage = InMemoryMedicationStorage(medications: [med]);
        final service = MedicationService(storage);
        await storage.updateMedication(
          med.copyWith(
            dose: '3ml',
            doseValue: 3,
            doseUnit: MedicationDoseUnit.ml,
          ),
        );
        await service.addMissingScheduledLogs(
          date: past,
          items: [item(med)],
          now: now,
        );
        final log = (await storage.fetchAllLogs()).single;
        expect(log.doseSnapshot, '3ml');
        expect(log.doseValueSnapshot, 3);
        expect(log.doseUnitSnapshot, MedicationDoseUnit.ml);
      },
    );

    for (final slot in [MedicationTimeSlot.lunch, MedicationTimeSlot.bedtime]) {
      test(
        '$slot has no automatic time; invalid second item rolls back memory and cache',
        () async {
          final med = medication('a').copyWith(lunch: true, bedtime: true);
          final storage = InMemoryMedicationStorage(medications: [med]);
          final service = MedicationService(storage);
          await service.load(date: past);
          var notifications = 0;
          service.addListener(() => notifications++);
          expect(slot.defaultTakenAt(past), isNull);
          await expectLater(
            service.addMissingScheduledLogs(
              date: past,
              items: [item(med), item(med, slot)],
              now: now,
            ),
            throwsArgumentError,
          );
          expect(await storage.fetchAllLogs(), isEmpty);
          expect(service.todayDoseItems.where((e) => e.log != null), isEmpty);
          expect(notifications, 0);
        },
      );
    }

    test(
      'rejects future date and today future slot; allows elapsed today slot',
      () async {
        final med = medication('a');
        final storage = InMemoryMedicationStorage(medications: [med]);
        final service = MedicationService(storage);
        await expectLater(
          service.addMissingScheduledLogs(
            date: DateTime(2026, 9, 25),
            items: [item(med)],
            now: now,
          ),
          throwsA(isA<FuturePrnMedicationDateException>()),
        );
        await expectLater(
          service.addMissingScheduledLogs(
            date: now,
            items: [item(med, MedicationTimeSlot.evening)],
            now: now,
          ),
          throwsA(isA<FuturePrnMedicationTimeException>()),
        );
        expect(await storage.fetchAllLogs(), isEmpty);
        await service.addMissingScheduledLogs(
          date: now,
          items: [item(med)],
          now: now,
        );
        expect(
          (await storage.fetchAllLogs()).single.takenAt,
          DateTime(2026, 9, 24, 9),
        );
      },
    );

    test('rejects inactive, PRN, removed slots and missing medication without partial writes', () async {
      final valid = medication('valid');
      for (final invalid in [
        medication('bad').copyWith(isActive: false),
        medication('bad').copyWith(type: MedicationType.prn),
        medication('bad').copyWith(morning: false),
      ]) {
        final storage = InMemoryMedicationStorage(
          medications: [valid, invalid],
        );
        final service = MedicationService(storage);
        await expectLater(
          service.addMissingScheduledLogs(
            date: past,
            items: [item(valid), item(invalid)],
            now: now,
          ),
          throwsArgumentError,
        );
        expect(await storage.fetchAllLogs(), isEmpty);
      }
      final service = MedicationService(
        InMemoryMedicationStorage(medications: [valid]),
      );
      await expectLater(
        service.addMissingScheduledLogs(
          date: past,
          items: [item(medication('absent'))],
          now: now,
        ),
        throwsArgumentError,
      );
    });

    test('in-flight duplicate is rejected; storage failure leaves cache untouched and permits retry', () async {
      final med = medication('a');
      final storage = GatedMedicationStorage(medications: [med]);
      final service = MedicationService(storage);
      await service.load(date: past);
      final first = service.addMissingScheduledLogs(
        date: past,
        items: [item(med)],
        now: now,
      );
      await expectLater(
        service.addMissingScheduledLogs(
          date: past,
          items: [item(med)],
          now: now,
        ),
        throwsStateError,
      );
      storage.gate.completeError(StateError('injected failure'));
      await expectLater(first, throwsStateError);
      expect(await storage.fetchAllLogs(), isEmpty);
      expect(service.logFor(med.id, past, MedicationTimeSlot.morning), isNull);
      storage.gate = Completer<void>()..complete();
      await service.addMissingScheduledLogs(
        date: past,
        items: [item(med)],
        now: now,
      );
      expect(await storage.fetchAllLogs(), hasLength(1));
    });

    test('batch backup and restore retain exact IDs, times and known/unknown snapshots', () async {
      final a = medication('a');
      final b = medication('b');
      final storage = InMemoryMedicationStorage(
        medications: [a, b],
        logs: [logFor(a, known: false)],
      );
      final service = MedicationService(storage);
      await service.addMissingScheduledLogs(
        date: past,
        items: [item(a), item(a, MedicationTimeSlot.evening), item(b)],
        now: now,
      );
      final logs = await storage.fetchAllLogs();
      final backup = BackupService(
        repository: InMemoryBackupRepository(
          BackupSnapshot(
            healthRecords: const [],
            medications: [a, b],
            medicationLogs: logs,
            labResults: const [],
          ),
        ),
      );
      final document = backup.validateBackup(
        (await backup.createBackup(createdAt: now)).toPrettyJson(),
      );
      final destination = InMemoryBackupRepository();
      await BackupService(repository: destination).restoreBackup(document);
      expect(
        (await destination.fetchSnapshot()).medicationLogs.map(
          (e) => e.toMap(),
        ),
        logs.map((e) => e.toMap()),
      );
      expect(BackupDocument.backupVersion, 6);
    });
  });

  group('batch history UI', () {
    testWidgets(
      'morning and evening retain manual single-add with active slot choice',
      (tester) async {
        final med = medication('a');
        final service = MedicationService(
          InMemoryMedicationStorage(medications: [med]),
        );
        await openBatch(tester, service);
        await tester.tap(find.byKey(const Key('med-batch-manual-a-evening')));
        await tester.pumpAndSettle();
        final field = tester
            .widget<DropdownButtonFormField<MedicationTimeSlot>>(
              find.byKey(const Key('scheduled-correction-slot-field')),
            );
        expect(field.onChanged, isNotNull);
        final dropdown = tester.widget<DropdownButton<MedicationTimeSlot>>(
          find.byType(DropdownButton<MedicationTimeSlot>),
        );
        expect(dropdown.items!.map((e) => e.value), med.timeSlots);
        expect(field.initialValue, MedicationTimeSlot.evening);
        await tester.tap(
          find.byKey(const Key('scheduled-correction-save-button')),
        );
        await tester.pumpAndSettle();
        expect(
          (await service.allLogsForTest()).single.takenAt,
          DateTime(2026, 9, 10, 21),
        );
        expect(
          find.byKey(const Key('med-batch-manual-a-evening')),
          findsNothing,
        );
      },
    );
    testWidgets(
      'small viewport scrolls the day list without overflow and keeps save reachable',
      (tester) async {
        final service = MedicationService(
          InMemoryMedicationStorage(
            medications: List.generate(8, (i) => medication('$i')),
          ),
        );
        await openBatch(tester, service);
        tester.view.physicalSize = const Size(360, 640);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('med-batch-save')).hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('med-batch-7-evening')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('med-batch-7-evening')));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('med-batch-save')))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'shows whole schedule, locks existing rows and refreshes selected date after one save',
      (tester) async {
        final a = medication('a').copyWith(evening: false);
        final b = medication('b').copyWith(evening: false);
        final c = medication('c');
        final storage = InMemoryMedicationStorage(
          medications: [a, b, c],
          logs: [logFor(a), logFor(b, known: false, taken: false)],
        );
        final service = MedicationService(storage);
        await openBatch(tester, service);
        expect(find.text('현재 정기약 설정 기준'), findsOneWidget);
        expect(find.text('아침 · 09:00'), findsOneWidget);
        expect(find.text('저녁 · 21:00'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(4));
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('med-batch-a-morning')),
              )
              .onChanged,
          isNull,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('med-batch-b-morning')),
              )
              .onChanged,
          isNull,
        );
        expect(find.text('0.5정\n이미 기록됨 · 복용'), findsOneWidget);
        expect(find.text('복용량 기록 없음\n이미 기록됨 · 미복용'), findsOneWidget);
        await tester.tap(find.byKey(const Key('med-batch-c-morning')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('med-batch-save')));
        await tester.pumpAndSettle();
        expect(await storage.fetchAllLogs(), hasLength(3));
        expect(
          (await storage.fetchAllLogs()).last.takenAt,
          DateTime(2026, 9, 10, 9),
        );
        expect(find.text('선택 항목을 저장했습니다.'), findsOneWidget);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('med-batch-c-morning')),
              )
              .onChanged,
          isNull,
        );
        expect(find.text('정기 복약 추가\n2026.09.10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'double tap submits once and disables saving; failure preserves selection with explicit error',
      (tester) async {
        final med = medication('a').copyWith(evening: false);
        final storage = GatedMedicationStorage(medications: [med]);
        final service = MedicationService(storage);
        await openBatch(tester, service);
        await tester.tap(find.byKey(const Key('med-batch-a-morning')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('med-batch-save')));
        await tester.tap(find.byKey(const Key('med-batch-save')));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('med-batch-save')))
              .onPressed,
          isNull,
        );
        expect(storage.batchCalls, 1);
        storage.gate.completeError(StateError('save failure'));
        await tester.pumpAndSettle();
        expect(find.text('저장하지 못했습니다. 다시 시도해주세요.'), findsOneWidget);
        expect(find.text('선택 항목을 저장했습니다.'), findsNothing);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('med-batch-a-morning')),
              )
              .value,
          isTrue,
        );
        expect(await storage.fetchAllLogs(), isEmpty);
        storage.gate = Completer<void>()..complete();
        await tester.tap(find.byKey(const Key('med-batch-save')));
        await tester.pumpAndSettle();
        expect(await storage.fetchAllLogs(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'lunch and bedtime remain visible and manual form requires explicit time',
      (tester) async {
        final med = medication(
          'a',
        ).copyWith(morning: false, evening: false, lunch: true, bedtime: true);
        final storage = InMemoryMedicationStorage(medications: [med]);
        final service = MedicationService(storage);
        await openBatch(tester, service);
        expect(find.text('점심 · 시간 직접 입력'), findsOneWidget);
        expect(find.text('취침 전 · 시간 직접 입력'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.tap(find.byKey(const Key('med-batch-manual-a-lunch')));
        await tester.pumpAndSettle();
        expect(find.text('복용 시간을 선택해주세요.'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('scheduled-correction-save-button')),
        );
        await tester.pumpAndSettle();
        expect(await storage.fetchAllLogs(), isEmpty);
        expect(find.text('실제 복용 시간을 선택해주세요.'), findsOneWidget);
        final slot = tester.widget<DropdownButtonFormField<MedicationTimeSlot>>(
          find.byKey(const Key('scheduled-correction-slot-field')),
        );
        expect(slot.onChanged, isNotNull);
        await tester.tap(
          find.byKey(const Key('scheduled-correction-time-field')),
        );
        await tester.pumpAndSettle();
        final selectedTime = tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime;
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('scheduled-correction-save-button')),
        );
        await tester.pumpAndSettle();
        final log = (await storage.fetchAllLogs()).single;
        expect(log.timeSlot, MedicationTimeSlot.lunch);
        expect(
          log.takenAt,
          DateTime(
            past.year,
            past.month,
            past.day,
            selectedTime.hour,
            selectedTime.minute,
          ),
        );
        expect(log.doseValueSnapshot, med.doseValue);
        expect(find.text('2mg\n이미 기록됨 · 복용'), findsOneWidget);
      },
    );

    testWidgets(
      'existing correction slot is disabled even if removed from current schedule',
      (tester) async {
        final med = medication('a').copyWith(morning: false);
        final storage = InMemoryMedicationStorage(
          medications: [med],
          logs: [logFor(med)],
        );
        final service = MedicationService(storage);
        await openHistory(tester, service);
        await tester.tap(
          find.byKey(const Key('med-history-edit-scheduled-existing-a')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButtonFormField<MedicationTimeSlot>>(
                find.byKey(const Key('scheduled-correction-slot-field')),
              )
              .onChanged,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const Key('scheduled-correction-save-button')),
        );
        await tester.pumpAndSettle();
        expect((await storage.fetchAllLogs()).single.doseSnapshot, '0.5정');
        expect(
          (await storage.fetchAllLogs()).single.timeSlot,
          MedicationTimeSlot.morning,
        );
      },
    );

    testWidgets(
      'read failure is an error with retry, never a missing-record list',
      (tester) async {
        final storage = ReadFailingStorage(medications: [medication('a')]);
        final service = MedicationService(storage);
        await openHistory(tester, service);
        storage.fail = true;
        await tester.tap(
          find.byKey(const Key('med-history-add-missing-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('med-history-add-scheduled-option')),
        );
        await tester.pumpAndSettle();
        expect(find.text('정기약 목록을 불러오지 못했습니다.'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('med-batch-save')))
              .onPressed,
          isNull,
        );
        storage.fail = false;
        await tester.tap(find.text('다시 불러오기'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxListTile), findsNWidgets(2));
      },
    );
  });
}

Future<void> openHistory(WidgetTester tester, MedicationService service) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await service.load();
  await tester.pumpWidget(
    MaterialApp(home: MedicationHistoryScreen(service: service)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('medication-history-date-field')));
  await tester.pumpAndSettle();
  tester
      .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
      .onDateChanged(past);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> openBatch(WidgetTester tester, MedicationService service) async {
  await openHistory(tester, service);
  await tester.tap(find.byKey(const Key('med-history-add-missing-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('med-history-add-scheduled-option')));
  await tester.pumpAndSettle();
}

class ReadFailingStorage extends InMemoryMedicationStorage {
  ReadFailingStorage({super.medications});
  bool fail = false;

  @override
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date) {
    if (fail) return Future.error(StateError('read failure'));
    return super.fetchLogsForDate(date);
  }
}

MedicationDoseItem item(
  Medication med, [
  MedicationTimeSlot slot = MedicationTimeSlot.morning,
]) => MedicationDoseItem(medication: med, timeSlot: slot);

class GatedMedicationStorage extends InMemoryMedicationStorage {
  GatedMedicationStorage({super.medications});
  Completer<void> gate = Completer<void>();
  int batchCalls = 0;

  @override
  Future<List<MedicationLog>> insertMissingScheduledLogs({
    required DateTime date,
    required List<MedicationDoseItem> items,
    required DateTime now,
  }) async {
    batchCalls++;
    await gate.future;
    return super.insertMissingScheduledLogs(date: date, items: items, now: now);
  }
}

Medication medication(String id) => Medication(
  id: id,
  name: '약 $id',
  dose: '2mg',
  doseValue: 2,
  doseUnit: MedicationDoseUnit.mg,
  morning: true,
  lunch: false,
  evening: true,
  bedtime: false,
  isActive: true,
  createdAt: past,
  updatedAt: past,
);

MedicationLog logFor(Medication med, {bool known = true, bool taken = true}) =>
    MedicationLog(
      id: 'existing-${med.id}',
      medicationId: med.id,
      date: past,
      timeSlot: MedicationTimeSlot.morning,
      isTaken: taken,
      takenAt: taken ? DateTime(2026, 9, 10, 8) : null,
      doseSnapshot: known ? '0.5정' : null,
      doseValueSnapshot: known ? 0.5 : null,
      doseUnitSnapshot: known ? MedicationDoseUnit.tablet : null,
      createdAt: past,
      updatedAt: past,
    );
