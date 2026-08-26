import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/symptom.dart';
import 'app_database.dart';

class DuplicateSymptomRecordException implements Exception {
  const DuplicateSymptomRecordException();
}

abstract class SymptomStorage {
  Future<List<SymptomDefinition>> fetchDefinitions();
  Future<List<SymptomRecord>> fetchRecords();
  Future<void> upsertRecord(SymptomRecord record);
}

class SymptomService extends ChangeNotifier {
  SymptomService(this._storage);

  final SymptomStorage _storage;
  final List<SymptomDefinition> _definitions = [];
  final List<SymptomRecord> _records = [];

  List<SymptomDefinition> get definitions => List.unmodifiable(
    _definitions.where((definition) => definition.isActive),
  );

  List<SymptomRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    _definitions
      ..clear()
      ..addAll(await _storage.fetchDefinitions());
    _sortDefinitions();
    _records
      ..clear()
      ..addAll(await _storage.fetchRecords());
    _sortRecords();
    notifyListeners();
  }

  List<SymptomRecord> recordsForDate(DateTime date) {
    final dateKey = SymptomRecord.formatDateKey(date);
    return _records
        .where((record) => record.dateKey == dateKey)
        .toList(growable: false);
  }

  SymptomRecord? recordForDateAndSymptom(
    DateTime date,
    String symptomDefinitionId,
  ) {
    final dateKey = SymptomRecord.formatDateKey(date);
    for (final record in _records) {
      if (record.dateKey == dateKey &&
          record.symptomDefinitionId == symptomDefinitionId) {
        return record;
      }
    }
    return null;
  }

  SymptomSeverity severityForDateAndSymptom(
    DateTime date,
    String symptomDefinitionId,
  ) {
    return recordForDateAndSymptom(date, symptomDefinitionId)?.severity ??
        SymptomSeverity.none;
  }

  Future<void> saveRecord(SymptomRecord record) async {
    await _storage.upsertRecord(record);
    final index = _records.indexWhere(
      (item) =>
          item.dateKey == record.dateKey &&
          item.symptomDefinitionId == record.symptomDefinitionId,
    );
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
    _sortRecords();
    notifyListeners();
  }

  Future<void> saveSeverity({
    required DateTime date,
    required String symptomDefinitionId,
    required SymptomSeverity severity,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final existing = recordForDateAndSymptom(date, symptomDefinitionId);
    final record = SymptomRecord(
      id: existing?.id ?? 'symptom-${timestamp.microsecondsSinceEpoch}',
      symptomDefinitionId: symptomDefinitionId,
      date: DateTime(date.year, date.month, date.day),
      severity: severity,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
    await saveRecord(record);
  }

  void _sortDefinitions() {
    _definitions.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.name.compareTo(b.name);
    });
  }

  void _sortRecords() {
    _records.sort((a, b) {
      final dateCompare = b.dateKey.compareTo(a.dateKey);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.symptomDefinitionId.compareTo(b.symptomDefinitionId);
    });
  }
}

class SqfliteSymptomStorage implements SymptomStorage {
  static const _definitionTable = 'symptom_definitions';
  static const _recordTable = 'symptom_records';

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
  Future<List<SymptomDefinition>> fetchDefinitions() async {
    final db = await _db;
    final rows = await db.query(
      _definitionTable,
      orderBy: 'sortOrder ASC, name ASC',
    );
    return rows.map(SymptomDefinition.fromMap).toList();
  }

  @override
  Future<List<SymptomRecord>> fetchRecords() async {
    final db = await _db;
    final rows = await db.query(
      _recordTable,
      orderBy: 'date DESC, symptomDefinitionId ASC',
    );
    return rows.map(SymptomRecord.fromMap).toList();
  }

  @override
  Future<void> upsertRecord(SymptomRecord record) async {
    final db = await _db;
    try {
      await db.insert(
        _recordTable,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateSymptomRecordException();
      }
      rethrow;
    }
  }
}

class InMemorySymptomStorage implements SymptomStorage {
  InMemorySymptomStorage({
    List<SymptomDefinition>? definitions,
    List<SymptomRecord>? records,
  }) : _definitions = List.of(definitions ?? defaultSymptomDefinitions()),
       _records = List.of(records ?? const []);

  final List<SymptomDefinition> _definitions;
  final List<SymptomRecord> _records;

  @override
  Future<List<SymptomDefinition>> fetchDefinitions() async {
    return List.of(_definitions);
  }

  @override
  Future<List<SymptomRecord>> fetchRecords() async {
    return List.of(_records);
  }

  @override
  Future<void> upsertRecord(SymptomRecord record) async {
    final index = _records.indexWhere(
      (item) =>
          item.dateKey == record.dateKey &&
          item.symptomDefinitionId == record.symptomDefinitionId,
    );
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }
}

List<SymptomDefinition> defaultSymptomDefinitions() {
  final now = DateTime(2026, 8, 26);
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
    SymptomDefinition(
      id: 'symptom-nausea',
      name: '메스꺼움',
      isDefault: true,
      isActive: true,
      sortOrder: 30,
      createdAt: now,
      updatedAt: now,
    ),
    SymptomDefinition(
      id: 'symptom-dizziness',
      name: '어지러움',
      isDefault: true,
      isActive: true,
      sortOrder: 40,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
