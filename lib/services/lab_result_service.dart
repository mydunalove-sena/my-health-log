import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/lab_result.dart';
import 'app_database.dart';

class EmptyLabTestNameException implements Exception {
  const EmptyLabTestNameException();
}

class EmptyLabValueException implements Exception {
  const EmptyLabValueException();
}

class DuplicateLabResultException implements Exception {
  const DuplicateLabResultException();
}

abstract class LabResultStorage {
  Future<List<LabResult>> fetchAll();
  Future<void> insert(LabResult result);
  Future<void> update(LabResult result);
  Future<void> delete(String id);
}

class LabResultService extends ChangeNotifier {
  LabResultService(this._storage);

  final LabResultStorage _storage;
  final List<LabResult> _results = [];

  List<LabResult> get results => List.unmodifiable(_results);

  List<LabResultDateGroup> get groups {
    final grouped = <String, List<LabResult>>{};
    final dates = <String, DateTime>{};
    for (final result in _results) {
      grouped.putIfAbsent(result.dateKey, () => []).add(result);
      dates[result.dateKey] = result.date;
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        LabResultDateGroup(
          date: dates[key]!,
          results: List.unmodifiable(grouped[key]!..sort(_compareResultOrder)),
        ),
    ];
  }

  Future<void> load() async {
    _results
      ..clear()
      ..addAll(await _storage.fetchAll());
    _sortResults();
    notifyListeners();
  }

  List<LabResult> resultsForDate(DateTime date) {
    final dateKey = LabResult.formatDateKey(date);
    return _results.where((result) => result.dateKey == dateKey).toList()
      ..sort(_compareResultOrder);
  }

  LabResult? resultById(String id) {
    for (final result in _results) {
      if (result.id == id) {
        return result;
      }
    }
    return null;
  }

  Future<void> save(LabResult result) async {
    final testName = result.testName.trim();
    if (testName.isEmpty) {
      throw const EmptyLabTestNameException();
    }
    if (result.value.isNaN || result.value.isInfinite) {
      throw const EmptyLabValueException();
    }

    final normalized = result.copyWith(
      testName: testName,
      unit: result.unit?.trim().isEmpty == true ? null : result.unit?.trim(),
      clearUnit: result.unit?.trim().isEmpty == true,
    );
    final duplicateIndex = _results.indexWhere(
      (item) =>
          item.id != normalized.id &&
          item.dateKey == normalized.dateKey &&
          item.testName.trim() == normalized.testName,
    );
    if (duplicateIndex != -1) {
      throw const DuplicateLabResultException();
    }

    final index = _results.indexWhere((item) => item.id == normalized.id);
    try {
      if (index == -1) {
        await _storage.insert(normalized);
        _results.add(normalized);
      } else {
        await _storage.update(normalized);
        _results[index] = normalized;
      }
    } on DuplicateLabResultException {
      rethrow;
    }
    _sortResults();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.delete(id);
    _results.removeWhere((result) => result.id == id);
    notifyListeners();
  }

  void _sortResults() {
    _results.sort((a, b) {
      final dateCompare = b.dateKey.compareTo(a.dateKey);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return _compareResultOrder(a, b);
    });
  }

  static int _compareResultOrder(LabResult a, LabResult b) {
    final createdCompare = a.createdAt.compareTo(b.createdAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return a.testName.compareTo(b.testName);
  }
}

class SqfliteLabResultStorage implements LabResultStorage {
  static const _table = 'lab_results';

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
  Future<List<LabResult>> fetchAll() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'date DESC, createdAt ASC');
    return rows.map(LabResult.fromMap).toList();
  }

  @override
  Future<void> insert(LabResult result) async {
    final db = await _db;
    try {
      await db.insert(_table, result.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateLabResultException();
      }
      rethrow;
    }
  }

  @override
  Future<void> update(LabResult result) async {
    final db = await _db;
    try {
      await db.update(
        _table,
        result.toMap(),
        where: 'id = ?',
        whereArgs: [result.id],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateLabResultException();
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

class InMemoryLabResultStorage implements LabResultStorage {
  InMemoryLabResultStorage([List<LabResult>? results])
    : _results = List.of(results ?? const []);

  final List<LabResult> _results;

  @override
  Future<List<LabResult>> fetchAll() async {
    return List.of(_results);
  }

  @override
  Future<void> insert(LabResult result) async {
    if (_hasDuplicate(result)) {
      throw const DuplicateLabResultException();
    }
    _results.add(result);
  }

  @override
  Future<void> update(LabResult result) async {
    if (_hasDuplicate(result)) {
      throw const DuplicateLabResultException();
    }
    final index = _results.indexWhere((item) => item.id == result.id);
    if (index == -1) {
      _results.add(result);
    } else {
      _results[index] = result;
    }
  }

  @override
  Future<void> delete(String id) async {
    _results.removeWhere((result) => result.id == id);
  }

  bool _hasDuplicate(LabResult result) {
    return _results.any(
      (item) =>
          item.id != result.id &&
          item.dateKey == result.dateKey &&
          item.testName.trim() == result.testName.trim(),
    );
  }
}
