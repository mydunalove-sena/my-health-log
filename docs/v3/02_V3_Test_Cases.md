# My Health Log V3 Test Cases

## Future Date Protection

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-DATE-TC-01 | Health | Save today | Saved |
| V3-DATE-TC-02 | Health | Save past date | Saved |
| V3-DATE-TC-03 | Health | Save tomorrow | Rejected |
| V3-DATE-TC-04 | Health | Save far-future date | Rejected |
| V3-DATE-TC-05 | Health | Edit existing record date to future | Rejected; original record retained |
| V3-DATE-TC-06 | Health UI | Open DatePicker | Maximum selectable date is today |
| V3-DATE-TC-07 | Health Service | Direct service save with future date | Rejected |
| V3-DATE-TC-08 | Health/Statistics | Legacy future record exists | Preserved internally; hidden from normal list/statistics |
| V3-DATE-TC-09 | Lab | Save today | Saved |
| V3-DATE-TC-10 | Lab | Save past date | Saved |
| V3-DATE-TC-11 | Lab | Save tomorrow | Rejected |
| V3-DATE-TC-12 | Lab | Save far-future date | Rejected |
| V3-DATE-TC-13 | Lab | Edit existing result date to future | Rejected; original result retained |
| V3-DATE-TC-14 | Lab UI | Open DatePicker | Maximum selectable date is today |
| V3-DATE-TC-15 | Lab Service | Direct service save with future date | Rejected |
| V3-DATE-TC-16 | Lab/Statistics | Legacy future result exists | Preserved internally; hidden from normal list/group/statistics |

## Scheduled Medication / PRN / Dose Units

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-MED-TC-01 | Legacy | Load V2 medication without type | Treated as scheduled |
| V3-MED-TC-02 | Legacy dose | Load `0.5정` | Parsed as 0.5 + 정; original text preserved |
| V3-MED-TC-03 | Legacy dose | Load `10 mg` | Parsed as 10 + mg |
| V3-MED-TC-04 | Legacy dose | Load `2.5ml` | Parsed as 2.5 + ml |
| V3-MED-TC-05 | Legacy dose | Load unstructured free text | Original text preserved |
| V3-MED-TC-06 | Dose | Save 0.25 정 | Saved and displayed as `0.25정` |
| V3-MED-TC-07 | Dose | Save 5 mg | Saved and displayed as `5mg` |
| V3-MED-TC-08 | Dose | Save 2.5 ml | Saved and displayed as `2.5ml` |
| V3-MED-TC-09 | Scheduled | Save without time slot | Rejected |
| V3-MED-TC-10 | Scheduled | Existing toggle behavior | Still works |
| V3-MED-TC-11 | PRN | Save without time slot | Allowed |
| V3-MED-TC-12 | PRN | No dose taken today | No `미복용` state generated |
| V3-MED-TC-13 | PRN | Record one actual dose | One PRN log stored |
| V3-MED-TC-14 | PRN | Record twice on same date | Two PRN logs stored |
| V3-MED-TC-15 | PRN | Record future date | Rejected |
| V3-MED-TC-16 | PRN | Record future time today | Rejected |
| V3-MED-TC-17 | PRN | Record dose/note | Actual value/unit/note preserved |
| V3-MED-TC-18 | Backup | Create P0-2 backup | Uses backupVersion 2 and includes PRN logs |
| V3-MED-TC-19 | Backup | Restore V2 backupVersion 1 | Accepted; V3 defaults applied |
| V3-MED-TC-20 | Regression | Existing Home scheduled medication | Remains displayed correctly |

