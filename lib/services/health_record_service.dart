import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/health_record.dart';
import 'app_database.dart';

class DuplicateHealthRecordException implements Exception {
  const DuplicateHealthRecordException();
}

class EmptyHealthRecordException implements Exception {
  const EmptyHealthRecordException();
}

abstract class HealthRecordStorage {
  Future<List<HealthRecord>> fetchAll();
  Future<void> insert(HealthRecord record);
  Future<void> update(HealthRecord record);
  Future<void> delete(String id);
}

class HealthRecordService extends ChangeNotifier {
  HealthRecordService(this._storage);

  final HealthRecordStorage _storage;
  final List<HealthRecord> _records = [];

  List<HealthRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    _records
      ..clear()
      ..addAll(await _storage.fetchAll());
    _sortRecords();
    notifyListeners();
  }

  HealthRecord? recordForDate(DateTime date) {
    final dateKey = HealthRecord.formatDateKey(date);
    for (final record in _records) {
      if (record.dateKey == dateKey) {
        return record;
      }
    }
    return null;
  }

  HealthRecord? get todayRecord => recordForDate(DateTime.now());

  Future<void> save(HealthRecord record) async {
    if (!record.hasAnyHealthValue) {
      throw const EmptyHealthRecordException();
    }

    final currentIndex = _records.indexWhere((item) => item.id == record.id);
    final sameDateIndex = _records.indexWhere(
      (item) => item.id != record.id && item.dateKey == record.dateKey,
    );
    if (sameDateIndex != -1) {
      throw const DuplicateHealthRecordException();
    }

    if (currentIndex == -1) {
      await _storage.insert(record);
      _records.add(record);
    } else {
      await _storage.update(record);
      _records[currentIndex] = record;
    }
    _sortRecords();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.delete(id);
    _records.removeWhere((record) => record.id == id);
    notifyListeners();
  }

  void _sortRecords() {
    _records.sort((a, b) => b.date.compareTo(a.date));
  }
}

class SqfliteHealthRecordStorage implements HealthRecordStorage {
  static const _table = 'health_records';

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
  Future<List<HealthRecord>> fetchAll() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'date DESC');
    return rows.map(HealthRecord.fromMap).toList();
  }

  @override
  Future<void> insert(HealthRecord record) async {
    final db = await _db;
    try {
      await db.insert(_table, record.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateHealthRecordException();
      }
      rethrow;
    }
  }

  @override
  Future<void> update(HealthRecord record) async {
    final db = await _db;
    try {
      await db.update(
        _table,
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateHealthRecordException();
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

class InMemoryHealthRecordStorage implements HealthRecordStorage {
  InMemoryHealthRecordStorage([List<HealthRecord>? records])
    : _records = List.of(records ?? const []);

  final List<HealthRecord> _records;

  @override
  Future<List<HealthRecord>> fetchAll() async {
    return List.of(_records)..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> insert(HealthRecord record) async {
    if (_records.any((item) => item.dateKey == record.dateKey)) {
      throw const DuplicateHealthRecordException();
    }
    _records.add(record);
  }

  @override
  Future<void> update(HealthRecord record) async {
    final sameDate = _records.indexWhere(
      (item) => item.id != record.id && item.dateKey == record.dateKey,
    );
    if (sameDate != -1) {
      throw const DuplicateHealthRecordException();
    }
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
