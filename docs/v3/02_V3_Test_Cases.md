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

## V3.0.1 HOT FIX

### Lab Result CRUD UX

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HF-LAB-TC-01 | Lab detail | Open a lab-date detail screen | Each result row shows an explicit edit action |
| V3-HF-LAB-TC-02 | Lab detail | Open a lab-date detail screen | Each result row shows an explicit delete action |
| V3-HF-LAB-TC-03 | Lab edit | Enter edit from a result row/action | Existing lab name, value, unit, and date are preserved |
| V3-HF-LAB-TC-04 | Lab edit | Change a result saved for today to a past date | Save succeeds |
| V3-HF-LAB-TC-05 | Lab list | Save a date change | Result appears under the new date group |
| V3-HF-LAB-TC-06 | Lab delete | Cancel delete confirmation | Original result remains |
| V3-HF-LAB-TC-07 | Lab delete | Confirm delete | Target result is removed |
| V3-HF-LAB-TC-08 | Lab delete | Delete the last result in a date group | Empty date group/detail does not remain |
| V3-HF-LAB-TC-09 | Lab add | Save a past-date result from main `+` | App opens the saved date detail |
| V3-HF-LAB-TC-10 | Lab add | Add another result from detail `+ 검사 항목 추가` | The detail date is used as the initial date |
| V3-HF-LAB-TC-11 | Lab grouping | Save multiple results on the same date | Results are grouped together on that date |

### Medication History

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HF-MED-TC-01 | Navigation | Open today's medication screen | `기록` entry point opens medication history |
| V3-HF-MED-TC-02 | History | View past medication history | Records are shown by date |
| V3-HF-MED-TC-03 | Scheduled history | Stored taken scheduled log exists | Taken status is displayed |
| V3-HF-MED-TC-04 | Scheduled history | Compare no log with stored `isTaken == false` log | Missing log is not treated as false; stored false is shown as a saved missed-dose record |
| V3-HF-MED-TC-05 | Scheduled history | Medication has no stored log on a date | No synthetic missed-dose history row is created |
| V3-HF-MED-TC-06 | Scheduled history | Historical dose snapshot exists | Snapshot dose is displayed |
| V3-HF-MED-TC-07 | Scheduled history | Current medication dose changes after a stored taken log | Historical snapshot remains unchanged |
| V3-HF-MED-TC-08 | Legacy scheduled log | Stored scheduled log has no snapshot | Current medication dose is not used as fallback historical dose |
| V3-HF-MED-TC-09 | Inactive medication | Historical log references inactive/soft-deleted medication | Medication name is still resolved from all medication rows |
| V3-HF-MED-TC-10 | PRN history | PRN log exists | Actual taken time is displayed |
| V3-HF-MED-TC-11 | PRN history | PRN log has stored dose value/unit | Actual stored dose is displayed |
| V3-HF-MED-TC-12 | PRN symptoms | PRN log has related symptom links | Related symptoms are displayed neutrally |
| V3-HF-MED-TC-13 | PRN history | PRN log has no related symptom links | Log still displays normally |
| V3-HF-MED-TC-14 | PRN history | Multiple PRN logs exist on the same date | Each PRN log is shown separately |
| V3-HF-MED-TC-15 | Regression | Open medication history and return to today | Today's medication screen state is unchanged |

### Home Today's Medication Display

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HF-HOME-MED-TC-01 | Home | More than three scheduled medication items exist today | All scheduled medication items are displayed |
| V3-HF-HOME-MED-TC-02 | Home grouping | Scheduled medications exist across morning, lunch, evening, and bedtime | Groups are shown in morning -> lunch -> evening -> bedtime order |
| V3-HF-HOME-MED-TC-03 | Home grouping | A time slot has no scheduled medication | The empty time-slot group is hidden |
| V3-HF-HOME-MED-TC-04 | Home rows | View grouped scheduled medication rows | Row keeps medication name, dose, taken/not-taken state, and status icon without repeating the time-slot label |
| V3-HF-HOME-MED-TC-05 | Home dose | Completed scheduled dose has a snapshot | Historical dose snapshot is displayed |
| V3-HF-HOME-MED-TC-06 | Home dose | Untaken scheduled dose exists | Current medication dose is displayed |
| V3-HF-HOME-MED-TC-07 | Home scroll | Many scheduled medication items exist | Existing Home scroll allows access through the final medication |
| V3-HF-HOME-MED-TC-08 | Home action | Many scheduled medication groups are displayed | Medication confirmation button remains reachable after all groups |
| V3-HF-HOME-MED-TC-09 | PRN scope | PRN medication exists | PRN medication is not newly displayed on Home |
| V3-HF-HOME-MED-TC-10 | Compatibility scope | Home scheduled-medication display changes are used | DB/model/service/Backup behavior remains unchanged |