## Dose Change History / Scheduled Snapshot

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HIST-TC-01 | History | Register a new medication | No fabricated initial change event |
| V3-HIST-TC-02 | History | Change `0.5mg` to `1mg` | One event with previous/new dose and changed time |
| V3-HIST-TC-03 | History | Change only name/schedule | No dose-change event |
| V3-HIST-TC-04 | History | Existing `10 mg`, save `10mg` | No false history event |
| V3-HIST-TC-05 | History | Remove current dose | Event preserves previous dose and empty new dose |
| V3-HIST-TC-06 | History UI | Open edited medication with history | Previous -> new dose and changed time visible |
| V3-SNAP-TC-01 | Scheduled log | Mark `0.5mg` medication taken | Log snapshot is `0.5mg` |
| V3-SNAP-TC-02 | Scheduled log | Change medication to `1mg` after taken | Existing log remains `0.5mg` |
| V3-SNAP-TC-03 | Scheduled log | Undo taken state | Snapshot cleared |
| V3-SNAP-TC-04 | Scheduled log | Retake after dose changed to `1mg` | Snapshot becomes `1mg` |
| V3-SNAP-TC-05 | Legacy log | Load pre-V5 taken log | Snapshot remains empty/unknown |
| V3-HIST-TC-07 | Backup | Backup history + scheduled snapshot | backupVersion 3 round-trips both |
| V3-HIST-TC-08 | Backup | Restore backupVersion 2 | Accepted with empty history/snapshot |

## Symptom Recording

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-SYM-TC-01 | Severity | Inspect severity values | Exactly `없음`, `약함`, `보통`, `심함` |
| V3-SYM-TC-02 | Service | Save one symptom for a date | Record is stored |
| V3-SYM-TC-03 | Service | Query records for that date | Saved symptom is returned |
| V3-SYM-TC-04 | Service | Save same date and same symptom again | Existing record is updated; no duplicate |
| V3-SYM-TC-05 | Service | Save same symptom on another date | Dates remain separate |
| V3-SYM-TC-06 | Regression | Save health, medication, lab, and symptom data | Existing services keep their own records |
| V3-SYM-TC-07 | UI | Open symptom record from Health tab | Symptom record screen opens without changing bottom navigation |
| V3-SYM-TC-08 | UI | Select severity and save | Severity is persisted |
| V3-SYM-TC-09 | UI | Reopen saved date | Existing severity selection is shown |
| V3-SYM-TC-10 | Scope | Record symptom while PRN exists | No symptom-to-PRN link or interpretation is created |

## PRN Symptom Links

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-PRN-SYM-TC-01 | Service | Save PRN log without symptoms | PRN log is saved and no links are created |
| V3-PRN-SYM-TC-02 | Service | Save PRN log with one symptom | One `prn_symptom_links` row is saved |
| V3-PRN-SYM-TC-03 | Service | Save PRN log with multiple symptoms | Multiple links are saved for the same PRN log |
| V3-PRN-SYM-TC-04 | Service | Pass duplicate symptom IDs | Duplicate PRN-log/symptom links are not created |
| V3-PRN-SYM-TC-05 | Service | Save two PRN logs with different symptoms | Links remain separated by `prnMedicationLogId` |
| V3-PRN-SYM-TC-06 | Scope | Save PRN symptom links | `symptom_records` are not created or changed |
| V3-PRN-SYM-TC-07 | Reload | Reload medication service after saving links | Links are still queryable |
| V3-PRN-SYM-TC-08 | Delete | Delete a linked PRN log | Related links are deleted before/with the PRN log |
| V3-PRN-SYM-TC-09 | Legacy | Load an existing PRN log without links | PRN log is readable and has an empty link list |
| V3-PRN-SYM-TC-10 | UI | Open PRN log form | `관련 증상 (선택)` is shown when active symptoms exist |
| V3-PRN-SYM-TC-11 | UI | Select more than one symptom | Multiple symptom checkboxes can be selected |
| V3-PRN-SYM-TC-12 | UI | Save with no symptom selected | PRN log is saved normally |
| V3-PRN-SYM-TC-13 | UI | View a linked PRN log | Neutral `관련 증상: ...` text is shown |
| V3-PRN-SYM-TC-14 | UI regression | Same PRN medication has an older linked log and a latest unlinked log | Today's summary keeps the latest time, each PRN log is listed separately, the older log keeps `관련 증상: 두통 · 어지러움`, and the latest unlinked log does not inherit those symptoms |

