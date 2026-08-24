# Backup Data Specification

## Top-Level JSON

```json
{
  "app": "My Health Log",
  "backupVersion": 1,
  "createdAt": "ISO-8601",
  "appVersion": "1.0.1+2",
  "data": {
    "healthRecords": [],
    "medications": [],
    "medicationLogs": [],
    "labResults": []
  }
}
```

## File Name

Default generated file name:

```text
my_health_log_backup_YYYYMMDD_HHMMSS.json
```

## Entity Fields

The backup uses the existing model `toMap()` / `fromMap()` structures so restore preserves the same fields used by SQLite.

### healthRecords

- `id`: string
- `date`: `yyyy-MM-dd`
- `weight`: number or null
- `systolicBloodPressure`: number or null
- `diastolicBloodPressure`: number or null
- `waterIntake`: number or null
- `steps`: number or null
- `sleepHours`: number or null
- `condition`: string or null
- `createdAt`: ISO-8601 string
- `updatedAt`: ISO-8601 string

### medications

- `id`: string
- `name`: string
- `dose`: string or null
- `morning`: 1 or 0
- `lunch`: 1 or 0
- `evening`: 1 or 0
- `bedtime`: 1 or 0
- `isActive`: 1 or 0
- `createdAt`: ISO-8601 string
- `updatedAt`: ISO-8601 string

### medicationLogs

- `id`: string
- `medicationId`: string
- `date`: `yyyy-MM-dd`
- `timeSlot`: string
- `isTaken`: 1 or 0
- `takenAt`: ISO-8601 string or null
- `createdAt`: ISO-8601 string
- `updatedAt`: ISO-8601 string

### labResults

- `id`: string
- `date`: `yyyy-MM-dd`
- `testName`: string
- `value`: number
- `unit`: string or null
- `createdAt`: ISO-8601 string
- `updatedAt`: ISO-8601 string

## Restore Policy

- Restore is full replacement.
- `medication_logs` are restored after `medications` to preserve relationships.
- `medicationLogs.medicationId` must reference a medication in the same backup.
- Home and Statistics cache/display state is not backed up because it is derived from stored records.

