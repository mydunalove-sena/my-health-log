import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  group('V3.5 Home PRN summary', () {
    testWidgets('hides PRN subsection when today has no actual PRN logs', (
      tester,
    ) async {
      final service = await _service(
        medications: [
          _medication(id: 'prn', name: 'PRN med', type: MedicationType.prn),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(medicationService: service)),
      );

      expect(find.byKey(const Key('home-prn-medication-group')), findsNothing);
      expect(find.text('PRN med'), findsNothing);
    });

    testWidgets('shows today PRN logs with count and times', (tester) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
        dose: '1mg',
        doseValue: 1,
        doseUnit: MedicationDoseUnit.mg,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'prn-1',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 9, 20),
          ),
          _prnLog(
            id: 'prn-2',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 15, 40),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(medicationService: service)),
      );

      expect(
        find.byKey(const Key('home-prn-medication-group')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-prn-prn')), findsOneWidget);
      expect(find.text('PRN med'), findsOneWidget);
      expect(find.textContaining('09:20'), findsOneWidget);
      expect(find.textContaining('15:40'), findsOneWidget);
    });

    testWidgets('shows scheduled and actual PRN groups together', (
      tester,
    ) async {
      final today = _today();
      final scheduled = _medication(id: 'scheduled', name: 'Scheduled med');
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [scheduled, prn],
        prnLogs: [
          _prnLog(
            id: 'prn-1',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 10),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(medicationService: service)),
      );

      expect(find.text('Scheduled med'), findsOneWidget);
      expect(find.text('PRN med'), findsOneWidget);
      expect(
        find.byKey(const Key('home-prn-medication-group')),
        findsOneWidget,
      );
    });
  });

  group('V3.5 PRN UX', () {
    testWidgets('uses take label before first PRN log and add label after', (
      tester,
    ) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(medications: [prn]);

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      expect(find.byKey(const Key('prn-record-prn')), findsOneWidget);

      await service.recordPrnTaken(
        medication: prn,
        takenAt: DateTime(today.year, today.month, today.day, 9),
        now: DateTime(today.year, today.month, today.day, 9, 1),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('09:00'), findsWidgets);
      expect(find.byKey(const Key('prn-record-prn')), findsOneWidget);
    });

    test(
      'additional PRN records insert new rows without overwriting old rows',
      () async {
        final today = _today();
        final prn = _medication(
          id: 'prn',
          name: 'PRN med',
          type: MedicationType.prn,
        );
        final service = await _service(medications: [prn]);

        final first = await service.recordPrnTaken(
          medication: prn,
          takenAt: DateTime(today.year, today.month, today.day, 9),
          now: DateTime(today.year, today.month, today.day, 9, 1),
        );
        final second = await service.recordPrnTaken(
          medication: prn,
          takenAt: DateTime(today.year, today.month, today.day, 15),
          now: DateTime(today.year, today.month, today.day, 15, 1),
        );

        final logs = await service.allPrnLogsForTest();
        expect(logs, hasLength(2));
        expect(logs.map((log) => log.id), containsAll([first.id, second.id]));
        expect(first.id, isNot(second.id));
      },
    );

    testWidgets('shows PRN note on today row when present', (tester) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'prn-note',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 9),
            note: 'after exercise',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('prn-log-note-prn-note')),
        findsOneWidget,
      );
      expect(find.textContaining('after exercise'), findsOneWidget);
    });

    testWidgets('hides PRN note line when note is blank', (tester) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'prn-no-note',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 9),
            note: '   ',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('prn-log-note-prn-no-note')),
        findsNothing,
      );
      expect(find.textContaining('상세 증상:'), findsNothing);
      expect(find.textContaining('메모:'), findsNothing);
    });

    testWidgets('limits long PRN note display to two lines', (tester) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'prn-long-note',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 9),
            note: List.filled(20, 'very long note').join(' '),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byKey(const ValueKey('prn-log-note-prn-long-note')),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    test(
      'counts PRN period summaries by medication and date boundary',
      () async {
        final asOf = DateTime(2026, 9, 7, 12);
        final first = _medication(
          id: 'prn-a',
          name: 'PRN A',
          type: MedicationType.prn,
        );
        final second = _medication(
          id: 'prn-b',
          name: 'PRN B',
          type: MedicationType.prn,
        );
        final service = await _service(
          medications: [first, second],
          prnLogs: [
            _prnLog(
              id: 'a-09-01',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 1, 9),
            ),
            _prnLog(
              id: 'a-09-01-2',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 1, 15),
            ),
            _prnLog(
              id: 'a-08-09',
              medicationId: first.id,
              takenAt: DateTime(2026, 8, 9, 9),
            ),
            _prnLog(
              id: 'a-08-08',
              medicationId: first.id,
              takenAt: DateTime(2026, 8, 8, 9),
            ),
            _prnLog(
              id: 'b-09-07',
              medicationId: second.id,
              takenAt: DateTime(2026, 9, 7, 9),
            ),
            _prnLog(
              id: 'future',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 8, 9),
            ),
          ],
          date: asOf,
        );

        final summaries = await service.prnPeriodSummaryByMedication(
          asOf: asOf,
        );

        expect(summaries[first.id]?.last30Days, 3);
        expect(summaries[first.id]?.medicationDays, 2);
        expect(summaries[first.id]?.recentDateKeys, [
          '2026-09-01',
          '2026-08-09',
        ]);
        expect(summaries[second.id]?.last30Days, 1);
        expect(summaries[second.id]?.medicationDays, 1);
        expect(summaries[second.id]?.recentDateKeys, ['2026-09-07']);
      },
    );

    test('sorts recent distinct PRN dates and keeps 30-day boundary', () async {
      final asOf = DateTime(2026, 9, 7, 12);
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'day-1',
            medicationId: prn.id,
            takenAt: DateTime(2026, 9, 7, 9),
          ),
          _prnLog(
            id: 'day-2',
            medicationId: prn.id,
            takenAt: DateTime(2026, 9, 6, 9),
          ),
          _prnLog(
            id: 'day-3',
            medicationId: prn.id,
            takenAt: DateTime(2026, 9, 5, 9),
          ),
          _prnLog(
            id: 'boundary',
            medicationId: prn.id,
            takenAt: DateTime(2026, 8, 9, 9),
          ),
          _prnLog(
            id: 'outside',
            medicationId: prn.id,
            takenAt: DateTime(2026, 8, 8, 9),
          ),
        ],
        date: asOf,
      );

      final summary = (await service.prnPeriodSummaryByMedication(
        asOf: asOf,
      ))[prn.id]!;

      expect(summary.last30Days, 4);
      expect(summary.medicationDays, 4);
      expect(summary.recentDateKeys, [
        '2026-09-07',
        '2026-09-06',
        '2026-09-05',
        '2026-08-09',
      ]);
    });

    test(
      'fetches medication-specific recent PRN logs without date selection',
      () async {
        final asOf = DateTime(2026, 9, 7, 12);
        final first = _medication(
          id: 'prn-a',
          name: 'PRN A',
          type: MedicationType.prn,
        );
        final second = _medication(
          id: 'prn-b',
          name: 'PRN B',
          type: MedicationType.prn,
        );
        final service = await _service(
          medications: [first, second],
          prnLogs: [
            _prnLog(
              id: 'a-evening',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 7, 21),
            ),
            _prnLog(
              id: 'a-morning',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 7, 9),
            ),
            _prnLog(
              id: 'a-boundary',
              medicationId: first.id,
              takenAt: DateTime(2026, 8, 9, 8),
            ),
            _prnLog(
              id: 'a-outside',
              medicationId: first.id,
              takenAt: DateTime(2026, 8, 8, 8),
            ),
            _prnLog(
              id: 'a-future',
              medicationId: first.id,
              takenAt: DateTime(2026, 9, 8, 8),
            ),
            _prnLog(
              id: 'b-recent',
              medicationId: second.id,
              takenAt: DateTime(2026, 9, 6, 8),
            ),
          ],
          date: asOf,
        );

        final recent = await service.recentPrnLogsByMedication(asOf: asOf);

        expect(recent[first.id]?.map((log) => log.id), [
          'a-evening',
          'a-morning',
          'a-boundary',
        ]);
        expect(recent[second.id]?.map((log) => log.id), ['b-recent']);
      },
    );

    test('limits medication-specific recent PRN logs per medication', () async {
      final asOf = DateTime(2026, 9, 7, 12);
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          for (var index = 0; index < 6; index += 1)
            _prnLog(
              id: 'log-$index',
              medicationId: prn.id,
              takenAt: DateTime(2026, 9, 7, 12 - index),
            ),
        ],
        date: asOf,
      );

      final recent = await service.recentPrnLogsByMedication(
        asOf: asOf,
        limitPerMedication: 5,
      );

      expect(recent[prn.id]?.map((log) => log.id), [
        'log-0',
        'log-1',
        'log-2',
        'log-3',
        'log-4',
      ]);
    });

    testWidgets('shows PRN period summary in medication PRN section', (
      tester,
    ) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          _prnLog(
            id: 'recent',
            medicationId: prn.id,
            takenAt: DateTime(today.year, today.month, today.day, 9),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('prn-period-summary')), findsOneWidget);
      expect(find.text('지난 30일 1회'), findsOneWidget);
      expect(find.text('복용일 1일'), findsOneWidget);
      expect(find.textContaining('최근 복용:'), findsNothing);
    });

    testWidgets('hides recent PRN date summary while keeping recent records', (
      tester,
    ) async {
      final today = _today();
      final prn = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final service = await _service(
        medications: [prn],
        prnLogs: [
          for (var offset = 0; offset < 7; offset += 1)
            _prnLog(
              id: 'recent-$offset',
              medicationId: prn.id,
              takenAt: DateTime(
                today.year,
                today.month,
                today.day,
              ).subtract(Duration(days: offset)).add(const Duration(hours: 9)),
            ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('지난 30일 7회'), findsOneWidget);
      expect(find.text('복용일 7일'), findsOneWidget);
      expect(find.text('최근 복용 기록'), findsOneWidget);
      expect(find.textContaining('최근 복용:'), findsNothing);
      expect(
        find.byKey(const ValueKey('prn-log-entry-recent-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('prn-log-entry-recent-4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('prn-log-entry-recent-5')),
        findsNothing,
      );
    });

    testWidgets(
      'hides recent PRN record preview when last 30-day count is zero',
      (tester) async {
        final prn = _medication(
          id: 'prn',
          name: 'PRN med',
          type: MedicationType.prn,
        );
        final service = await _service(medications: [prn]);

        await tester.pumpWidget(
          MaterialApp(home: MedicationScreen(service: service)),
        );
        await tester.pumpAndSettle();

        expect(find.text('지난 30일 0회'), findsOneWidget);
        expect(find.text('복용일 0일'), findsOneWidget);
        expect(find.textContaining('최근 복용:'), findsNothing);
      },
    );
    testWidgets('shows no recent PRN record preview when count is zero', (
      tester,
    ) async {
      final prn = _medication(
        id: 'prn-empty',
        name: 'PRN empty',
        type: MedicationType.prn,
      );
      final service = await _service(medications: [prn]);

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('prn-recent-history-prn-empty')),
        findsNothing,
      );
    });

    testWidgets('shows medication-specific recent PRN records in PRN row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = _today();
      final first = _medication(
        id: 'prn-a',
        name: 'PRN A',
        type: MedicationType.prn,
      );
      final second = _medication(
        id: 'prn-b',
        name: 'PRN B',
        type: MedicationType.prn,
      );
      final firstEvening = _prnLog(
        id: 'a-evening',
        medicationId: first.id,
        takenAt: DateTime(today.year, today.month, today.day, 21, 10),
        doseValue: 1000,
        doseUnit: MedicationDoseUnit.mg,
        note: '머리 통증 메모',
      );
      final firstMorning = _prnLog(
        id: 'a-morning',
        medicationId: first.id,
        takenAt: DateTime(today.year, today.month, today.day, 9, 5),
        doseValue: 500,
        doseUnit: MedicationDoseUnit.mg,
        note: '   ',
      );
      final secondLog = _prnLog(
        id: 'b-log',
        medicationId: second.id,
        takenAt: DateTime(today.year, today.month, today.day, 8),
      );
      final service = await _service(
        medications: [first, second],
        prnLogs: [firstMorning, secondLog, firstEvening],
        prnSymptomLinks: [_link('link-evening', firstEvening.id, 'headache')],
      );
      final symptomService = await _symptomService();

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationScreen(
            service: service,
            symptomService: symptomService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstPreview = find.byKey(
        const ValueKey('prn-recent-history-prn-a'),
      );
      final firstRow = find.byKey(const ValueKey('prn-medication-row-prn-a'));
      expect(firstPreview, findsOneWidget);
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.byKey(const ValueKey('prn-log-entry-a-evening')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.byKey(const ValueKey('prn-log-entry-a-morning')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.textContaining(
            '${_formatTestDate(today)} 21:10 | 1000mg',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firstRow, matching: find.text('지난 30일 2회')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firstRow, matching: find.text('복용일 1일')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firstRow, matching: find.text('최근 복용 기록')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.textContaining('관련 증상: 두통'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.textContaining('상세 증상: 머리 통증 메모'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('메모:'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('prn-log-note-a-morning')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: firstPreview,
          matching: find.byKey(const ValueKey('prn-log-entry-b-log')),
        ),
        findsNothing,
      );
    });
  });

  group('V3.5 past scheduled correction', () {
    test(
      'adds a missed past scheduled log with matching date and takenAt date',
      () async {
        final past = DateTime(2026, 8, 20);
        final medication = _medication(id: 'med', name: 'Scheduled med');
        final service = await _service(medications: [medication]);

        final log = await service.saveScheduledCorrection(
          medication: medication,
          date: past,
          timeSlot: MedicationTimeSlot.morning,
          isTaken: true,
          takenAt: DateTime(2026, 8, 20, 8, 30),
          now: DateTime(2026, 8, 30),
        );

        expect(log.date, past);
        expect(log.takenAt, DateTime(2026, 8, 20, 8, 30));
        expect(log.isTaken, isTrue);
        expect(log.displayDoseSnapshot, isNull);
      },
    );

    test(
      'updates an existing scheduled log preserving id and createdAt',
      () async {
        final past = DateTime(2026, 8, 20);
        final createdAt = DateTime(2026, 8, 20, 8);
        final medication = _medication(id: 'med', name: 'Scheduled med');
        final service = await _service(
          medications: [medication],
          logs: [
            _scheduledLog(
              id: 'existing',
              medicationId: medication.id,
              date: past,
              createdAt: createdAt,
              isTaken: true,
              takenAt: DateTime(2026, 8, 20, 8, 10),
            ),
          ],
        );

        final updated = await service.saveScheduledCorrection(
          medication: medication,
          date: past,
          timeSlot: MedicationTimeSlot.morning,
          isTaken: false,
          now: DateTime(2026, 8, 30),
        );

        expect(updated.id, 'existing');
        expect(updated.createdAt, createdAt);
        expect(updated.isTaken, isFalse);
        expect(updated.takenAt, isNull);
        expect((await service.allLogsForTest()), hasLength(1));
      },
    );

    test(
      'scheduled correction touches only the selected date and time slot',
      () async {
        final past = DateTime(2026, 8, 20);
        final otherDate = DateTime(2026, 8, 19);
        final medication = _medication(
          id: 'med',
          name: 'Scheduled med',
          lunch: true,
        );
        final service = await _service(
          medications: [medication],
          logs: [
            _scheduledLog(
              id: 'other-date',
              medicationId: medication.id,
              date: otherDate,
              isTaken: true,
            ),
            _scheduledLog(
              id: 'other-slot',
              medicationId: medication.id,
              date: past,
              timeSlot: MedicationTimeSlot.lunch,
              isTaken: true,
            ),
          ],
        );

        await service.saveScheduledCorrection(
          medication: medication,
          date: past,
          timeSlot: MedicationTimeSlot.morning,
          isTaken: false,
          now: DateTime(2026, 8, 30),
        );

        final logs = await service.allLogsForTest();
        expect(logs, hasLength(3));
        expect(
          logs.singleWhere((log) => log.id == 'other-date').isTaken,
          isTrue,
        );
        expect(
          logs.singleWhere((log) => log.id == 'other-slot').isTaken,
          isTrue,
        );
      },
    );

    test('blocks future scheduled correction dates and times', () async {
      final medication = _medication(id: 'med', name: 'Scheduled med');
      final service = await _service(medications: [medication]);

      expect(
        () => service.saveScheduledCorrection(
          medication: medication,
          date: DateTime(2026, 8, 31),
          timeSlot: MedicationTimeSlot.morning,
          isTaken: true,
          takenAt: DateTime(2026, 8, 31, 8),
          now: DateTime(2026, 8, 30, 9),
        ),
        throwsA(isA<FuturePrnMedicationDateException>()),
      );
      expect(
        () => service.saveScheduledCorrection(
          medication: medication,
          date: DateTime(2026, 8, 30),
          timeSlot: MedicationTimeSlot.morning,
          isTaken: true,
          takenAt: DateTime(2026, 8, 30, 10),
          now: DateTime(2026, 8, 30, 9),
        ),
        throwsA(isA<FuturePrnMedicationTimeException>()),
      );
    });
  });

  group('V3.5 past PRN correction', () {
    test('updates an existing PRN log preserving id and createdAt', () async {
      final medication = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final existing = _prnLog(
        id: 'existing-prn',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 9),
        doseValue: 1,
        doseUnit: MedicationDoseUnit.mg,
        note: 'old',
      );
      final service = await _service(
        medications: [medication],
        prnLogs: [existing],
      );

      final updated = await service.updatePrnLog(
        medication: medication,
        existingLog: existing,
        takenAt: DateTime(2026, 8, 20, 10, 30),
        doseValue: 2,
        doseUnit: MedicationDoseUnit.mg,
        note: 'new',
        now: DateTime(2026, 8, 30),
      );

      expect(updated.id, existing.id);
      expect(updated.createdAt, existing.createdAt);
      expect(updated.takenAt, DateTime(2026, 8, 20, 10, 30));
      expect(updated.displayDose, '2mg');
      expect(updated.note, 'new');
      expect((await service.allPrnLogsForTest()), hasLength(1));
    });

    test('replaces symptom links only for the edited PRN log', () async {
      final medication = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final first = _prnLog(
        id: 'first',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 9),
      );
      final second = _prnLog(
        id: 'second',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 15),
      );
      final service = await _service(
        medications: [medication],
        prnLogs: [first, second],
        prnSymptomLinks: [
          _link('first-a', first.id, 'a'),
          _link('second-b', second.id, 'b'),
        ],
      );

      await service.updatePrnLog(
        medication: medication,
        existingLog: first,
        takenAt: first.takenAt,
        symptomDefinitionIds: ['c'],
        now: DateTime(2026, 8, 30),
      );

      final links = await service.allPrnSymptomLinksForTest();
      expect(
        links
            .where((link) => link.prnMedicationLogId == first.id)
            .map((link) => link.symptomDefinitionId),
        ['c'],
      );
      expect(
        links
            .where((link) => link.prnMedicationLogId == second.id)
            .map((link) => link.symptomDefinitionId),
        ['b'],
      );
    });

    test('moves a PRN log date without touching other PRN rows', () async {
      final medication = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final first = _prnLog(
        id: 'first',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 9),
      );
      final second = _prnLog(
        id: 'second',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 15),
      );
      final service = await _service(
        medications: [medication],
        prnLogs: [first, second],
      );

      final updated = await service.updatePrnLog(
        medication: medication,
        existingLog: first,
        takenAt: DateTime(2026, 8, 19, 7),
        now: DateTime(2026, 8, 30),
      );

      expect(updated.date, DateTime(2026, 8, 19));
      final logs = await service.allPrnLogsForTest();
      expect(logs, hasLength(2));
      expect(
        logs.singleWhere((log) => log.id == 'second').date,
        DateTime(2026, 8, 20),
      );
    });

    test('blocks future PRN update dates and times', () async {
      final medication = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final existing = _prnLog(
        id: 'existing',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 20, 9),
      );
      final service = await _service(
        medications: [medication],
        prnLogs: [existing],
      );

      expect(
        () => service.updatePrnLog(
          medication: medication,
          existingLog: existing,
          takenAt: DateTime(2026, 8, 31, 9),
          now: DateTime(2026, 8, 30, 9),
        ),
        throwsA(isA<FuturePrnMedicationDateException>()),
      );
      expect(
        () => service.updatePrnLog(
          medication: medication,
          existingLog: existing,
          takenAt: DateTime(2026, 8, 30, 10),
          now: DateTime(2026, 8, 30, 9),
        ),
        throwsA(isA<FuturePrnMedicationTimeException>()),
      );
    });
  });

  group('V3.5 history UI actions', () {
    testWidgets('shows missing-log add action and scheduled edit action', (
      tester,
    ) async {
      final date = _today();
      final medication = _medication(id: 'med', name: 'Scheduled med');
      final service = await _service(
        medications: [medication],
        logs: [
          _scheduledLog(
            id: 'scheduled-log',
            medicationId: medication.id,
            date: date,
            isTaken: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: MedicationHistoryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('med-history-add-missing-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('med-history-edit-scheduled-scheduled-log')),
        findsOneWidget,
      );
    });

    testWidgets(
      'PRN history edit action opens edit form with existing values',
      (tester) async {
        final date = _today();
        final medication = _medication(
          id: 'prn',
          name: 'PRN med',
          type: MedicationType.prn,
        );
        final log = _prnLog(
          id: 'prn-log',
          medicationId: medication.id,
          takenAt: DateTime(date.year, date.month, date.day, 9, 10),
          doseValue: 0.5,
          doseUnit: MedicationDoseUnit.tablet,
          note: 'memo',
        );
        final service = await _service(
          medications: [medication],
          prnLogs: [log],
        );

        await tester.pumpWidget(
          MaterialApp(home: MedicationHistoryScreen(service: service)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('med-history-edit-prn-prn-log')));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextFormField, '0.5'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'memo'), findsOneWidget);
      },
    );

    testWidgets('MedicationHistoryScreen shows PRN note', (tester) async {
      final date = _today();
      final medication = _medication(
        id: 'prn',
        name: 'PRN med',
        type: MedicationType.prn,
      );
      final log = _prnLog(
        id: 'prn-history-note',
        medicationId: medication.id,
        takenAt: DateTime(date.year, date.month, date.day, 9, 10),
        note: 'right shoulder pain',
      );
      final service = await _service(medications: [medication], prnLogs: [log]);

      await tester.pumpWidget(
        MaterialApp(home: MedicationHistoryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('med-history-prn-note-prn-history-note')),
        findsOneWidget,
      );
      expect(find.textContaining('right shoulder pain'), findsOneWidget);
      expect(find.textContaining('상세 증상:'), findsOneWidget);
      expect(find.textContaining('메모:'), findsNothing);
    });
  });
}