## Symptom Backup / Restore

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-SYM-BK-TC-01 | Backup | Create current backup | Uses backupVersion 4 and includes symptom definitions, symptom records, and PRN symptom links |
| V3-SYM-BK-TC-02 | Restore | Backup, change/delete data, then restore | Original symptom definition is restored |
| V3-SYM-BK-TC-03 | Restore | Restore symptom records | Severity is restored without changing severity values |
| V3-SYM-BK-TC-04 | Restore | Restore PRN symptom links | Link keeps the same PRN log ID and symptom definition ID |
| V3-SYM-BK-TC-05 | Replace | Restore snapshot without stale symptom/link rows | Data not present in the snapshot does not remain after restore |
| V3-SYM-BK-TC-06 | Legacy | Restore backupVersion 1, 2, or 3 without symptom collections | Restore succeeds and symptom collections are treated as empty |
| V3-SYM-BK-TC-07 | Restore refresh | Restore backup after symptom values changed in memory | MedicationService and SymptomService are reloaded before restore success is shown; symptom screen immediately displays restored values without app restart |

## Health Field Visibility

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HEALTH-VIS-TC-01 | Defaults | Open health field visibility settings for the first time | Weight, blood pressure, water, exercise, sleep, and condition are all ON |
| V3-HEALTH-VIS-TC-02 | Save | Hide and show each supported health field | Visibility state is saved through `HealthFieldVisibilityService`; date remains visible |
| V3-HEALTH-VIS-TC-03 | Health list/form | Hide water and sleep | Health record list and add/edit form hide water and sleep while other health UI remains visible |
| V3-HEALTH-VIS-TC-04 | Data preservation | Edit and save a record while water and sleep are hidden | Hidden water and sleep values are preserved and reappear when shown again |
| V3-HEALTH-VIS-TC-05 | Persistence | Restart app with water and sleep hidden | Water and sleep remain hidden after relaunch |
| V3-HEALTH-VIS-TC-06 | Home | Hide weight, blood pressure, water, and sleep | Home today's health card shows only exercise and condition |
| V3-HEALTH-VIS-TC-07 | Statistics | Hide weight and blood pressure | Weight and blood pressure tabs are hidden; lab tab remains visible and functional |
| V3-HEALTH-VIS-TC-08 | Restore visibility | Turn all six fields back ON | Home and health edit screen show all six fields with existing values |
| V3-HEALTH-VIS-TC-09 | DB/Backup scope | Use field visibility settings | No DB migration, no `HealthRecord` model/schema change, no backupVersion change, and no visibility settings in backup |

### P1-1 Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-1 focused tests, `flutter test test/health_field_visibility_test.dart`: 7 PASS, 0 FAIL.
- Full regression, `flutter test`: 150 PASS, 0 FAIL, exit code 0.

### P1-1 Android Manual QA

| ID | Scenario | Result |
|---|---|---|
| QA-1 | First visibility settings check showed weight, blood pressure, water, exercise, sleep, and condition ON | PASS |
| QA-2 | Created 2026.08.27 health record with weight `55.5 kg`, blood pressure `120 / 80 mmHg`, water `1500 mL`, exercise `5000 steps`, sleep `7.5 시간`, condition `보통` | PASS |
| QA-3 | Turned water OFF and sleep OFF; list and edit screen hid both fields while other health UI remained | PASS |
| QA-4 | Edited and saved while water/sleep were hidden; after showing again, water `1500` and sleep `7.5` remained, and weight change `55.5 -> 55.6` saved | PASS |
| QA-5 | Fully closed and relaunched with water OFF and sleep OFF | PASS; water/sleep OFF persisted and edit screen still hid both |
| QA-6 | Hid weight, blood pressure, water, and sleep | PASS; Home today's health showed exercise and condition only |
| QA-7 | Hid weight and blood pressure in Statistics | PASS; lab tab remained visible and functional |
| QA-8 | Turned all six fields back ON | PASS; Home showed `55.6 kg`, `120 / 80 mmHg`, `1500 mL`, `5000`, `7.5 시간`, and `보통`; edit screen showed all six inputs and values |
| QA-9 | Reopened Statistics with all fields ON | PASS; weight and blood pressure tabs restored, lab tab remained, data showed `55.6 kg` and `120 / 80 mmHg` |