### Statistics Date Display

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-HF-STAT-TC-01 | Statistics list | View weight statistics on a narrow mobile viewport | `MM.dd` date such as `08.28` stays on one line |
| V3-HF-STAT-TC-02 | Shared row regression | Use weight, blood pressure, and lab value lists | Shared value-row date display applies to all three lists |
| V3-HF-STAT-TC-03 | Scope | View statistics chart | Chart and x-axis date rendering are unchanged |

### V3.0.1 Automated QA

- `flutter analyze`: PASS, No issues found.
- Home/widget focused tests, `flutter test test/widget_test.dart`: 19 PASS, 0 FAIL.
- Medication snapshot display focused tests, `flutter test test/medication_snapshot_display_test.dart`: 3 PASS, 0 FAIL.
- Lab focused tests, `flutter test test/lab_result_test.dart`: 18 PASS, 0 FAIL.
- Medication History focused tests, `flutter test test/medication_history_test.dart`: 7 PASS, 0 FAIL.
- Statistics focused tests, `flutter test test/statistics_test.dart`: 27 PASS, 0 FAIL.
- Medication/PRN/Snapshot/Backup regression bundle: 71 PASS, 0 FAIL.
- Full regression, `flutter test`: 185 PASS, 0 FAIL.
- During test stabilization, the Lab DatePicker widget helper initially selected a day without pressing OK/confirmation. This was a test automation issue, not a production app functional bug. After the helper fix, lab focused tests passed 18/18.

### V3.0.1 Android Device QA

- Device: SM-S918N, Android 16, device ID R3CW201RKMP.
- Result: 20 PASS, 0 FAIL, 8 BLOCKED.
- Confirmed app functional failure count: 0.
- QA used a pre-run DB snapshot and restored the DB after testing.
- QA301 test data residual check: PASS, no QA301 data remained after restore.

| ID | Scenario | Result |
|---|---|---|
| QA-LAUNCH-01 | Launch / force-stop / relaunch for 3 cycles | PASS |
| QA-LAB-01 | Lab screen and detail display | PASS |
| QA-LAB-02 | Explicit edit/delete actions in lab detail | PASS |
| QA-LAB-03 | Main `+` saves past-date lab result and opens saved-date detail | PASS |
| QA-LAB-04 | Detail `+ 검사 항목 추가` keeps the same date and supports consecutive same-date entry | PASS |
| QA-LAB-05 | Lab edit form preserves existing values | PASS |
| QA-LAB-06 | Lab date change recalculates groups | PASS |
| QA-LAB-07 | Duplicate validation on device | BLOCKED - automation/data-safety limitation |
| QA-LAB-08 | Delete cancel keeps lab result | PASS |
| QA-LAB-09 | Delete confirm removes lab result | PASS |
| QA-LAB-10 | Last QA lab group is removed; no empty group remains | PASS |
| QA-MED-01 | Today's medication screen shows `기록` and `관리` | PASS |
| QA-MED-02 | Medication history is read-only | PASS |
| QA-MED-03 | No-log empty-date device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-04 | Existing scheduled history displays stored status and dose text | PASS |
| QA-MED-05 | Scheduled dose-change snapshot device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-06 | Existing stored `isTaken == false` displays as a saved missed-dose record | PASS |
| QA-MED-07 | Inactive medication history device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-08 | PRN actual log device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-09 | PRN symptom link device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-10 | PRN no-symptom device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-11 | Multiple PRN logs device setup | BLOCKED - automation/data-safety limitation |
| QA-MED-12 | Medication history lookup does not alter today's medication state | PASS |
| QA-PERSIST-01 | Persistence/relaunch after QA data operations | PASS |
| QA-LOGCAT-01 | App logcat fatal/ANR check | PASS |
| QA-RESTORE-01 | Pre-QA DB snapshot and post-QA DB restore | PASS |

### V3.0.1 Additional Android Statistics Check

This check is recorded separately from the strengthened device QA count above. The strengthened device QA result remains 20 PASS, 0 FAIL, 8 BLOCKED.

