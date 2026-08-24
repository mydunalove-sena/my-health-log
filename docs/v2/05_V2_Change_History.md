# V2 Change History

## V1 Baseline

- V1 was implemented as a Flutter Android app with local SQLite persistence.
- Database version was 3 before V2.
- Existing entities were `HealthRecord`, `Medication`, `MedicationLog`, and `LabResult`.
- Existing tests covered core CRUD, validation, statistics, and regression flows.

## V2 Changes

- Added local JSON backup/restore service.
- Added SQLite snapshot repository using transaction-based full replacement.
- Added backup validation for app identity, version, required data structure, record parsing, and medication log relationships.
- Added Data Management UI from the Home app bar.
- Added file picker, path provider, and share sheet dependencies.
- Added automated backup/restore tests including round-trip integrity.
- Added V2 documentation.
- Updated Android build configuration to use compileSdk 36 for the app and Android plugin subprojects.
- Built and installed the V2 release APK on the connected Android emulator.
- Split backup into `백업 파일 저장` and `백업 파일 공유` after Samsung SM-S918N manual QA showed that Share Sheet alone did not provide a reliable direct file-save path.
- Added Android system save-file flow for backup JSON using the existing file picker dependency and no broad storage permission.
- Added save completion feedback with the generated backup file name.
- Fixed Samsung SM-S918N Home health summary card regression where blood pressure and exercise values wrapped awkwardly on small screens.
- Changed Home exercise summary unit from `steps` to `걸음`.
- Added narrow Android screen widget regression coverage for Home health summary cards.
- Documented Samsung SM-S918N ADB multi-user installation finding: duplicate launcher icons were classified as a development QA environment issue caused by User 95 (Samsung DUAL_APP), not as an app Launcher/UI defect.
- Updated real-device QA install procedure to use `adb install --user 0 -r ...`, verify User 0/User 95 package state, and recover incorrect User 95 installs with `adb shell pm uninstall --user 95 com.example.my_health_log`.

## Changed Files

- `pubspec.yaml`
- `pubspec.lock`
- `lib/app.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/data_management/data_management_screen.dart`
- `lib/services/backup_service.dart`
- `test/backup_service_test.dart`
- `android/app/build.gradle.kts`
- `android/build.gradle.kts`
- `docs/v2/01_V2_Requirements.md`
- `docs/v2/02_Backup_Data_Specification.md`
- `docs/v2/03_V2_Test_Cases.md`
- `docs/v2/04_V2_Regression_Result.md`
- `docs/v2/05_V2_Change_History.md`
- `README.md`
- `release/v1.0.1/MyHealthLog-v1.0.1.apk`
- `release/v1.0.1/RELEASE_NOTES.md`
- `release/v1.0.1/SHA256.txt`

## Known Limitations

- The project directory is not a Git repository, so no feature branch, commit, or push was created from this workspace.
- Actual Android share sheet and document picker behavior must be manually verified on device.
- Real-device ADB sideload QA must target User 0 explicitly on Samsung devices that expose DUAL_APP or Secure Folder users.
- `flutter --version --suppress-analytics` did not return in this shell session, although `flutter pub get`, `flutter analyze`, and `flutter test` executed successfully.
- `flutter build apk --debug` did not return cleanly in this shell session, but direct Gradle `assembleDebug` completed successfully.