## Optional Water Input

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HEALTH-WATER-TC-01 | Save | Leave visible water field blank and save with another health value | Record saves successfully and `waterIntake` is `null` |
| V3-HEALTH-WATER-TC-02 | Save | Enter visible water value `1500` | `waterIntake` is saved as `1500` |
| V3-HEALTH-WATER-TC-03 | Edit | Clear an existing visible water value and save | Existing water value is explicitly removed and `waterIntake` becomes `null` |
| V3-HEALTH-WATER-TC-04 | Validation | Enter water value `0` | Validation fails; `0` is not saved and is not treated as `null` |
| V3-HEALTH-WATER-TC-05 | Visibility | Hide water through P1-1 settings and edit another health value | Existing hidden `waterIntake` value is preserved |
| V3-HEALTH-WATER-TC-06 | State separation | Compare visible blank, visible value, and hidden existing-value states | `null`, positive integer, and preserved hidden value remain distinct |

### P1-2 Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-2 focused tests, `flutter test test/health_water_optional_test.dart`: 6 PASS, 0 FAIL.
- Impacted existing tests, `flutter test test/widget_test.dart test/health_field_visibility_test.dart`: 24 PASS, 0 FAIL.
- Stabilized PRN regression, `flutter test test/prn_symptom_link_test.dart`: 14 PASS, 0 FAIL.
- Full regression, `flutter test`: 156 PASS, 0 FAIL, exit code 0.

### P1-2 Android Manual QA

| ID | Scenario | Result |
|---|---|---|
| QA-1 | Saved a health record with other health values present and visible water left blank | PASS; after reopening, water remained blank |
| QA-2 | Entered water `1500 mL`, saved, and reopened the record | PASS; `1500` remained visible |
| QA-3 | Cleared an existing visible water value `1500`, saved, and reopened the record | PASS; water was blank |
| QA-4 | Entered water `0` and attempted to save | PASS; validation showed `수분은 0보다 큰 값으로 입력해주세요.` and `0` was not saved |
| QA-5 | Saved water `1500`, hid water through P1-1 visibility, edited another health value, then showed water again | PASS; existing `1500` was preserved |

## User Symptom Add/Edit

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-SYM-USER-TC-01 | Add | Add user symptom `목통증` | Active user symptom is saved with `isDefault = false`, trimmed name, generated id, and sort order after existing definitions |
| V3-SYM-USER-TC-02 | Validation | Add blank, whitespace-only, or duplicate active symptom name | Save is rejected and no new definition is stored |
| V3-SYM-USER-TC-03 | Rename | Rename user symptom `목통증` to `목 통증` | Existing definition id and metadata are preserved except name and updatedAt |
| V3-SYM-USER-TC-04 | Default policy | Try to rename a built-in default symptom | Rename is rejected and the default symptom name is unchanged |
| V3-SYM-USER-TC-05 | Record preservation | Rename a user symptom after saving severity | Existing `symptom_records` keep the same `symptomDefinitionId` and severity; UI displays the new name |
| V3-SYM-USER-TC-06 | PRN link preservation | Rename a user symptom linked to an existing PRN log | Existing `prn_symptom_links` keep the same `symptomDefinitionId`; PRN UI displays the new name |
| V3-SYM-USER-TC-07 | Reload | Reload service/storage after add and rename | Added and renamed user symptom definitions remain available |
| V3-SYM-USER-TC-08 | Backup | Backup and restore user-added/renamed definition with record and PRN link | backupVersion 4 round-trips all related rows without backup format changes |

### P1-3 Automated QA

- `flutter analyze`: PASS, No issues found.
- P1-3 focused tests, `flutter test test/symptom_definition_management_test.dart`: 12 PASS, 0 FAIL.
- Impacted existing tests, `flutter test test/symptom_test.dart test/prn_symptom_link_test.dart test/backup_service_test.dart test/data_management_screen_test.dart test/widget_test.dart`: 57 PASS, 0 FAIL.
- Backup regression, `test/backup_service_test.dart`: 19 PASS, including user-added and renamed symptom definition, symptom record, and PRN symptom link backupVersion 4 round-trip.
- Full regression, `flutter test`: 169 PASS, 0 FAIL, exit code 0.