- Device: SM-S918N, Android 16.

| ID | Scenario | Result |
|---|---|---|
| QA-STAT-DATE-01 | Weight statistics list date displays on one line | PASS |
| QA-STAT-DATE-02 | Blood pressure statistics list date displays on one line | PASS |
| QA-STAT-DATE-03 | Lab statistics list date displays on one line | PASS |

### V3.0.1 Additional Android Home Medication Check

This check is recorded separately from the strengthened device QA count above. The strengthened device QA result remains 20 PASS, 0 FAIL, 8 BLOCKED.

- Device: SM-S918N, Android 16.

| ID | Scenario | Result |
|---|---|---|
| QA-HOME-MED-01 | More than three scheduled medication items are displayed on Home | PASS |
| QA-HOME-MED-02 | Morning, lunch, evening, and bedtime groups display correctly | PASS |
| QA-HOME-MED-03 | Empty time-slot groups are hidden | PASS |
| QA-HOME-MED-04 | Home scroll reaches the final medication | PASS |
| QA-HOME-MED-05 | Medication confirmation button remains reachable | PASS |

## V3.1.0 Exercise Records

### Exercise Service / Model

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-EX-TC-01 | Model | Map round-trip an `ExerciseRecord` | All fields are preserved |
| V3-EX-TC-02 | Save | Save walking, 30 minutes, moderate intensity | Record saves with exercise type, duration, intensity, MET snapshot, and expected calorie policy |
| V3-EX-TC-03 | Multiple per day | Save walking and cycling on the same date | Both records exist; date is not unique |
| V3-EX-TC-04 | Date query | Query records for one date | Only records for that date are returned |
| V3-EX-TC-05 | Sorting | Load all exercise records | Records are ordered by date descending |
| V3-EX-TC-06 | Future date | Save an exercise dated tomorrow | Save is rejected and no record is inserted |
| V3-EX-TC-07 | Duration zero | Save `0` minutes | Save is rejected |
| V3-EX-TC-08 | Duration negative | Save a negative duration | Save is rejected |
| V3-EX-TC-09 | Weight snapshot | Save exercise on a date with `HealthRecord.weight` | `weightSnapshot` stores that date's weight |
| V3-EX-TC-10 | No weight | Save exercise on a date without health weight | Record saves with `weightSnapshot == null` and `estimatedCalories == null` |
| V3-EX-TC-11 | MET snapshot | Save by exercise type and intensity | `metSnapshot` matches the app MET constant |
| V3-EX-TC-12 | Estimated calories | Save exercise with weight and duration | `estimatedCalories` equals `metSnapshot * weightSnapshot * durationMinutes / 60` |
| V3-EX-TC-13 | Same-date edit | Change duration or intensity without changing date | Existing `weightSnapshot` is preserved and calories are recalculated |
| V3-EX-TC-14 | Date-change edit | Change exercise date to another date with different weight | New date's `weightSnapshot` is applied and calories are recalculated |
| V3-EX-TC-15 | Edit | Update an existing exercise | Updated values persist |
| V3-EX-TC-16 | Delete | Delete an existing exercise | Exercise record is removed |
| V3-EX-TC-17 | Persistence | Reload from SQLite storage | Saved exercise records and snapshots remain available |

### Exercise UI / Navigation

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-EX-UI-TC-01 | ExerciseScreen | Open exercise history | Past records render by date descending |
| V3-EX-UI-TC-02 | ExerciseScreen | Same date has multiple records | Multiple records for that date render |
| V3-EX-UI-TC-03 | ExerciseScreen | Record has calculated calories | UI uses `예상 소모 칼로리` text |
| V3-EX-UI-TC-04 | ExerciseScreen | Record has no weight snapshot | UI displays expected calorie calculation unavailable |
| V3-EX-UI-TC-05 | Health navigation | Tap Health screen exercise-record action | Exercise screen opens |
| V3-EX-UI-TC-06 | Home | Render Home with `ExerciseService` connected | Home renders without crash and without treating legacy steps as new exercise |

### Exercise Backup / Compatibility

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V3-EX-BACKUP-TC-01 | Backup V5 | Create backup with exercise records | backupVersion 5 includes `exerciseRecords` |
| V3-EX-BACKUP-TC-02 | Backup V5 | Restore V5 backup in automated regression | Exercise records round-trip |
| V3-EX-BACKUP-TC-03 | Backup V4 | Restore backupVersion 4 without `exerciseRecords` | Restore succeeds with empty exercise records |
| V3-EX-BACKUP-TC-04 | Legacy steps | Backup/restore health records with steps | Legacy `healthRecords.steps` is preserved |
| V3-EX-BACKUP-TC-05 | Migration scope | Existing steps data exists | Steps are not converted into `ExerciseRecord` |

