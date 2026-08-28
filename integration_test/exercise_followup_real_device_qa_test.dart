import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_health_log/models/exercise_record.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/exercise_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home smoke with injected ExerciseService', (tester) async {
    final healthService = HealthRecordService(SqfliteHealthRecordStorage());
    final exerciseService = ExerciseService(
      SqfliteExerciseRecordStorage(),
      healthService,
    );
    final medicationService = MedicationService(SqfliteMedicationStorage());
    await Future.wait([
      healthService.load(),
      exerciseService.load(),
      medicationService.load(),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          healthRecordService: healthService,
          medicationService: medicationService,
          exerciseService: exerciseService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('My Health Log'), findsOneWidget);
    expect(find.text('오늘의 건강'), findsOneWidget);
    expect(find.text('오늘의 운동'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // ignore: avoid_print
    print('QA_V310_FOLLOWUP_HOME_SMOKE PASS');
  });

  testWidgets('Backup V5 serializes QA exercise records only', (tester) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toString();
    const prefix = 'qa-v310-exercise-followup';
    final healthId = '$prefix-health-$runId';
    final exerciseId = '$prefix-exercise-$runId';

    addTearDown(() async {
      await _cleanupQaData(prefix);
      final healthService = HealthRecordService(SqfliteHealthRecordStorage());
      final exerciseService = ExerciseService(
        SqfliteExerciseRecordStorage(),
        healthService,
      );
      await Future.wait([healthService.load(), exerciseService.load()]);
      expect(
        exerciseService.records.where((record) => record.id.startsWith(prefix)),
        isEmpty,
      );
      expect(
        healthService.records.where((record) => record.id.startsWith(prefix)),
        isEmpty,
      );
      // ignore: avoid_print
      print('QA_V310_FOLLOWUP_CLEANUP PASS');
    });

    final healthService = HealthRecordService(SqfliteHealthRecordStorage());
    final exerciseService = ExerciseService(
      SqfliteExerciseRecordStorage(),
      healthService,
    );
    await Future.wait([healthService.load(), exerciseService.load()]);

    final qaDate = _findUnusedDate(healthService);
    final now = DateTime.now();
    await healthService.save(
      HealthRecord(
        id: healthId,
        date: qaDate,
        weight: 60,
        steps: 4321,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await exerciseService.save(
      ExerciseRecord(
        id: exerciseId,
        date: qaDate,
        exerciseType: ExerciseType.walking,
        durationMinutes: 30,
        intensity: ExerciseIntensity.moderate,
        weightSnapshot: null,
        metSnapshot: 0,
        estimatedCalories: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final saved = exerciseService.records.singleWhere(
      (record) => record.id == exerciseId,
    );
    final backupService = BackupService(repository: SqfliteBackupRepository());
    final backup = await backupService.createBackup(createdAt: now);

    expect(BackupDocument.backupVersion, 5);
    expect(backup.toJson()['backupVersion'], 5);
    expect(
      (backup.toJson()['data'] as Map<String, Object?>).containsKey(
        'exerciseRecords',
      ),
      isTrue,
    );
    final backedUp = backup.snapshot.exerciseRecords.singleWhere(
      (record) => record.id == exerciseId,
    );
    expect(backedUp.toMap(), saved.toMap());

    final decoded = backupService.validateBackup(backup.toPrettyJson());
    final decodedRecord = decoded.snapshot.exerciseRecords.singleWhere(
      (record) => record.id == exerciseId,
    );
    expect(decodedRecord.id, saved.id);
    expect(decodedRecord.dateKey, saved.dateKey);
    expect(decodedRecord.exerciseType, saved.exerciseType);
    expect(decodedRecord.durationMinutes, saved.durationMinutes);
    expect(decodedRecord.intensity, saved.intensity);
    expect(decodedRecord.weightSnapshot, saved.weightSnapshot);
    expect(decodedRecord.metSnapshot, saved.metSnapshot);
    expect(decodedRecord.estimatedCalories, saved.estimatedCalories);

    // ignore: avoid_print
    print('QA_V310_FOLLOWUP_BACKUP_V5 PASS');
  });
}

DateTime _findUnusedDate(HealthRecordService healthService) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (var offset = 1; offset < 9000; offset++) {
    final candidate = today.subtract(Duration(days: offset));
    if (candidate.isBefore(DateTime(2000))) {
      break;
    }
    if (healthService.recordForDate(candidate) == null) {
      return candidate;
    }
  }
  throw StateError('No unused health-record date found for follow-up QA');
}

Future<void> _cleanupQaData(String prefix) async {
  final healthService = HealthRecordService(SqfliteHealthRecordStorage());
  final exerciseService = ExerciseService(
    SqfliteExerciseRecordStorage(),
    healthService,
  );
  await Future.wait([healthService.load(), exerciseService.load()]);
  for (final record in exerciseService.records.where(
    (record) => record.id.startsWith(prefix),
  )) {
    await exerciseService.delete(record.id);
  }
  for (final record in healthService.records.where(
    (record) => record.id.startsWith(prefix),
  )) {
    await healthService.delete(record.id);
  }
}
