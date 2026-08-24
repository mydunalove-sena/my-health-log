# My Health Log V2.0.0

Release Type: Public V2 Release

Version: 2.0.0+3

## Highlights

- Local JSON backup for HealthRecord, Medication, MedicationLog, and LabResult data.
- Backup file save through Android system file save UI.
- Optional backup file share action.
- Full replacement restore with validation before applying data.
- SQLite transaction-based restore to avoid partial replacement on failure.
- Samsung SM-S918N real-device QA coverage.
- Home health summary card regression fix for small Android screens.
- Exercise unit label changed from `steps` to `걸음`.
- ADB multi-user QA installation procedure documented with `adb install --user 0 -r ...`.

## Verification

- `flutter analyze`: PASS
- `flutter test`: PASS, 73 tests
- Android Debug build: PASS
- Android Release build: PASS
- Samsung SM-S918N APK install/run: PASS
- Backup JSON creation: PASS
- Android file save UI: PASS
- Download location backup save: PASS
- Saved JSON restore: PASS
- Full replacement restore: PASS
- Data persistence after app restart: PASS

## Distribution

APK binaries are not tracked in the source repository. The release APK is attached to the GitHub Release for tag `v2.0.0`.
