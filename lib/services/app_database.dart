import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static const databaseName = 'my_health_log.db';
  static const databaseVersion = 4;
  static Database? _database;

  static Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, databaseName);
    final database = await openDatabase(
      path,
      version: databaseVersion,
      onCreate: (db, version) async {
        await _createHealthRecords(db);
        await _createMedicationTables(db);
        await _createLabResultTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMedicationTables(db);
        }
        if (oldVersion < 3) {
          await _createLabResultTables(db);
        }
        if (oldVersion >= 2 && oldVersion < 4) {
          await _upgradeMedicationV4(db);
        }
      },
    );
    _database = database;
    return database;
  }

  static Future<void> _createHealthRecords(Database db) async {
    await db.execute('''
CREATE TABLE health_records (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL UNIQUE,
  weight REAL,
  systolicBloodPressure INTEGER,
  diastolicBloodPressure INTEGER,
  waterIntake INTEGER,
  steps INTEGER,
  sleepHours REAL,
  condition TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_health_records_date ON health_records(date)',
    );
  }

  static Future<void> _createMedicationTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS medications (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  medicationType TEXT NOT NULL DEFAULT 'scheduled',
  dose TEXT,
  doseValue REAL,
  doseUnit TEXT,
  morning INTEGER NOT NULL DEFAULT 0,
  lunch INTEGER NOT NULL DEFAULT 0,
  evening INTEGER NOT NULL DEFAULT 0,
  bedtime INTEGER NOT NULL DEFAULT 0,
  isActive INTEGER NOT NULL DEFAULT 1,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS medication_logs (
  id TEXT PRIMARY KEY,
  medicationId TEXT NOT NULL,
  date TEXT NOT NULL,
  timeSlot TEXT NOT NULL,
  isTaken INTEGER NOT NULL DEFAULT 0,
  takenAt TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (medicationId) REFERENCES medications(id),
  UNIQUE (medicationId, date, timeSlot)
)
''');
    await _createPrnMedicationLogs(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_medications_active ON medications(isActive)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_medication_logs_date ON medication_logs(date)',
    );
  }

  static Future<void> _createPrnMedicationLogs(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS prn_medication_logs (
  id TEXT PRIMARY KEY,
  medicationId TEXT NOT NULL,
  date TEXT NOT NULL,
  takenAt TEXT NOT NULL,
  doseValue REAL,
  doseUnit TEXT,
  note TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (medicationId) REFERENCES medications(id)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prn_medication_logs_date ON prn_medication_logs(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prn_medication_logs_medication ON prn_medication_logs(medicationId)',
    );
  }

  static Future<void> _upgradeMedicationV4(Database db) async {
    await db.execute(
      "ALTER TABLE medications ADD COLUMN medicationType TEXT NOT NULL DEFAULT 'scheduled'",
    );
    await db.execute('ALTER TABLE medications ADD COLUMN doseValue REAL');
    await db.execute('ALTER TABLE medications ADD COLUMN doseUnit TEXT');
    await _createPrnMedicationLogs(db);
  }

  static Future<void> _createLabResultTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS lab_results (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  testName TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  UNIQUE (date, testName)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lab_results_date ON lab_results(date)',
    );
  }
}
