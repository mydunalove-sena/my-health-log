import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/exercise_met_values.dart';
import 'package:my_health_log/models/exercise_record.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/services/exercise_service.dart';
import 'package:my_health_log/services/health_record_service.dart';

void main() {
  group('ExerciseRecord', () {
    test('map round-trip preserves exercise fields', () {
      final record = _exerciseRecord();

      final restored = ExerciseRecord.fromMap(record.toMap());

      expect(restored.toMap(), record.toMap());
      expect(restored.exerciseType.label, '걷기');
      expect(restored.intensity.label, '보통');
    });
  });

  group('ExerciseService', () {
    test('allows multiple exercise records on the same date', () async {
      final service = await _exerciseService(
        healthRecords: [_healthRecord(weight: 60)],
      );
      final day = DateTime(2026, 8, 24);

      await service.save(_exerciseRecord(id: 'exercise-1', date: day));
      await service.save(
        _exerciseRecord(
          id: 'exercise-2',
          date: day,
          exerciseType: ExerciseType.running,
        ),
      );

      expect(service.records, hasLength(2));
      expect(service.recordsForDate(day), hasLength(2));
    });

    test('queries records by date in date-descending order', () async {
      final service = await _exerciseService(
        records: [
          _exerciseRecord(id: 'old', date: DateTime(2026, 8, 23)),
          _exerciseRecord(id: 'new', date: DateTime(2026, 8, 24)),
        ],
      );

      expect(service.records.map((record) => record.id), ['new', 'old']);
      expect(service.recordsForDate(DateTime(2026, 8, 23)).single.id, 'old');
    });

    test('blocks future dates', () async {
      final service = await _exerciseService();
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      expect(
        () => service.save(_exerciseRecord(date: tomorrow)),
        throwsA(isA<FutureExerciseRecordDateException>()),
      );
    });

    test('blocks zero and negative duration', () async {
      final service = await _exerciseService();

      expect(
        () => service.save(_exerciseRecord(durationMinutes: 0)),
        throwsA(isA<InvalidExerciseDurationException>()),
      );
      expect(
        () => service.save(_exerciseRecord(durationMinutes: -1)),
        throwsA(isA<InvalidExerciseDurationException>()),
      );
    });

    test(
      'applies weight snapshot and calculates MET calories on create',
      () async {
        final service = await _exerciseService(
          healthRecords: [_healthRecord(weight: 54.2)],
        );

        await service.save(
          _exerciseRecord(
            exerciseType: ExerciseType.walking,
            intensity: ExerciseIntensity.moderate,
            durationMinutes: 40,
          ),
        );

        final record = service.records.single;
        expect(record.weightSnapshot, 54.2);
        expect(record.metSnapshot, 3.8);
        expect(record.estimatedCalories, closeTo(137.31, 0.01));
      },
    );

    test(
      'saves exercise without same-day weight and leaves calories null',
      () async {
        final service = await _exerciseService();

        await service.save(_exerciseRecord());

        final record = service.records.single;
        expect(record.weightSnapshot, isNull);
        expect(record.estimatedCalories, isNull);
      },
    );

    test('keeps same-date weight snapshot when editing', () async {
      final day = DateTime(2026, 8, 24);
      final healthService = await _healthService(
        records: [_healthRecord(date: day, weight: 54.2)],
      );
      final service = ExerciseService(
        InMemoryExerciseRecordStorage(),
        healthService,
      );
      await service.load();
      await service.save(_exerciseRecord(date: day));
      final original = service.records.single;

      await healthService.save(_healthRecord(date: day, weight: 60));
      await service.save(
        original.copyWith(
          durationMinutes: 30,
          exerciseType: ExerciseType.running,
        ),
      );

      final edited = service.records.single;
      expect(edited.weightSnapshot, 54.2);
      expect(edited.metSnapshot, 9.3);
      expect(edited.estimatedCalories, closeTo(252.03, 0.01));
    });

    test('refreshes weight snapshot only when exercise date changes', () async {
      final oldDay = DateTime(2026, 8, 23);
      final newDay = DateTime(2026, 8, 24);
      final service = await _exerciseService(
        healthRecords: [
          _healthRecord(id: 'old-health', date: oldDay, weight: 54.2),
          _healthRecord(id: 'new-health', date: newDay, weight: 60),
        ],
      );
      await service.save(_exerciseRecord(date: oldDay));
      final original = service.records.single;

      await service.save(original.copyWith(date: newDay));

      expect(service.records.single.weightSnapshot, 60);
    });

    test('updates and deletes records', () async {
      final service = await _exerciseService(
        healthRecords: [_healthRecord(weight: 60)],
      );
      await service.save(_exerciseRecord());
      final original = service.records.single;

      await service.save(original.copyWith(durationMinutes: 20));
      expect(service.records.single.durationMinutes, 20);

      await service.delete(original.id);
      expect(service.records, isEmpty);
    });

    test('MET table returns configured values', () {
      expect(
        ExerciseMetValues.metFor(
          ExerciseType.elliptical,
          ExerciseIntensity.light,
        ),
        5.0,
      );
      expect(
        ExerciseMetValues.metFor(
          ExerciseType.elliptical,
          ExerciseIntensity.moderate,
        ),
        5.0,
      );
    });
  });
}

Future<ExerciseService> _exerciseService({
  List<ExerciseRecord>? records,
  List<HealthRecord>? healthRecords,
}) async {
  final healthService = await _healthService(records: healthRecords);
  final service = ExerciseService(
    InMemoryExerciseRecordStorage(records),
    healthService,
  );
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

ExerciseRecord _exerciseRecord({
  String id = 'exercise-1',
  DateTime? date,
  ExerciseType exerciseType = ExerciseType.walking,
  ExerciseIntensity intensity = ExerciseIntensity.moderate,
  int durationMinutes = 40,
}) {
  final now = DateTime(2026, 8, 24, 10);
  return ExerciseRecord(
    id: id,
    date: date ?? DateTime(2026, 8, 24),
    exerciseType: exerciseType,
    durationMinutes: durationMinutes,
    intensity: intensity,
    weightSnapshot: null,
    metSnapshot: 0,
    estimatedCalories: null,
    createdAt: now,
    updatedAt: now,
  );
}

HealthRecord _healthRecord({
  String id = 'health-1',
  DateTime? date,
  double? weight,
}) {
  final now = DateTime(2026, 8, 24, 9);
  return HealthRecord(
    id: id,
    date: date ?? DateTime(2026, 8, 24),
    weight: weight,
    createdAt: now,
    updatedAt: now,
  );
}
