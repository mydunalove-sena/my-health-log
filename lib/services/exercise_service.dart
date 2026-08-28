import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/exercise_met_values.dart';
import '../models/exercise_record.dart';
import 'app_database.dart';
import 'health_record_service.dart';

class FutureExerciseRecordDateException implements Exception {
  const FutureExerciseRecordDateException();
}

class InvalidExerciseDurationException implements Exception {
  const InvalidExerciseDurationException();
}

abstract class ExerciseRecordStorage {
  Future<List<ExerciseRecord>> fetchAll();
  Future<void> insert(ExerciseRecord record);
  Future<void> update(ExerciseRecord record);
  Future<void> delete(String id);
}

class ExerciseService extends ChangeNotifier {
  ExerciseService(this._storage, this._healthRecordService);

  final ExerciseRecordStorage _storage;
  final HealthRecordService _healthRecordService;
  final List<ExerciseRecord> _records = [];

  List<ExerciseRecord> get records => List.unmodifiable(
    _records.where((record) => !_isFutureDate(record.date)),
  );

  Future<void> load() async {
    _records
      ..clear()
      ..addAll(await _storage.fetchAll());
    _sortRecords();
    notifyListeners();
  }

  List<ExerciseRecord> recordsForDate(DateTime date) {
    final dateKey = ExerciseRecord.formatDateKey(date);
    return List.unmodifiable(
      records.where((record) => record.dateKey == dateKey),
    );
  }

  List<ExerciseRecord> get todayRecords => recordsForDate(DateTime.now());

  Future<void> save(ExerciseRecord record) async {
    if (_isFutureDate(record.date)) {
      throw const FutureExerciseRecordDateException();
    }
    if (record.durationMinutes <= 0) {
      throw const InvalidExerciseDurationException();
    }

    final currentIndex = _records.indexWhere((item) => item.id == record.id);
    final current = currentIndex == -1 ? null : _records[currentIndex];
    final now = DateTime.now();
    final sameDate = current != null && current.dateKey == record.dateKey;
    final weightSnapshot = sameDate
        ? current.weightSnapshot
        : _healthRecordService.recordForDate(record.date)?.weight;
    final metSnapshot = ExerciseMetValues.metFor(
      record.exerciseType,
      record.intensity,
    );
    final estimatedCalories = ExerciseMetValues.estimatedCalories(
      met: metSnapshot,
      weight: weightSnapshot,
      durationMinutes: record.durationMinutes,
    );
    final normalized = ExerciseRecord(
      id: record.id,
      date: DateTime(record.date.year, record.date.month, record.date.day),
      exerciseType: record.exerciseType,
      durationMinutes: record.durationMinutes,
      intensity: record.intensity,
      weightSnapshot: weightSnapshot,
      metSnapshot: metSnapshot,
      estimatedCalories: estimatedCalories,
      createdAt: current?.createdAt ?? record.createdAt,
      updatedAt: current == null ? record.updatedAt : now,
    );

    if (currentIndex == -1) {
      await _storage.insert(normalized);
      _records.add(normalized);
    } else {
      await _storage.update(normalized);
      _records[currentIndex] = normalized;
    }
    _sortRecords();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.delete(id);
    _records.removeWhere((record) => record.id == id);
    notifyListeners();
  }

  bool _isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isAfter(today);
  }

  void _sortRecords() {
    _records.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) {
        return byDate;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}

class SqfliteExerciseRecordStorage implements ExerciseRecordStorage {
  static const _table = 'exercise_records';

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final database = await AppDatabase.open();
    _database = database;
    return database;
  }

  @override
  Future<List<ExerciseRecord>> fetchAll() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'date DESC, createdAt DESC');
    return rows.map(ExerciseRecord.fromMap).toList();
  }

  @override
  Future<void> insert(ExerciseRecord record) async {
    final db = await _db;
    await db.insert(_table, record.toMap());
  }

  @override
  Future<void> update(ExerciseRecord record) async {
    final db = await _db;
    await db.update(
      _table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

class InMemoryExerciseRecordStorage implements ExerciseRecordStorage {
  InMemoryExerciseRecordStorage([List<ExerciseRecord>? records])
    : _records = List.of(records ?? const []);

  final List<ExerciseRecord> _records;

  @override
  Future<List<ExerciseRecord>> fetchAll() async {
    return List.of(_records)..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) {
        return byDate;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  @override
  Future<void> insert(ExerciseRecord record) async {
    _records.add(record);
  }

  @override
  Future<void> update(ExerciseRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((record) => record.id == id);
  }
}
