import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/exercise_record.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/screens/exercise/exercise_screen.dart';
import 'package:my_health_log/services/exercise_service.dart';
import 'package:my_health_log/services/health_record_service.dart';

void main() {
  testWidgets('exercise list displays current and past records', (
    tester,
  ) async {
    final healthService = await _healthService(
      records: [_healthRecord(weight: 54.2)],
    );
    final service = ExerciseService(
      InMemoryExerciseRecordStorage([
        _exerciseRecord(
          id: 'past',
          date: DateTime(2026, 8, 23),
          exerciseType: ExerciseType.running,
          durationMinutes: 30,
          intensity: ExerciseIntensity.vigorous,
          weightSnapshot: 60,
          metSnapshot: 11,
          estimatedCalories: 330,
        ),
        _exerciseRecord(
          id: 'today',
          date: DateTime(2026, 8, 24),
          exerciseType: ExerciseType.walking,
          durationMinutes: 40,
          intensity: ExerciseIntensity.moderate,
          weightSnapshot: 54.2,
          metSnapshot: 3.8,
          estimatedCalories: 137.31,
        ),
      ]),
      healthService,
    );
    await service.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          exerciseService: service,
          healthRecordService: healthService,
        ),
      ),
    );

    expect(find.text('운동 기록'), findsWidgets);
    expect(find.text('2026.08.24'), findsOneWidget);
    expect(find.text('2026.08.23'), findsOneWidget);
    expect(find.text('걷기 · 40분 · 보통'), findsOneWidget);
    expect(find.text('달리기 · 30분 · 강하게'), findsOneWidget);
    expect(find.text('예상 소모 칼로리 137 kcal'), findsOneWidget);
    expect(find.text('예상 소모 칼로리 330 kcal'), findsOneWidget);
  });

  testWidgets('exercise form saves and deletes a record', (tester) async {
    final healthService = await _healthService(
      records: [_healthRecord(weight: 54.2)],
    );
    final service = ExerciseService(
      InMemoryExerciseRecordStorage(),
      healthService,
    );
    await service.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseScreen(
          exerciseService: service,
          healthRecordService: healthService,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('exercise-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('exercise-duration-field')),
      '40',
    );
    await tester.tap(find.byKey(const Key('exercise-save-button')));
    await tester.pumpAndSettle();

    expect(service.records, hasLength(1));
    expect(find.text('걷기 · 40분 · 보통'), findsOneWidget);

    await tester.tap(find.text('걷기 · 40분 · 보통'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제').last);
    await tester.pumpAndSettle();

    expect(service.records, isEmpty);
    expect(find.text('운동 기록이 없습니다.'), findsOneWidget);
  });
}

Future<HealthRecordService> _healthService({
  List<HealthRecord>? records,
}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

ExerciseRecord _exerciseRecord({
  required String id,
  required DateTime date,
  required ExerciseType exerciseType,
  required int durationMinutes,
  required ExerciseIntensity intensity,
  required double? weightSnapshot,
  required double metSnapshot,
  required double? estimatedCalories,
}) {
  final now = DateTime(2026, 8, 24, 10);
  return ExerciseRecord(
    id: id,
    date: date,
    exerciseType: exerciseType,
    durationMinutes: durationMinutes,
    intensity: intensity,
    weightSnapshot: weightSnapshot,
    metSnapshot: metSnapshot,
    estimatedCalories: estimatedCalories,
    createdAt: now,
    updatedAt: now,
  );
}

HealthRecord _healthRecord({double? weight}) {
  final now = DateTime(2026, 8, 24, 9);
  return HealthRecord(
    id: 'health-1',
    date: DateTime(2026, 8, 24),
    weight: weight,
    createdAt: now,
    updatedAt: now,
  );
}