### V3.1.0 Automated QA

- Focused tests: 73 PASS, 0 FAIL.
- Full regression initial run: 199 PASS, 1 FAIL. The failure was a stale V3.0.1 compatibility-test expectation for `databaseVersion 7` and `backupVersion 4`, not an app functional defect.
- After updating the V3.1 expected versions to `databaseVersion 8` and `backupVersion 5`, final full regression passed: 200 PASS, 0 FAIL.
- `flutter analyze`: PASS, No issues found.
- `git diff --check`: PASS. Only LF -> CRLF warnings were reported.

### V3.1.0 Release APK Build

- Command: `flutter build apk --release`.
- Result: PASS.
- APK: `build\app\outputs\flutter-apk\app-release.apk`.
- APK size: 54,214,009 bytes, about 51.7 MB.
- SHA-256: `95704F75F9FF9F90767B3F5B1F82E877ACE1829E3D8F653361CAE3FFB15768CF`.

### V3.1.0 Android Device QA

- Device: Samsung SM-S918N, Android 16, SDK 36.
- Exercise DB / Service checks passed: multiple exercises per day, weight snapshot, MET snapshot, estimated calories, no-weight date save, future-date rejection, and zero/negative duration rejection.
- Exercise edit checks passed: same-date edit preserved snapshot, date change created a new weight snapshot, and calories recalculated.
- SQLite persistence passed after creating a new service/storage instance and reloading.
- ExerciseScreen, Health -> Exercise navigation, and Home smoke passed.
- Backup V5 serialization passed: backupVersion 5, `exerciseRecords` included, JSON round-trip preserved ExerciseRecord snapshot fields.
- QA data cleanup passed.
- `adb install -r` passed.
- Release launch stability passed 3/3.
- Final logcat showed no fatal app crash.
- Confirmed app functional failures: 0.
- Real-device full DB Restore round-trip was not run to protect existing user data. Backup/Restore round-trip is covered by automated regression; real-device QA covered Backup V5 serialization only.

## V3.2.0 Lab Result Entry / Lab Test Settings

### Lab Test Settings / Batch Entry

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V320-LAB-TC-01 | Settings | Open lab-test settings | Management-type controls and lab-test definitions are shown |
| V320-LAB-TC-02 | Settings | Select one of the seven management types | Selected type is stored and its preset can be applied |
| V320-LAB-TC-03 | Settings | Enable/disable predefined tests | Enabled list updates and persists |
| V320-LAB-TC-04 | Custom test | Add a valid custom lab-test name and optional unit | Custom definition is stored and enabled |
| V320-LAB-TC-05 | Custom validation | Add blank custom name | Rejected |
| V320-LAB-TC-06 | Custom validation | Add duplicate predefined/custom name with case/space variation | Rejected |
| V320-LAB-TC-07 | Custom unit | Add custom test with blank unit | Stored with `defaultUnit == null` |
| V320-LAB-TC-08 | Batch entry | Open new lab-result registration | Multi-entry screen opens for one selected date |
| V320-LAB-TC-09 | Batch entry | View enabled lab rows | Enabled test names and configured default units are shown |
| V320-LAB-TC-10 | Batch entry | Existing same-date results exist | Existing values are prefilled by `testName` |
| V320-LAB-TC-11 | Batch save | Enter values for multiple enabled tests | Non-empty rows are saved in one action |
| V320-LAB-TC-12 | Batch update | Save an existing same-date/test-name value | Existing row is updated; `id`/`createdAt` remain and `updatedAt` changes |
| V320-LAB-TC-13 | Batch blank | Leave a new row empty | No new `LabResult` row is created |
| V320-LAB-TC-14 | Existing row clear | Clear a prefilled value in batch UI | Existing DB row is not automatically deleted |
| V320-LAB-TC-15 | Disabled historical test | Disable a test that already has results | Existing result remains visible in list/detail/Statistics |
| V320-LAB-TC-16 | Compatibility | Use V3.2 settings/batch flow | databaseVersion 8, backupVersion 5, LabResult schema unchanged |

### V3.2.0 Confirmed QA

