# My Health Log V3 Change History

## 2026-08-24 - Future Date Protection

### Requirement

Health records and lab results represent events that have already occurred. Past dates and today are valid; future dates are invalid.

### Implementation

- Added service-level future-date validation to `HealthRecordService`.
- Added service-level future-date validation to `LabResultService`.
- Added dedicated future-date exceptions.
- Limited Health DatePicker to today.
- Limited Lab DatePicker to today.
- Added safe DatePicker initialization for legacy records whose stored date is already in the future.
- Preserved pre-existing future records/results internally instead of deleting them.
- Excluded pre-existing future health/lab data from normal UI-facing lists/groups used by Statistics.

### Automated QA

- `flutter analyze`: PASS
- Future-date automated tests: 12 PASS
- Full regression: 85 PASS
- Android manual QA: Health DatePicker future dates disabled
- Android manual QA: Lab DatePicker future dates disabled

## 2026-08-25 - P0-2 Scheduled Medication / PRN / Dose Units

### Requirement

Support real-life scheduled and PRN medication patterns while preserving V2 medication data. Dose entry supports decimal values and selectable units `정`, `mg`, and `ml`.

### Implementation

- DB version 3 -> 4 migration.
- Added medication type (`scheduled` / `prn`).
- Added structured `doseValue` and `doseUnit`.
- Preserved legacy `dose` text for compatibility.
- Added PRN actual-dose table allowing multiple events per day.
- Added PRN actual date/time, dose, unit, and optional note.
- Kept existing scheduled MedicationLog behavior.
- Upgraded backup format to version 2 while accepting backup version 1.

### Automated QA

- `flutter analyze`: PASS
- Existing medication regression: 10 PASS
- V3 P0-2 feature tests: 12 PASS
- Backup compatibility regression: 10 PASS
- Full regression: 99 PASS
- `git diff --check`: PASS

### Android Manual QA

- DB v3 -> v4 migration preserved existing medication data.
- Existing V2 medications were treated as scheduled medications.
- Scheduled medication groups and take buttons remained functional.
- Dose-unit selector displayed `정`, `mg`, and `ml`.
- Decimal dose `0.5mg` saved and displayed correctly.
- `2.5ml` saved and displayed correctly.
- PRN type removed scheduled time-slot requirements.
- PRN medication saved without a scheduled time slot.
- PRN medication appeared in a separate section without a missed-dose state.
- One actual PRN dose was recorded and displayed.
- Two PRN doses on the same date were stored separately and displayed as two doses.
- Editing an existing scheduled medication updated the same record without creating a duplicate.

### Result

P0-2 scheduled medication / PRN / structured-dose implementation passed automated and Android manual QA.

## 2026-08-25 - P0-3 Dose Change History / Scheduled Dose Snapshot

### Requirement

Medication dose edits must not rewrite the meaning of past medication records. New dose changes must be traceable without fabricating unknown historical dose information.

### Planned Implementation

- DB version 4 -> 5 migration.
- Add `medication_dose_history`.
- Add scheduled MedicationLog dose snapshot fields.
- Create dose-history events only for semantic dose changes.
- Snapshot current scheduled dose when a dose is marked taken.
- Preserve an existing taken snapshot after later medication edits.
- Do not backfill unknown pre-V5 log doses.
- Show dose-change history on the medication edit screen.
- Upgrade backup format to version 3 while accepting versions 1 and 2.
- Add automated QA and Android migration/manual checks.

### QA Status

Pending local application and validation.

### P0-3 Manual QA Bug Fix

