import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_health_log/core/constants/exercise_met_values.dart';
import 'package:my_health_log/models/exercise_record.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/screens/exercise/exercise_screen.dart';
import 'package:my_health_log/screens/health/health_screen.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/exercise_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('V3.1.0 exercise real-device automated QA', (tester) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toString();
    const prefix = 'qa-v310-exercise';
    final qaIds = _QaIds(prefix: prefix, runId: runId);

    addTearDown(() async {
      await _cleanupQaData(qaIds);
      final cleanupHealth = HealthRecordService(SqfliteHealthRecordStorage());
      final cleanupExercise = ExerciseService(
        SqfliteExerciseRecordStorage(),
        cleanupHealth,
      );
      await Future.wait([cleanupHealth.load(), cleanupExercise.load()]);
      expect(
        cleanupExercise.records.where((record) => record.id.startsWith(prefix)),
        isEmpty,
      );
      expect(
        cleanupHealth.records.where((record) => record.id.startsWith(prefix)),
        isEmpty,
      );
      // ignore: avoid_print
      print('QA_V310_CLEANUP PASS');
    });

    final healthService = HealthRecordService(SqfliteHealthRecordStorage());
    final exerciseService = ExerciseService(
      SqfliteExerciseRecordStorage(),
      healthService,
    );
    final medicationService = MedicationService(SqfliteMedicationStorage());
    final symptomService = SymptomService(SqfliteSymptomStorage());
    await Future.wait([
      healthService.load(),
      exerciseService.load(),
      medicationService.load(),
      symptomService.load(),
    ]);

    final dates = _findUnusedDates(healthService);
    final dateA = dates[0];
    final dateB = dates[1];
    final dateC = dates[2];
    final now = DateTime.now();

    await healthService.save(
      _healthRecord(id: qaIds.healthA, date: dateA, weight: 60, steps: 4321),
    );
    await healthService.save(
      _healthRecord(id: qaIds.healthB, date: dateB, weight: 62.5),
    );

    await exerciseService.save(
      _exerciseRecord(
        id: qaIds.exerciseA,
        date: dateA,
        type: ExerciseType.walking,
        durationMinutes: 30,
        intensity: ExerciseIntensity.moderate,
        now: now,
      ),
    );
    await exerciseService.save(
      _exerciseRecord(
        id: qaIds.exerciseB,
        date: dateA,
        type: ExerciseType.cycling,
        durationMinutes: 20,
        intensity: ExerciseIntensity.vigorous,
        now: now,
      ),
    );
    await exerciseService.save(
      _exerciseRecord(
        id: qaIds.exerciseC,
        date: dateC,
        type: ExerciseType.other,
        durationMinutes: 15,
        intensity: ExerciseIntensity.light,
        now: now,
      ),
    );

    final dateARecords = exerciseService.recordsForDate(dateA);
    expect(
      dateARecords.where((record) => record.id.startsWith(prefix)),
      hasLength(2),
    );

    final exerciseA = _byId(exerciseService, qaIds.exerciseA);
    final exerciseB = _byId(exerciseService, qaIds.exerciseB);
    final exerciseC = _byId(exerciseService, qaIds.exerciseC);
    expect(exerciseA.weightSnapshot, 60);
    expect(exerciseB.weightSnapshot, 60);
    expect(
      exerciseA.metSnapshot,
      ExerciseMetValues.metFor(
        ExerciseType.walking,
        ExerciseIntensity.moderate,
      ),
    );
    expect(
      exerciseB.metSnapshot,
      ExerciseMetValues.metFor(
        ExerciseType.cycling,
        ExerciseIntensity.vigorous,
      ),
    );
    expect(exerciseA.estimatedCalories, closeTo(114, 0.001));
    expect(exerciseB.estimatedCalories, closeTo(180, 0.001));
    expect(exerciseC.weightSnapshot, isNull);
    expect(exerciseC.estimatedCalories, isNull);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(
      () => exerciseService.save(
        _exerciseRecord(
          id: qaIds.futureExercise,
          date: tomorrow,
          type: ExerciseType.walking,
          durationMinutes: 10,
          intensity: ExerciseIntensity.light,
          now: now,
        ),
      ),
      throwsA(isA<FutureExerciseRecordDateException>()),
    );
    expect(
      () => exerciseService.save(
        _exerciseRecord(
          id: qaIds.invalidZero,
          date: dateA,
          type: ExerciseType.walking,
          durationMinutes: 0,
          intensity: ExerciseIntensity.light,
          now: now,
        ),
      ),
      throwsA(isA<InvalidExerciseDurationException>()),
    );
    expect(
      () => exerciseService.save(
        _exerciseRecord(
          id: qaIds.invalidNegative,
          date: dateA,
          type: ExerciseType.walking,
          durationMinutes: -1,
          intensity: ExerciseIntensity.light,
          now: now,
        ),
      ),
      throwsA(isA<InvalidExerciseDurationException>()),
    );
    expect(
      exerciseService.records.any(
        (record) => record.id == qaIds.futureExercise,
      ),
      isFalse,
    );
    expect(
      exerciseService.records.any((record) => record.id == qaIds.invalidZero),
      isFalse,
    );
    expect(
      exerciseService.records.any(
        (record) => record.id == qaIds.invalidNegative,
      ),
      isFalse,
    );

    await exerciseService.save(
      exerciseA.copyWith(
        durationMinutes: 45,
        intensity: ExerciseIntensity.vigorous,
      ),
    );
    final sameDateEdited = _byId(exerciseService, qaIds.exerciseA);
    expect(sameDateEdited.weightSnapshot, 60);
    expect(
      sameDateEdited.metSnapshot,
      ExerciseMetValues.metFor(
        ExerciseType.walking,
        ExerciseIntensity.vigorous,
      ),
    );
    expect(sameDateEdited.estimatedCalories, closeTo(216, 0.001));

    await exerciseService.save(sameDateEdited.copyWith(date: dateB));
    final dateChanged = _byId(exerciseService, qaIds.exerciseA);
    expect(dateChanged.weightSnapshot, 62.5);
    expect(dateChanged.estimatedCalories, closeTo(225, 0.001));

    final reloadedHealth = HealthRecordService(SqfliteHealthRecordStorage());
    final reloadedExercise = ExerciseService(
      SqfliteExerciseRecordStorage(),
      reloadedHealth,
    );
    await Future.wait([reloadedHealth.load(), reloadedExercise.load()]);
    final reloadedA = _byId(reloadedExercise, qaIds.exerciseA);
    final reloadedB = _byId(reloadedExercise, qaIds.exerciseB);
    final reloadedC = _byId(reloadedExercise, qaIds.exerciseC);
    expect(reloadedA.dateKey, ExerciseRecord.formatDateKey(dateB));
    expect(reloadedA.durationMinutes, 45);
    expect(reloadedA.intensity, ExerciseIntensity.vigorous);
    expect(reloadedA.weightSnapshot, 62.5);
    expect(reloadedA.metSnapshot, dateChanged.metSnapshot);
    expect(
      reloadedA.estimatedCalories,
      closeTo(dateChanged.estimatedCalories!, 0.001),
    );
    expect(reloadedB.dateKey, ExerciseRecord.formatDateKey(dateA));
    expect(reloadedB.weightSnapshot, 60);
    expect(reloadedC.weightSnapshot, isNull);
    expect(reloadedC.estimatedCalories, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          exerciseService: reloadedExercise,
          healthRecordService: reloadedHealth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('운동 기록'), findsWidgets);
    expect(find.textContaining('걷기'), findsWidgets);
    expect(find.textContaining('45분'), findsWidgets);
    expect(find.textContaining('강하게'), findsWidgets);
    expect(find.textContaining('자전거'), findsWidgets);
    expect(find.textContaining('20분'), findsWidgets);
    expect(find.textContaining('예상 소모 칼로리'), findsWidgets);
    expect(find.textContaining('예상 소모 칼로리 계산 불가'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(
          service: reloadedHealth,
          symptomService: symptomService,
          exerciseService: reloadedExercise,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-record-button')));
    await tester.pumpAndSettle();
    expect(find.text('운동 기록'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          healthRecordService: reloadedHealth,
          medicationService: medicationService,
          exerciseService: reloadedExercise,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    final backupService = BackupService(repository: SqfliteBackupRepository());
    final backup = await backupService.createBackup(createdAt: now);
    expect(backup.toJson()['backupVersion'], 5);
    final qaExerciseRows = backup.snapshot.exerciseRecords
        .where((record) => record.id.startsWith(prefix))
        .toList();
    expect(
      qaExerciseRows.map((record) => record.id),
      containsAll([qaIds.exerciseA, qaIds.exerciseB, qaIds.exerciseC]),
    );
    final decoded = backupService.validateBackup(backup.toPrettyJson());
    final decodedA = decoded.snapshot.exerciseRecords.singleWhere(
      (record) => record.id == qaIds.exerciseA,
    );
    expect(decodedA.dateKey, reloadedA.dateKey);
    expect(decodedA.exerciseType, reloadedA.exerciseType);
    expect(decodedA.durationMinutes, reloadedA.durationMinutes);
    expect(decodedA.intensity, reloadedA.intensity);
    expect(decodedA.weightSnapshot, reloadedA.weightSnapshot);
    expect(decodedA.metSnapshot, reloadedA.metSnapshot);
    expect(
      decodedA.estimatedCalories,
      closeTo(reloadedA.estimatedCalories!, 0.001),
    );

    // ignore: avoid_print
    print(
      'QA_V310_DATES A=${ExerciseRecord.formatDateKey(dateA)} B=${ExerciseRecord.formatDateKey(dateB)} C=${ExerciseRecord.formatDateKey(dateC)}',
    );
    // ignore: avoid_print
    print('QA_V310_SERVICE PASS');
    // ignore: avoid_print
    print('QA_V310_EDIT PASS');
    // ignore: avoid_print
    print('QA_V310_PERSISTENCE PASS');
    // ignore: avoid_print
    print('QA_V310_UI PASS');
    // ignore: avoid_print
    print('QA_V310_BACKUP_V5 PASS');
  });
}

List<DateTime> _findUnusedDates(HealthRecordService healthService) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = <DateTime>[];
  for (var offset = 1; offset < 9000 && result.length < 3; offset++) {
    final candidate = today.subtract(Duration(days: offset));
    if (candidate.isBefore(DateTime(2000))) {
      break;
    }
    if (healthService.recordForDate(candidate) == null) {
      result.add(candidate);
    }
  }
  if (result.length < 3) {
    throw StateError('Not enough unused health-record dates for exercise QA');
  }
  return result;
}

Future<void> _cleanupQaData(_QaIds qaIds) async {
  final healthService = HealthRecordService(SqfliteHealthRecordStorage());
  final exerciseService = ExerciseService(
    SqfliteExerciseRecordStorage(),
    healthService,
  );
  await Future.wait([healthService.load(), exerciseService.load()]);
  for (final record in exerciseService.records.where(
    (record) => record.id.startsWith(qaIds.prefix),
  )) {
    await exerciseService.delete(record.id);
  }
  for (final record in healthService.records.where(
    (record) => record.id.startsWith(qaIds.prefix),
  )) {
    await healthService.delete(record.id);
  }
}

ExerciseRecord _byId(ExerciseService service, String id) {
  return service.records.singleWhere((record) => record.id == id);
}

HealthRecord _healthRecord({
  required String id,
  required DateTime date,
  required double weight,
  int? steps,
}) {
  final now = DateTime.now();
  return HealthRecord(
    id: id,
    date: date,
    weight: weight,
    steps: steps,
    createdAt: now,
    updatedAt: now,
  );
}

ExerciseRecord _exerciseRecord({
  required String id,
  required DateTime date,
  required ExerciseType type,
  required int durationMinutes,
  required ExerciseIntensity intensity,
  required DateTime now,
}) {
  return ExerciseRecord(
    id: id,
    date: date,
    exerciseType: type,
    durationMinutes: durationMinutes,
    intensity: intensity,
    weightSnapshot: null,
    metSnapshot: 0,
    estimatedCalories: null,
    createdAt: now,
    updatedAt: now,
  );
}

class _QaIds {
  const _QaIds({required this.prefix, required this.runId});

  final String prefix;
  final String runId;

  String get healthA => '$prefix-health-a-$runId';
  String get healthB => '$prefix-health-b-$runId';
  String get exerciseA => '$prefix-a-$runId';
  String get exerciseB => '$prefix-b-$runId';
  String get exerciseC => '$prefix-c-$runId';
  String get futureExercise => '$prefix-future-$runId';
  String get invalidZero => '$prefix-invalid-zero-$runId';
  String get invalidNegative => '$prefix-invalid-negative-$runId';
}
