# V2 Regression Result

## Automated Results

| Command | Result |
|---|---|
| `dart format lib\core\widgets\health_summary_card.dart lib\screens\home\home_screen.dart test\widget_test.dart` | PASS |
| `flutter analyze` | PASS: no issues found |
| `flutter test` | PASS: 73 tests passed |
| `android\gradlew.bat -p android assembleDebug` with Android Studio JBR `JAVA_HOME` | PASS |
| `flutter build apk --release` | PASS: `build\app\outputs\flutter-apk\app-release.apk` |

## V1 Regression Coverage

Covered by existing automated tests:

- Home navigation and today summary.
- Health add/edit/delete, validation, duplicate date prevention, null display behavior.
- Medication add/edit, soft delete, today toggle, medication log preservation.
- Lab add/edit/delete, date grouping, duplicate prevention.
- Statistics navigation, health/lab data display, empty state paths.

## V2 Coverage

Covered by `test/backup_service_test.dart`:

- Empty backup.
- Stable timestamped backup file name: `my_health_log_backup_YYYYMMDD_HHMMSS.json`.
- Mixed entity backup.
- Null, zero, Korean, special character, and long string preservation.
- Metadata and backupVersion validation.
- Invalid JSON, other app, missing version, unsupported version, malformed data rejection.
- Full replacement restore.
- ID and relationship preservation.
- Failure rollback.
- Repeat restore without duplicates.
- Backup -> delete/change -> restore round trip.

## Real Device Findings

Manual QA on Samsung SM-S918N found that the previous `데이터 백업` action generated JSON and opened only the Android Share Sheet. On that device, the Share Sheet did not provide a reliable "save to My Files" or direct folder selection path, which made it difficult to keep the backup JSON in phone storage for restore testing.

Final regression QA on Samsung SM-S918N also found that Home health summary card values could wrap awkwardly on smaller Android screens. The affected examples were blood pressure (`120 / 80 mmHg`) and exercise (`4,000 steps`).

Final real-device installation QA on Samsung SM-S918N found duplicate My Health Log launcher icons after a development APK update. The test device had multiple Android user areas: User 0 (default user), User 95 (Samsung DUAL_APP), and User 150 (Secure Folder). Current evidence classifies this as `Test Environment / ADB Multi-user Installation`, not as an app UI or Launcher code defect.

Observed installation issue:

- Classification: Test Environment / ADB Multi-user Installation
- Device: Samsung SM-S918N
- Symptom: duplicate My Health Log icons after development APK update
- Cause: generic ADB install in a multi-user Samsung test environment also installed or retained the package in Samsung DUAL_APP User 95
- Scope: verified for development ADB sideload QA only; this does not establish that the same behavior occurs for Google Play production updates
- App defect status: not confirmed as an app functional defect

## Fix Results

- Data Management separates backup actions into `백업 파일 저장` and `백업 파일 공유`.
- `백업 파일 저장` uses the platform save-file flow from `file_picker`, which opens Android's `ACTION_CREATE_DOCUMENT` Storage Access Framework UI and writes the JSON bytes to the user-selected document.
- The generated JSON structure and restore validation/replacement logic are unchanged.
- No broad Android storage permission was added.
- On successful save, the app shows a completion message containing the file name.
- Home health summary card values now stay on one line and scale down within the existing card width instead of wrapping at awkward spaces.
- Home exercise summary now uses the Korean unit `걸음` instead of `steps`.
- A narrow-screen widget regression test covers blood pressure, exercise, weight, water, sleep, and condition card rendering.
- Real-device QA install procedure now targets User 0 explicitly with `adb install --user 0 -r ...`.
- QA procedure now checks package presence for User 0 and User 95 after install.

## Real Device ADB Install Procedure

Before installing on a real Android phone:

```bash
adb shell pm list users
```

Install only for the default user:

```bash
adb install --user 0 -r build/app/outputs/flutter-apk/app-release.apk
```

When using the Android SDK full path:

```bash
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe install --user 0 -r build\app\outputs\flutter-apk\app-release.apk
```

After install:

```bash
adb shell pm list packages --user 0 | findstr my_health_log
adb shell pm list packages --user 95 | findstr my_health_log
```

Expected result:

- User 0: `com.example.my_health_log` exists
- User 95: `com.example.my_health_log` does not exist

If User 95 contains the package, remove it from User 95 only:

```bash
adb shell pm uninstall --user 95 com.example.my_health_log
```

Do not uninstall from User 0 when preserving the default user's app data.

## Manual Required

The following still require an actual Android device or device-backed file picker flow:

- `MANUAL_REQUIRED`: On Samsung SM-S918N, `백업 파일 저장` opens the Android file save UI and saves to a user-selected folder such as Downloads.
- `MANUAL_REQUIRED`: The saved JSON can be selected by `데이터 복원`.
- `MANUAL_REQUIRED`: App relaunch after real-device restore keeps restored SQLite data.
- `MANUAL_REQUIRED`: `백업 파일 공유` still opens the Android Share Sheet as an optional separate action.
- `MANUAL_REQUIRED`: Home health summary cards should be visually rechecked on the real small-screen Android viewport after installing the rebuilt APK.