- Full `flutter test`: PASS, 243 tests.
- `flutter analyze`: PASS.
- `git diff --check`: PASS.
- Android SM-S918N update-install / existing-data smoke: PASS.
- Batch lab-entry screen, default units, settings screen, management type, predefined checkboxes, custom-test dialog, scroll/full-save access: PASS.
- Custom-test dialog smoke was cancelled; no dummy custom test was saved during device QA.
- Launch stability: PASS, 3/3; filtered logcat showed no app `FATAL EXCEPTION`.
- Confirmed defects: none.
- BLOCKED: 0.

## V3.3.0 Yearly Lab Statistics

### Yearly Statistics

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V330-STAT-TC-01 | Year selector | Open Lab Statistics | Current year is selected by default |
| V330-STAT-TC-02 | Year selector | Stored results contain one or more years | Available stored years are represented by the selector |
| V330-STAT-TC-03 | Filtering | Select lab test + year | Only matching test/year results are displayed |
| V330-STAT-TC-04 | Full-year results | Selected year has many results | All matching original results are shown; no recent-N truncation |
| V330-STAT-TC-05 | Sampling policy | Selected year has repeated monthly results | Results are not replaced by monthly averages/sampling |
| V330-STAT-TC-06 | Chart order | View chart | Oldest -> newest |
| V330-STAT-TC-07 | List order | View value list | Newest -> oldest |
| V330-STAT-TC-08 | Dense data | Many results exist in year | Chart remains reachable through horizontal scrolling |
| V330-STAT-TC-09 | Disabled test | Historical rows exist for disabled test | Test remains available in Statistics |
| V330-STAT-TC-10 | Exact-name scope | Differently named aliases exist | V3.3 keeps exact-name grouping; alias normalization is not fabricated |

### V3.3.0 Confirmed QA

- Statistics focused tests: PASS, 30/30.
- Related regression bundle: PASS, 115/115.
- Full `flutter test`: PASS, 246/246.
- `flutter analyze`: PASS.
- `git diff --check`: PASS.
- Android SM-S918N User 0 update-install and existing-data preservation: PASS.
- 2026 Creatinine: 02/03, 05/12, 08/11 all visible.
- 2026 BUN: 02/03, 05/12, 08/11 all visible.
- 2026 Tacrolimus: stored 2026 values including latest August result visible.
- Year selector / chart / list / scrolling / portrait overflow smoke: PASS.
- Launch stability: PASS, 3/3; no app `FATAL EXCEPTION`.
- Confirmed defects: none.
- BLOCKED: 0.

## V3.4.0 Lab Input Visibility / Statistics Aliases

### Numeric Input Visibility / Alias Handling

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V340-LAB-TC-01 | Numeric field | Enter `22.3` | Full string remains visible before save |
| V340-LAB-TC-02 | Numeric field | Enter `1.31` | Full string remains visible before save |
| V340-LAB-TC-03 | Numeric field | Enter `6.79` | Full string remains visible before save |
| V340-LAB-TC-04 | Numeric field | Enter `10.4` | Full string remains visible before save |
| V340-LAB-TC-05 | Numeric field | Enter `292` | Full string remains visible before save |
| V340-LAB-TC-06 | Save regression | Save decimal result such as `22.3` | Stored numeric value remains correct |
| V340-ALIAS-TC-01 | HDL alias | Only `HDL Cholesterol` exists | Canonical HDL statistics display normally |
| V340-ALIAS-TC-02 | HDL alias | Only `HDL-Cholesterol` exists | Included in canonical `HDL Cholesterol` statistics |
| V340-ALIAS-TC-03 | HDL alias | Both names exist on different dates | One canonical series includes both |
| V340-ALIAS-TC-04 | P alias | Only `P(인)` exists | Canonical P statistics display normally |
| V340-ALIAS-TC-05 | P alias | Only `Inorganic P(인)` exists | Included in canonical `P(인)` statistics |
| V340-ALIAS-TC-06 | P alias | Both names exist on different dates | One canonical series includes both |
| V340-ALIAS-TC-07 | Same-date duplicate | Canonical and alias rows exist on same date | Both stored rows remain visible; no merge/overwrite/delete |
| V340-ALIAS-TC-08 | Custom test scope | Similar custom test name exists | No fuzzy alias normalization is applied |
| V340-ALIAS-TC-09 | Regression | Creatinine/BUN/Tacrolimus 2026 data exists | Existing yearly statistics remain intact |