Future<MedicationService> _service({
  List<Medication>? medications,
  List<MedicationLog>? logs,
  List<PrnMedicationLog>? prnLogs,
  List<PrnSymptomLink>? prnSymptomLinks,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(
      medications: medications,
      logs: logs,
      prnLogs: prnLogs,
      prnSymptomLinks: prnSymptomLinks,
    ),
  );
  await service.load(date: date ?? _today());
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
  final now = DateTime(2026, 8, 20);
  return [
    SymptomDefinition(
      id: 'headache',
      name: '두통',
      isDefault: true,
      isActive: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

Medication _medication({
  required String id,
  required String name,
  MedicationType type = MedicationType.scheduled,
  String? dose = '1 tablet',
  double? doseValue = 1,
  MedicationDoseUnit? doseUnit = MedicationDoseUnit.tablet,
  bool lunch = false,
}) {
  final now = DateTime(2026, 8, 20);
  return Medication(
    id: id,
    name: name,
    type: type,
    dose: dose,
    doseValue: doseValue,
    doseUnit: doseUnit,
    morning: type == MedicationType.scheduled,
    lunch: type == MedicationType.scheduled && lunch,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

MedicationLog _scheduledLog({
  required String id,
  required String medicationId,
  required DateTime date,
  bool isTaken = true,
  MedicationTimeSlot timeSlot = MedicationTimeSlot.morning,
  DateTime? takenAt,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(date.year, date.month, date.day, 8);
  return MedicationLog(
    id: id,
    medicationId: medicationId,
    date: DateTime(date.year, date.month, date.day),
    timeSlot: timeSlot,
    isTaken: isTaken,
    takenAt: isTaken
        ? takenAt ?? DateTime(date.year, date.month, date.day, 8)
        : null,
    createdAt: created,
    updatedAt: created,
  );
}

PrnMedicationLog _prnLog({
  required String id,
  required String medicationId,
  required DateTime takenAt,
  double? doseValue,
  MedicationDoseUnit? doseUnit,
  String? note,
}) {
  return PrnMedicationLog(
    id: id,
    medicationId: medicationId,
    date: DateTime(takenAt.year, takenAt.month, takenAt.day),
    takenAt: takenAt,
    doseValue: doseValue,
    doseUnit: doseUnit,
    note: note,
    createdAt: takenAt,
    updatedAt: takenAt,
  );
}

PrnSymptomLink _link(String id, String prnMedicationLogId, String symptomId) {
  return PrnSymptomLink(
    id: id,
    prnMedicationLogId: prnMedicationLogId,
    symptomDefinitionId: symptomId,
    createdAt: DateTime(2026, 8, 20),
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatTestDate(DateTime date) => '${date.month}/${date.day}';