- Found during Android manual QA: a scheduled medication taken at `0.75?? displayed the later current dose `1mg` after the medication was edited.
- Root cause: the dose snapshot was stored correctly in `MedicationLog`, but Medication/Home UI rendered the current `Medication` dose.
- Fixed Medication and Home UI to render `MedicationLog.displayDoseSnapshot` for taken scheduled doses.
- Untaken scheduled doses continue to render the current medication dose.
- Legacy taken logs without a V5 snapshot do not fabricate a historical dose.

### Final QA Result

- DB v4 -> v5 migration preserved existing medication data on Android.
- Dose change `0.75??-> 1mg` created a visible dose-history event.
- Scheduled dose taken at `0.75?? kept its historical snapshot after the medication was edited to `1mg`.
- Medication screen displays `0.75?? for the completed historical dose.
- Home preview displays `?꾩묠 쨌 0.75??쨌 蹂듭슜 ?꾨즺`.
- Untaken medication rows continue to show the current configured dose.
- `flutter analyze`: PASS
- P0-3 + snapshot focused tests: 15 PASS
- Full regression: 114 PASS
- `git diff --check`: PASS

### Result

P0-3 medication dose history and scheduled-dose snapshot preservation passed automated and Android manual QA.

## 2026-08-26 - P0-4 Symptom Recording

### Requirement

Record date-specific symptoms with a fixed four-level severity scale while keeping symptoms independent from PRN medication and preserving existing health, medication, lab, and statistics behavior.

### Implementation

- DB version 5 -> 6 migration.
- Added `symptom_definitions` and `symptom_records`.
- Seeded a small default symptom list: `두통`, `피로`, `메스꺼움`, `어지러움`.
- Added fixed severity values: `없음`, `약함`, `보통`, `심함`.
- Added date+symptom uniqueness so saving the same symptom on the same date updates the existing record.
- Added symptom model and service/storage following the existing in-memory and sqflite service pattern.
- Added a simple Health-tab entry point and symptom record screen.
- Kept symptom records independent from PRN logs; P0-5 linkage is not implemented.
- Did not add symptom backup/restore; P0-6 remains deferred.
- Did not add user symptom add/edit; P1 remains deferred.

### Automated QA

- `dart format`: PASS
- `flutter analyze`: PASS
- Symptom focused tests: 6 PASS
- Full regression: 120 PASS

### Result

P0-4 symptom recording passed local automated QA. P0-5 symptom-to-PRN linkage, P0-6 symptom backup/restore, and P1 user symptom add/edit remain unimplemented.

## 2026-08-26 - P0-5 PRN Symptom Links

### Requirement

Allow a PRN medication log to optionally reference related symptoms without changing symptom records, symptom severity, or implying cause/effect.

### Implementation

- DB version 6 -> 7 migration.
- Added `prn_symptom_links` with `prnMedicationLogId`, `symptomDefinitionId`, and `createdAt`.
- Added a unique constraint on `prnMedicationLogId + symptomDefinitionId`.
- Added indexes for PRN-log and symptom-definition lookup.
- Added `PrnSymptomLink` model.
- Extended `MedicationService.recordPrnTaken(...)` with optional `symptomDefinitionIds`.
- Deduplicated repeated symptom IDs before saving links.
- Stored PRN log and symptom links together through the medication storage layer.
- Deleted PRN symptom links before deleting a PRN log.
- Added PRN log link lookup by `prnMedicationLogId`.
- Added optional related-symptom checkboxes to the PRN log form.
- Displayed linked symptoms with neutral text: `관련 증상: ...`.
- Kept `symptom_records` independent; PRN symptom selection does not create or update symptom records.
- Did not add symptom backup/restore; P0-6 remains deferred.
- Did not add user symptom add/edit; P1 remains deferred.

### Manual QA Bug Fix

- Found during Android manual QA: when the same PRN medication had two logs today, an older linked log at `02:16` and a latest unlinked log at `02:22`, the medication screen only made the latest PRN state visible.
- Root cause: the PRN medication row displayed linked symptoms from the latest PRN log only.
- Fixed the PRN medication row to keep the existing `오늘 N회 복용 · latest time` summary while listing today's PRN logs separately.
- Each displayed PRN log resolves related symptoms by its own `PrnMedicationLog.id`.
- A PRN log without related symptoms does not display symptoms from another PRN log.

### Automated QA

- `flutter analyze`: PASS, No issues found, exit code 0
- P0-5 focused tests, `flutter test test/prn_symptom_link_test.dart`: 14 PASS, 0 FAIL, exit code 0
- Full regression, `flutter test`: 134 PASS, 0 FAIL, exit code 0

### Android Manual QA

- Device: MyHealthLog_API37 / emulator-5554.
- Latest build installed and launched successfully.
- Same PRN medication had two logs today.
- `02:22`: no related symptoms.
- `02:16`: related symptoms were `두통 · 어지러움`.
- Medication screen showed `오늘 2회 복용 · 02:22`, `02:22`, `02:16`, and `관련 증상: 두통 · 어지러움` as separated log details.
- The latest unlinked log did not inherit symptoms from the older linked log.
- The older linked log's symptoms remained visible after adding the latest log.
- Existing stored data was preserved.
- Android manual QA: PASS.

### Result

P0-5 PRN symptom links passed automated and Android manual QA. P0-6 symptom backup/restore and P1 user symptom add/edit remain unimplemented.

## 2026-08-26 - P0-6 Symptom Backup / Restore

### Requirement

Include symptom definitions, symptom records, and PRN symptom links in local JSON backup/restore while preserving the existing full-replacement restore policy.

### Implementation

- Upgraded backup format to backupVersion 4.
- Included `symptom_definitions`, `symptom_records`, and `prn_symptom_links` in backup snapshots.
- Restore replaces existing symptom definitions, symptom records, and PRN symptom links with the backup snapshot.
- Backup versions 1, 2, and 3 remain accepted; missing symptom collections restore as empty.
- Kept `BackupService`, DB replacement semantics, and schema focused on P0-6 backup/restore only.
- Did not add user symptom add/edit; P1 remains deferred.

### Manual QA Bug Fix

- Found during Android manual QA: after restore, DB `symptom_records` were restored correctly, and MedicationService reloaded immediately, but SymptomService did not reload.
- Symptom screen therefore showed stale in-memory values immediately after restore.
- Force-stopping and relaunching the app showed the restored symptom values, confirming DB restore succeeded and only in-memory refresh was missing.
- Fixed the restore success path by passing SymptomService into DataManagementScreen and running `SymptomService.load()` with the existing service reloads.
- Kept existing `MedicationService.load()` refresh behavior.
- Added a widget regression test that restores a backup snapshot after stale symptom and medication state and verifies both services contain the restored values.

### Automated QA

- `flutter analyze`: PASS, No issues found, exit code 0.
- P0-6 focused tests, `flutter test test/backup_service_test.dart test/data_management_screen_test.dart`: 19 PASS, 0 FAIL, exit code 0.
- Full regression, `flutter test`: 143 PASS, 0 FAIL, exit code 0.

### Android Manual QA

- Device: MyHealthLog_API37 / emulator-5554.
- backupVersion 4 backup file created successfully.
- Backup file verified in `/sdcard/Download`: `my_health_log_backup_20260826_061054.json`, 9263 bytes.
- Backup symptom state: headache mild, fatigue severe, nausea none, dizziness none.
- Post-backup changed symptom state: headache severe, fatigue mild.
- After restore, symptom state returned to headache mild, fatigue severe, nausea none, dizziness none.
- Backup PRN state: two doses today; `02:22` had no related symptoms; `02:16` had headache and dizziness.
- Post-backup changed PRN state: added `06:21` PRN log with fatigue.
- After restore, the `06:21` PRN log was removed, today's PRN count returned to two, `02:22` still had no related symptoms, and `02:16` still had headache and dizziness.
- PRN log and `prn_symptom_links` replace/restore behavior confirmed.
- After the SymptomService refresh fix, Android re-QA confirmed restore immediately updated the symptom screen without app restart: headache mild and fatigue severe.
- Android manual QA: PASS.

### Result

P0-6 symptom backup/restore passed automated regression and Android manual QA. Restore now refreshes SymptomService in memory before showing restore success, so restored symptom values are visible immediately without app restart.

## 2026-08-26 - P0-7 Full P0 Regression

### Scope

- P0-1 future date protection.
- P0-2 scheduled medication, PRN medication, and decimal dose.
- P0-3 medication dose history and scheduled dose snapshot.
- P0-4 symptom recording.
- P0-5 PRN related-symptom links.
- P0-6 symptom and PRN symptom-link backup/restore.

### Automated QA

- `flutter analyze`: PASS, exit code 0.
- Full regression, `flutter test`: 143 PASS, 0 FAIL, exit code 0.
- P0-1 through P0-6 automated test coverage confirmed.

### Android Evidence

- P0-4 symptom recording save/display manual QA completed.
- P0-5 linked and unlinked PRN logs, including per-log related-symptom separation, manual QA completed.
- P0-6 backupVersion 4 real file save confirmed.
- P0-6 `symptom_records` backup/restore confirmed.
- P0-6 PRN log and `prn_symptom_links` replace/restore confirmed.
- P0-6 restore-time SymptomService refresh bug was fixed and passed Android re-QA.
- Latest code was run and verified on emulator-5554 with `flutter run`.

### Result

P0-7 full P0 regression passed. P0-1 through P0-6 are accepted for the V3 P0 scope.

## 2026-08-27 - P1-1 Health Field Visibility

### Requirement

Allow users to hide unused health-record fields from the visible UI without deleting or changing existing health-record data.

### Implementation

- Added `HealthFieldVisibilityService`.
- Stored field visibility settings with `SharedPreferences`.
- Default visibility is all-visible.
- Added health field visibility settings UI for weight, blood pressure, water, exercise, sleep, and condition.
- Kept date outside the hideable field set.
- Applied visibility settings to Home today's health card.
- Applied visibility settings to the health record list.
- Applied visibility settings to the health record add/edit screen.
- Applied visibility settings to Statistics.
- Hiding weight removes the weight statistics tab.
- Hiding blood pressure removes the blood pressure statistics tab.
- Lab statistics tab remains available.
- Preserved hidden health-record field values when editing and saving while those fields are hidden.
- Showing a field again displays the existing stored value.
- Kept `HealthRecord` and the `health_records` schema unchanged.
- No DB migration was added for P1-1.
- P1-1 visibility settings are not included in backup.
- `BackupService` was not changed for P1-1.
- backupVersion remains 4.
- At the time of P1-1 completion, P1-2 water optionalization and P1-3 user symptom add/edit remained deferred.

### Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-1 focused tests, `flutter test test/health_field_visibility_test.dart`: 7 PASS, 0 FAIL.
- Full regression, `flutter test`: 150 PASS, 0 FAIL, exit code 0.

### Android Manual QA

- Initial field visibility settings showed weight, blood pressure, water, exercise, sleep, and condition ON.
- Created the baseline 2026.08.27 health record with weight `55.5 kg`, blood pressure `120 / 80 mmHg`, water `1500 mL`, exercise `5000 steps`, sleep `7.5 시간`, and condition `보통`.
- With water OFF and sleep OFF, the health record list and edit screen hid water and sleep while other health UI remained visible.
- Editing and saving while water/sleep were hidden preserved water `1500` and sleep `7.5`; weight was updated from `55.5` to `55.6` and saved normally.
- After full app close and relaunch, water OFF and sleep OFF persisted and the edit screen still hid both fields.
- With weight, blood pressure, water, and sleep hidden, Home today's health showed exercise and condition while hiding those four fields.
- With weight OFF and blood pressure OFF, Statistics hid weight and blood pressure while the lab tab remained visible and functional.
- After all six fields were turned back ON, Home showed weight `55.6 kg`, blood pressure `120 / 80 mmHg`, water `1500 mL`, exercise `5000`, sleep `7.5 시간`, and condition `보통`.
- The health record edit screen showed all six input UIs and existing values after all fields were restored.
- Statistics restored the weight and blood pressure tabs after all fields were turned back ON and displayed weight `55.6 kg` and blood pressure `120 / 80 mmHg`.
- Android manual QA: PASS.

### Result

P1-1 health field visibility passed automated QA and Android manual QA. P1-1 is complete. P1-2 water optionalization and P1-3 user symptom add/edit remained deferred at the time of P1-1 completion.

## 2026-08-27 - P1-2 Optional Water Input

### Requirement

Make water intake optional in the visible health-record UI without adding a separate toggle, deleting hidden values, or changing the health-record data model.

### Implementation

- No production code changes were needed for P1-2.
- Existing `HealthRecord.waterIntake` nullable structure satisfies the optional value requirement.
- Existing `HealthFormScreen` blank-input handling saves visible blank water as `null`.
- Existing positive-integer validation rejects `0`; `0` is not treated as the same state as `null`.
- Clearing an existing visible water value and saving explicitly removes the value by saving `waterIntake` as `null`.
- Existing P1-1 visibility behavior preserves `waterIntake` when water is hidden and another health field is edited.
- No separate water toggle, checkbox, water-specific setting, or "not recorded" state was added.
- No water statistics were added.
- Home display policy was not changed.
- Kept `HealthRecord` and the `health_records` schema unchanged.
- No DB migration was added for P1-2.
- `BackupService` was not changed for P1-2.
- backupVersion remains 4.
- At the time of P1-2 completion, P1-3 user symptom add/edit remained deferred.

### Regression Test Stabilization

- Stabilized the existing P0-5 PRN symptom-link UI regression test by removing `DateTime.now()` dependency from the failing test case.
- Reused one deterministic test date for both medication-service loading and PRN log `takenAt`.
- Assertion meaning was unchanged.
- No production code was changed for the PRN regression stabilization.

### Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-2 focused tests, `flutter test test/health_water_optional_test.dart`: 6 PASS, 0 FAIL.
- Impacted existing tests, `flutter test test/widget_test.dart test/health_field_visibility_test.dart`: 24 PASS, 0 FAIL.
- PRN regression, `flutter test test/prn_symptom_link_test.dart`: 14 PASS, 0 FAIL.
- Full regression, `flutter test`: 156 PASS, 0 FAIL, exit code 0.

### Android Manual QA

- Water left blank with other health values present saved successfully and remained blank after reopening.
- Water `1500 mL` saved successfully and remained `1500` after reopening.
- Existing visible water value `1500` was cleared, saved, and remained blank after reopening.
- Water `0` was rejected with validation message `수분은 0보다 큰 값으로 입력해주세요.` and was not saved.
- With water `1500` saved, hiding water through P1-1 visibility, editing another health field, and showing water again preserved `1500`.
- Android manual QA: PASS.

### Result

P1-2 optional water input passed automated QA and Android manual QA. P1-2 is complete. P1-3 user symptom add/edit remained deferred at the time of P1-2 completion.

## 2026-08-27 - P1-3 User Symptom Add/Edit

### Requirement

Allow users to add custom symptom definitions and rename only user-added symptom definitions while preserving existing symptom records and PRN symptom links.

### Implementation

- Extended `SymptomService` and `SymptomStorage` with symptom definition management.
- Added user symptom definition creation.
- Added user symptom rename.
- Stored added user symptoms with `isDefault = false` and `isActive = true`.
- Preserved symptom definition id during rename.
- Blocked rename for built-in default symptoms.
- Kept built-in default symptoms unchanged: `두통`, `피로`, `메스꺼움`, and `어지러움`.
- Added service-layer validation for blank names and exact duplicate active names.
- Trimmed symptom names before saving.
- Allowed rename to the current symptom's own existing name.
- Did not add arbitrary length limits or case-insensitive duplicate matching.
- Added a symptom management screen reachable from the symptom record screen.
- Displayed active symptom definitions with default/user distinction.
- Provided edit action only for user-added symptoms.
- Did not add symptom delete, deactivate, reorder, icon, color, category, statistics, severity changes, or PRN effect/cause analysis.
- Preserved existing `symptom_records` rows and severities after rename.
- Preserved existing `prn_symptom_links` rows after rename.
- Existing symptom records and existing PRN links display the renamed symptom definition name.
- Medication screen now listens to `SymptomService` changes so renamed PRN symptom names refresh immediately.
- Kept `symptom_definitions`, `symptom_records`, and `prn_symptom_links` schema unchanged.
- No DB migration was added for P1-3.
- `BackupService` production code was not changed for P1-3.
- backupVersion remains 4.

### Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-3 focused tests, `flutter test test/symptom_definition_management_test.dart`: 12 PASS, 0 FAIL.
- Impacted existing tests, `flutter test test/symptom_test.dart test/prn_symptom_link_test.dart test/backup_service_test.dart test/data_management_screen_test.dart test/widget_test.dart`: 57 PASS, 0 FAIL.
- Backup regression, `test/backup_service_test.dart`: 19 PASS, including user-added and renamed symptom definition, symptom record, and PRN symptom link backupVersion 4 round-trip.
- Full regression, `flutter test`: 169 PASS, 0 FAIL, exit code 0.

### Android Manual QA

- Symptom management opened from the symptom record screen top action.
- User symptom `목통증` was added and displayed as a user symptom distinct from default symptoms.
- Symptom record screen displayed `목통증`, and severity `심함` saved and remained available.
- PRN log form displayed `목통증` in related symptoms, and the user symptom could be linked to a PRN log.
- User symptom rename from `목통증` to `목 통증` worked.
- Built-in default symptoms had no edit action.
- After rename, the existing symptom record preserved severity `심함` and displayed `목 통증`.
- After rename, the existing PRN link remained and displayed `목 통증`.
- Blank names and duplicate names were blocked.
- After full app close and relaunch, the user symptom, renamed name, symptom record, and PRN link persisted.
- Android backup/restore was not repeated for P1-3 because backup/restore production code was unchanged and backupVersion 4 round-trip was covered by automated regression.
- Android manual QA: PASS.

### Result

P1-3 user symptom add/edit passed automated QA and Android manual QA. P1-3 is complete.

## 2026-08-27 - V3 Final Regression

### Scope

- P0-1 through P0-7.
- P1-1 health field visibility.
- P1-2 optional water input.
- P1-3 user symptom add/edit.

### Automated QA

- `flutter analyze`: PASS, No issues found, exit code 0.
- Health/Future/Visibility/Water/Statistics/Widget grouped regression: 68 PASS, 0 FAIL, exit code 0.
- Medication/Dose/PRN/Symptom/P1-3 grouped regression: 69 PASS, 0 FAIL, exit code 0.
- Backup/Restore/Data management/Lab grouped regression: 32 PASS, 0 FAIL, exit code 0.
- Full regression, `flutter test`: 169 PASS, 0 FAIL, exit code 0.

### Android Regression

- Android V3 full regression: PASS.

### Result

V3 final automated regression passed. Android V3 full regression was already completed and passed.

## 2026-08-27 - V3 Release APK

### Build

- Command: `flutter build apk --release`.
- Result: PASS, exit code 0.
- Original APK: `build\app\outputs\flutter-apk\app-release.apk`.
- External local release copy: `MyHealthLog_V3_Release_20260827.apk`.
- APK size: 54,099,257 bytes.
- SHA-256: `0A4E1DE8399776889727921663B047D828370131735D49E620F0CEBBB7FB744D`.

### Versioned Data State

- databaseVersion remains 7.
- backupVersion remains 4.
- No DB migration, backup format change, or backupVersion change was added for the release build.

### Result

Release APK generation passed for the verified V3 code state.

## 2026-08-27 - V3 Release Version Alignment

- Prepared official release version `3.0.0+4` for GitHub Release `v3.0.0`.
- Kept databaseVersion 7 and backupVersion 4 unchanged.
- No feature, dependency, DB schema, or backup format change was included.

## 2026-08-28 - V3.0.1 HOT FIX

### Requirement

V3.0.1 addresses immediate V3.0.0 real-use friction without expanding into V3.1.0 scope. The hot fix makes lab-result edit/delete actions visible, improves same-date lab entry after saving, adds read-only medication history lookup for stored scheduled and PRN logs, improves Home today's scheduled-medication display, and fixes statistics list date wrapping on real Android devices.

### Implementation

- Lab date detail rows now expose explicit `수정` and `삭제` actions.
- Existing lab row-tap edit behavior remains available.
- Lab edit form date changes remain supported.
- Lab delete confirmation remains in place.
- Deleting the final result for a date removes the empty date group/detail state.
- Main lab `+` new-save flow opens the saved date's detail screen.
- Detail `+ 검사 항목 추가` keeps the detail date as the initial date for consecutive same-date entry.
- Added a `기록` entry point on today's medication screen while preserving `관리`.
- Added a separate read-only medication history screen.
- Medication history displays actually stored scheduled logs and PRN logs only.
- Missing scheduled logs are not fabricated as missed-dose history.
- Stored scheduled `isTaken == false` logs are displayed as saved missed-dose records.
- Scheduled historical dose uses the stored dose snapshot when present.
- Legacy scheduled logs without snapshots do not fall back to the current medication dose.
- Historical medication-name lookup can use inactive/soft-deleted medication rows through an all-medications read path.
- PRN history uses stored `takenAt`, `doseValue`, and `doseUnit`.
- PRN related symptoms are resolved through existing `prn_symptom_links` and shown neutrally.
- No past medication edit/delete workflow was added.
- No medical causality, effect, risk, diagnosis, or medication-advice interpretation was added.
- Home today's medication display no longer limits scheduled medication rows to three items.
- Home today's scheduled medications are grouped by morning, lunch, evening, and bedtime.
- Empty Home medication time-slot groups are hidden.
- Home medication rows no longer repeat the time-slot label because the group header already provides it.
- Home medication rows keep medication name, dose, taken/not-taken state, and status icon.
- Home completed scheduled doses continue to display historical dose snapshots.
- Home untaken scheduled doses continue to display the current medication dose.
- Home keeps the existing `SingleChildScrollView` so all scheduled medication groups remain reachable when many medications exist.
- The Home medication confirmation button remains after the full grouped medication list.
- PRN medications were not newly displayed on Home.
- No DB, model, service, or Backup change was made for the Home medication display improvement.
- Statistics value-list dates now keep the existing `MM.dd` format on one line.
- The shared `_ValueRow` date display fix applies to weight, blood pressure, and lab statistics lists.
- Statistics chart and x-axis date rendering were not changed.
- No V3.1.0 features were added.

### Compatibility

- databaseVersion remains 7.
- backupVersion remains 4.
- DB schema unchanged.
- Backup payload unchanged.
- Existing V3.0.0 data compatibility preserved.

### Automated QA

- `flutter analyze`: PASS, No issues found.
- Home/widget focused tests, `flutter test test/widget_test.dart`: 19 PASS, 0 FAIL.
- Medication snapshot display focused tests, `flutter test test/medication_snapshot_display_test.dart`: 3 PASS, 0 FAIL.
- Lab focused tests, `flutter test test/lab_result_test.dart`: 18 PASS, 0 FAIL.
- Medication History focused tests, `flutter test test/medication_history_test.dart`: 7 PASS, 0 FAIL.
- Statistics focused tests, `flutter test test/statistics_test.dart`: 27 PASS, 0 FAIL.
- Medication/PRN/Snapshot/Backup regression bundle: 71 PASS, 0 FAIL.
- Full regression, `flutter test`: 185 PASS, 0 FAIL.
- A Lab DatePicker widget-test helper initially failed because it selected the day but did not press OK/confirmation. This was a test automation issue, not a production app bug. After the helper was fixed, the lab focused suite passed 18/18.

### Android Device QA

- Device: SM-S918N, Android 16, device ID R3CW201RKMP.
- Result: 20 PASS, 0 FAIL, 8 BLOCKED.
- Confirmed app functional failure count: 0.
- Launch / force-stop / relaunch 3 cycles passed.
- Lab screen/detail, explicit edit/delete actions, past-date save-to-detail navigation, same-date consecutive entry, edit value preservation, date-change group recalculation, delete cancel, delete confirm, and final QA group removal passed.
- Today's medication screen `기록`/`관리` entry points passed.
- Medication history read-only behavior passed.
- Existing scheduled history display passed.
- Existing stored `isTaken == false` saved missed-dose display passed.
- Medication history lookup did not alter today's medication screen state.
- Persistence/relaunch passed.
- App logcat showed no confirmed app FATAL EXCEPTION or ANR.
- Pre-QA DB snapshot passed.
- Post-QA DB restore passed.
- QA301 test data residual check passed; no QA301 data remained after restore.

### Additional Android Home Medication Check

This was a separate real-device confirmation after the strengthened device QA above. The strengthened device QA count remains 20 PASS, 0 FAIL, 8 BLOCKED.

- Device: SM-S918N, Android 16.
- More than three scheduled medication items displayed on Home: PASS.
- Morning, lunch, evening, and bedtime groups displayed correctly: PASS.
- Empty time-slot groups were hidden: PASS.
- Home scrolling reached the final medication: PASS.
- Medication confirmation button remained reachable: PASS.

### Additional Android Statistics Check

This was a separate real-device confirmation after the strengthened device QA above. The strengthened device QA count remains 20 PASS, 0 FAIL, 8 BLOCKED.

- Device: SM-S918N, Android 16.
- Weight statistics list date displayed on one line: PASS.
- Blood pressure statistics list date displayed on one line: PASS.
- Lab statistics list date displayed on one line: PASS.

### Android Device QA Blocked Items

The following items were recorded as BLOCKED, not FAIL, because protecting real user data prevented broad medication create/dose-change/soft-delete and PRN fixture setup through live-device automation:

- Lab duplicate device automation.
- Medication no-log empty-date device setup.
- Scheduled dose-change snapshot device setup.
- Inactive medication history device setup.
- PRN actual log device setup.
- PRN symptom link device setup.
- PRN no-symptom device setup.
- Multiple PRN logs device setup.

### Result

V3.0.1 HOT FIX passed automated regression and Android device QA with no confirmed functional failures. V3.0.1 keeps databaseVersion 7, backupVersion 4, the existing DB schema, and the existing backup payload unchanged.