### V3.4.0 Confirmed QA

- Focused lab-safety tests: PASS, 16/16.
- Related regression bundle: PASS, 124/124.
- Full `flutter test`: PASS, 262/262.
- `flutter analyze`: initial unused-import test issue fixed; final PASS.
- `git diff --check`: PASS.
- Release APK build: PASS.
- Final Android SM-S918N User 0 update-install: PASS; User 95 package absent.
- Numeric input UI smoke with `1.31`, `22.3`, `6.79`, `10.4`, `292`: PASS.
- `HDL Cholesterol` 2026 included alias row stored as `HDL-Cholesterol`: PASS.
- `P(인)` 2026 included alias row stored as `Inorganic P(인)`: PASS.
- Creatinine/BUN/Tacrolimus latest-August regression: PASS.
- Launch stability: PASS, 3/3; no app `FATAL EXCEPTION`.
- Final confirmed defects: none.
- Final BLOCKED: 0.

## V3.5.0 Medication History / PRN UX

### Home PRN / History Correction

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V350-PRN-TC-01 | Home PRN | PRN medication exists but no log today | No missed-dose/recommendation summary is fabricated |
| V350-PRN-TC-02 | Home PRN | One actual PRN log exists today | Home shows stored PRN summary with count/time |
| V350-PRN-TC-03 | PRN action | No PRN log exists today | Action label is `복용` |
| V350-PRN-TC-04 | PRN action | One or more PRN logs exist today | Action label is `추가 복용` |
| V350-PRN-TC-05 | Multiple PRN | Record another same-day PRN dose | New log is inserted; prior log is not overwritten |
| V350-MED-HIST-TC-01 | Scheduled history | Add a missing scheduled log for a past date | Selected historical date/time are preserved |
| V350-MED-HIST-TC-02 | Scheduled edit | Edit an existing scheduled log | Existing `id`/`createdAt` preserved; `updatedAt` refreshed |
| V350-MED-HIST-TC-03 | Historical dose | Safe past dose cannot be determined | Current dose is not fabricated as historical snapshot |
| V350-PRN-HIST-TC-01 | PRN history | Add a missing PRN log for a selected date | New PRN history row is stored |
| V350-PRN-HIST-TC-02 | PRN edit | Edit date/time/dose/unit/note/symptoms | Existing row is updated while identity/history fields are preserved |
| V350-PRN-HIST-TC-03 | Symptom links | Edit one PRN log's related symptoms | Only that PRN log's links are replaced |
| V350-PRN-HIST-TC-04 | Interpretation scope | PRN symptom link exists | Display remains neutral; no cause/effect/medical advice is inferred |

### V3.5.0 Confirmed QA

- Focused V3.5 medication PRN/history tests: PASS, 15/15.
- Related regression bundle: PASS, 110/110.
- Full `flutter test`: PASS, 277/277.
- `flutter analyze`: PASS.
- `git diff --check`: PASS.
- Release APK build: PASS.
- Android SM-S918N User 0 update-install: PASS; User 95 package absent.
- Existing health/lab/medication/symptom data preservation smoke: PASS.
- Home actual-today PRN count/time display: PASS.
- Medication-history missing-log action and scheduled/PRN edit-form smoke: PASS; no destructive save was required for smoke.
- Launch stability: PASS, 3/3; no app `FATAL EXCEPTION`.
- Confirmed defects: none.
- BLOCKED: 0.

## V3.5.1 Health Record List Hot Fix

### Water / Sleep List Display

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V351-HEALTH-TC-01 | Water | Stored water value exists | Health list shows value with `mL` |
| V351-HEALTH-TC-02 | Water null | Water is null | List shows `기록 없음` |
| V351-HEALTH-TC-03 | Water format | Water is `1500` | List shows `1,500 mL` |
| V351-HEALTH-TC-04 | Sleep | Stored sleep value exists | Health list shows value with `시간` |
| V351-HEALTH-TC-05 | Sleep null | Sleep is null | List shows `기록 없음` |
| V351-HEALTH-TC-06 | Order | Record has all summary values | Order is weight -> blood pressure -> water -> sleep -> condition |
| V351-HEALTH-TC-07 | Visibility | Water setting OFF/ON | Only water line hides/restores |
| V351-HEALTH-TC-08 | Visibility | Sleep setting OFF/ON | Only sleep line hides/restores |
| V351-HEALTH-TC-09 | Regression | Tap health record | Existing edit navigation still works |

