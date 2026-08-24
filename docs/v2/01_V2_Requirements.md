# My Health Log V2 Requirements

## Goal

V2 adds local JSON backup and full restore for user-entered My Health Log data while preserving V1 behavior and data structure.

## Current V1 Baseline

- Project path: local Flutter workspace for `my_health_log`.
- Flutter project detected from `pubspec.yaml`, `lib/main.dart`, and implemented entities.
- Git repository: not present in the project directory.
- Local storage: sqflite / SQLite.
- Database: `my_health_log.db`, version 3.
- Tables: `health_records`, `medications`, `medication_logs`, `lab_results`.
- Soft delete: `medications.isActive = 0` preserves past `medication_logs`.
- Date keys: `yyyy-MM-dd`.
- Date-time values: ISO-8601 strings.

## In Scope

- Create one JSON backup containing all user-entered records.
- Include backup metadata: app name, backup version, creation time, app version.
- Allow empty data backup.
- Save the generated backup JSON through the Android system file save UI so the user can choose a folder such as Downloads.
- Use the Storage Access Framework style document flow without broad storage permissions.
- Keep backup sharing available as a separate optional action through the platform share sheet.
- Pick a JSON backup file for restore.
- Validate before applying restore.
- Reject invalid JSON, other app files, unsupported versions, missing structures, and corrupted records.
- Restore by replacing all current data with the backup data.
- Refresh loaded app state after restore.
- Use SQLite transaction for replacement.
- Keep current data intact if restore fails.

## Out of Scope

- Login.
- Server storage.
- Cloud sync.
- Samsung Health or InBody integration.
- Automatic scheduled backup.
- Medical interpretation or recommendation.

## UI

V1 has no Settings screen. V2 adds one minimal access point from the Home app bar using the existing Material style. It does not add a bottom navigation tab.

The Data Management screen includes:

- `백업 파일 저장`
- `백업 파일 공유`
- `데이터 복원`
- Busy state to prevent duplicate taps.
- Save success feedback with the saved backup file name.
- Restore warning and confirmation dialog.