### P1-3 Android Manual QA

| ID | Scenario | Result |
|---|---|---|
| QA-1 | Opened symptom management from the symptom record screen top action | PASS |
| QA-2 | Added user symptom `목통증` | PASS; shown as a user symptom and visually distinct from default symptoms |
| QA-3 | Recorded severity `심함` for `목통증` | PASS; symptom record screen kept the saved severity |
| QA-4 | Opened PRN log form and linked `목통증` | PASS; user symptom appeared in related symptoms and was shown on the PRN record display |
| QA-5 | Renamed `목통증` to `목 통증` | PASS; user symptom rename worked and default symptoms had no edit action |
| QA-6 | Checked symptom record after rename | PASS; existing severity `심함` remained and displayed as `목 통증` |
| QA-7 | Checked PRN link after rename | PASS; existing PRN link remained and displayed as `목 통증` |
| QA-8 | Tried blank and duplicate names | PASS; both saves were blocked |
| QA-9 | Fully closed and relaunched the app | PASS; user symptom, renamed name, symptom record, and PRN link persisted |

P1-3 did not change backup/restore production code. Android backup/restore was not repeated for P1-3; backupVersion 4 round-trip was covered by automated regression.

## Regression

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-P0-REG-TC-01 | P0 regression | Run automated regression covering P0-1 through P0-6 | `flutter analyze` passes, full `flutter test` passes, and P0-1 through P0-6 automated coverage is confirmed |
| V3-P0-REG-TC-02 | Android regression evidence | Review completed Android manual QA for P0-4, P0-5, and P0-6 plus latest emulator run | Previously verified Android behavior remains accepted for P0 final regression; P0-7 is PASS |
| V3-FINAL-REG-TC-01 | V3 final automated regression | Run grouped V3 regression for Health/Future/Visibility/Water/Statistics/Widget | 68 PASS, 0 FAIL |
| V3-FINAL-REG-TC-02 | V3 final automated regression | Run grouped V3 regression for Medication/Dose/PRN/Symptom/P1-3 | 69 PASS, 0 FAIL |
| V3-FINAL-REG-TC-03 | V3 final automated regression | Run grouped V3 regression for Backup/Restore/Data management/Lab | 32 PASS, 0 FAIL |
| V3-FINAL-REG-TC-04 | V3 final automated regression | Run full `flutter test` after grouped regression | 169 PASS, 0 FAIL, exit code 0 |
| V3-FINAL-REG-TC-05 | V3 final Android regression | Run Android V3 full regression after P0/P1 completion | PASS |
| V3-REL-TC-01 | Release APK | Build release APK from verified V3 branch | `flutter build apk --release` passes and creates a non-empty APK |
| V3-REL-TC-02 | Release APK copy | Copy release APK outside the repository | External APK copy has the same size and SHA-256 as the original |

### V3 Final Automated Regression

- `flutter analyze`: PASS, No issues found.
- Health/Future/Visibility/Water/Statistics/Widget grouped regression: 68 PASS, 0 FAIL, exit code 0.
- Medication/Dose/PRN/Symptom/P1-3 grouped regression: 69 PASS, 0 FAIL, exit code 0.
- Backup/Restore/Data management/Lab grouped regression: 32 PASS, 0 FAIL, exit code 0.
- Full regression, `flutter test`: 169 PASS, 0 FAIL, exit code 0.
- Android V3 full regression: PASS.
- Release APK build: PASS.
- Release APK SHA-256: `0A4E1DE8399776889727921663B047D828370131735D49E620F0CEBBB7FB744D`.

For each feature commit:

1. Run feature-specific automated tests.
2. Run the complete `flutter test` suite.
3. Run `flutter analyze`.
4. Run relevant Android manual checks.
5. Verify Git working tree before commit.