### V3.5.1 Confirmed QA

- Focused health display/visibility tests: PASS, 17/17.
- Related regression bundle: PASS, 48/48.
- Full `flutter test`: PASS, 281/281.
- `flutter analyze`: PASS.
- `git diff --check`: PASS.
- Release APK build: PASS.
- Android SM-S918N User 0 update-install: PASS; User 95 package absent.
- Water/sleep values, null state, units, visibility OFF/ON, other-field regression and record edit navigation: PASS.
- Existing data preservation: PASS.
- Launch stability: PASS, 3/3; no app `FATAL EXCEPTION`.
- Confirmed defects after hot fix: none.
- BLOCKED: 0.

## V3.6.0 Lab Settings Backup / Restore

### Backup / Restore / Validation

| ID | Area | Scenario | Expected |
|---|---|---|---|
| V360-BACKUP-TC-01 | Backup version | Create current backup | `backupVersion == 6` |
| V360-BACKUP-TC-02 | Payload | Create v6 backup | `data.labTestSettings` exists |
| V360-BACKUP-TC-03 | Settings round-trip | Backup management type | `managementType` is preserved |
| V360-BACKUP-TC-04 | Settings round-trip | Backup enabled test IDs | Enabled IDs are preserved in order/valid set |
| V360-BACKUP-TC-05 | Custom definition | Backup custom test with unit | id/name/unit round-trip |
| V360-BACKUP-TC-06 | Custom null unit | Backup custom test without unit | `defaultUnit == null` round-trip |
| V360-BACKUP-TC-07 | Predefined scope | Create backup | Predefined definitions are not duplicated as custom definitions |
| V360-BACKUP-TC-08 | Legacy compatibility | Restore v1-v5 backup without lab settings | Restore is accepted |
| V360-BACKUP-TC-09 | V6 validation | v6 backup omits `labTestSettings` | Rejected |
| V360-BACKUP-TC-10 | V6 validation | Invalid management type | Rejected |
| V360-BACKUP-TC-11 | V6 validation | Invalid/duplicate enabled ID relationship | Rejected |
| V360-BACKUP-TC-12 | V6 validation | Invalid custom definition relationship | Rejected |
| V360-RESTORE-TC-01 | Restore | Restore valid v6 lab settings | Applied through `LabTestSettingsService` |
| V360-RESTORE-TC-02 | Persistence | Restore valid v6 settings | SharedPreferences persists restored state |
| V360-RESTORE-TC-03 | Runtime refresh | Restore completes | Running settings service reloads without required app restart |
| V360-RESTORE-TC-04 | Rollback | Restore fails after replacement begins | Previous DB snapshot is restored |
| V360-RESTORE-TC-05 | Rollback | Previous lab settings existed and restore fails | Previous lab settings are reapplied |
| V360-COMPAT-TC-01 | DB scope | Use V3.6 backup | databaseVersion remains 8; no DB migration |

### V3.6.0 Confirmed QA

- Related backup/data-management/settings/medication-history regression: PASS, 65/65.
- Full `flutter test`: PASS, 285/285.
- `flutter analyze`: PASS, No issues found.
- `git diff --check`: PASS; line-ending warnings only.
- Legacy backup v1, v2, v3, v4, v5 restore compatibility: PASS.
- V6 lab settings payload / restore / reload / rollback / validation coverage: PASS.
- `databaseVersion`: 8 unchanged.
- `backupVersion`: 6.
- V3.6.0 Release APK build: PASS; `build/app/outputs/flutter-apk/app-release.apk`, 54,607,645 bytes, SHA-256 `FB22E909A47627EBDA31D5BAC2931F6A04A637A9D3C103543FA022428499562A`.
- External APK copy: PASS; `C:\Users\jeongeun\Documents\Codex\MyHealthLog_V3.6.0.apk`, same size and SHA-256.
- Android device QA: PASS; Samsung SM-S918N, Android 16, SDK 36.
- Android install scope: PASS; `adb install --user 0 -r`, versionName 3.6.0, versionCode 12, User 95 package absent.
- Device smoke: PASS; launch 3/3, Home, Health, Medication, Lab, and Statistics accessible, existing data presence preserved.
- Real-device Backup v6 lab-settings QA: PASS; `labTestSettings` payload present, settings change/restore/persistence confirmed, no fatal app crash or ANR found in app PID logcat.

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
