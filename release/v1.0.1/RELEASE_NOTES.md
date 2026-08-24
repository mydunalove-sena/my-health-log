# My Health Log V1.0.1 V2 Release

Release Type: Internal Portfolio V2 Release

Version: 1.0.1+2

## V2 Scope

- Added local JSON backup for HealthRecord, Medication, MedicationLog, and LabResult data.
- Added backup metadata: app name, backup version, createdAt, appVersion.
- Added JSON restore with validation before applying changes.
- Restore replaces current local data inside a SQLite transaction.
- Restore keeps current data intact if validation or replacement fails.
- Added Data Management screen from the Home app bar.
- Added Android share sheet and document picker integration.
- Preserved V1 CRUD, soft delete, statistics, and DB version 3 behavior.

## Not Changed

- No DB schema change
- DB version remains 3
- No Health CRUD change
- No Medication CRUD or MedicationLog behavior change
- No Lab CRUD change
- No medical judgment or interpretation added
- Existing V1.0.0 release artifact was not modified

## Verification

- flutter pub get: PASS
- flutter analyze: PASS, No issues found
- flutter test: PASS, 71 tests passed
- Gradle assembleDebug: PASS
- flutter build apk --release: PASS
- Release APK install: PASS
- Release APK launch smoke test: PASS
- V2 backup/restore automated coverage: PASS
- V1 regression: PASS

## Build Notes

- Android compileSdk was pinned to 36 for the app and Android plugin subprojects because current plugin metadata requires API 36 or later.
- Gradle direct release builds can include the dev-only integration_test plugin in GeneratedPluginRegistrant. Use `flutter build apk --release` for release artifact generation.
- Samsung SM-S918N real-device QA found a development ADB sideload environment issue where generic `adb install -r` could leave My Health Log installed in Samsung DUAL_APP User 95, causing duplicate launcher icons. This was classified as `Test Environment / ADB Multi-user Installation`, not as an app Launcher/UI defect.
- Real-device QA APK updates should use `adb install --user 0 -r ...`, then verify User 0 contains `com.example.my_health_log` and User 95 does not.
