# My Health Log V3 Requirements

## Goal

V3 improves medication management and symptom logging based on real usage while preserving the V2 baseline and existing user data.

V3.0.1 is a HOT FIX after the V3.0.0 release. It addresses immediate real-use friction in lab-result CRUD, medication-history lookup, Home today's scheduled-medication display, and statistics list date display without changing the database schema, backup payload, or V3.0.0 data compatibility.

V3.1.0 adds exercise-record improvements by separating exercise from legacy `HealthRecord.steps` while preserving existing V3 data compatibility.

## Fixed Principles

- V2 remains the baseline and is not rebuilt from scratch.
- Existing user-entered data is preserved whenever possible.
- The app records health information but does not diagnose, classify risk, or recommend medication changes.
- Existing V2 behavior is changed only when a V3 requirement requires it.
- Each feature follows Requirement -> Implementation -> Test Case -> Automated Test -> Manual Check -> Bug Fix -> Regression.

## Priority

### P0

- Block future dates for actual health/lab records.
- Improve scheduled medication handling.
- Add PRN medication support.
- Support decimal medication doses and units (`정`, `mg`, `ml`).
- Preserve medication dose-change history.
- Preserve the dose meaning of historical scheduled medication logs.
- Add symptom recording.
- Include symptom data in backup/restore.
- Add automated tests for V3 changes.
- Run full V2 regression.

### P1

- Show/hide health-record fields.
- Make water intake optional in the visible UI without deleting existing data.
- Allow basic user symptom add/edit.

### P2 / V4 Candidates

- Advanced symptom statistics.
- Expanded PRN statistics.
- Detailed symptom/medication analysis.
- Complex user-defined health fields.

## V3-DATE: Future Date Policy

Applies to HealthRecord and LabResult.

- DATE-01: Past date is allowed.
- DATE-02: Today is allowed.
- DATE-03: Future date is rejected.
- DATE-04: DatePicker must not allow dates after today.
- DATE-05: Editing an existing record/result must not allow changing its date to the future.
- DATE-06: Service-layer validation must reject future dates even if UI validation is bypassed.
- DATE-07: Pre-existing invalid future data must not be deleted automatically.
- DATE-08: Pre-existing future data must not appear in normal UI-facing lists used by Home/Statistics.

## V3-MED-P02: Scheduled Medication / PRN / Structured Dose

- MED-01: A medication has a type: `scheduled` or `prn`.
- MED-02: Existing V2 medications without a type are treated as `scheduled`.
- MED-03: Scheduled medications keep the existing morning/lunch/evening/bedtime model.
- MED-04: Scheduled medications require at least one time slot.
- MED-05: PRN medications do not require a time slot.
- MED-06: PRN medications are not shown as daily missed doses.
- MED-07: PRN medication is logged only when the user actually takes it.
- MED-08: Multiple PRN doses on the same date are allowed.
- MED-09: PRN log stores actual date/time, optional dose, unit, and note.
- MED-10: Future PRN date/time cannot be recorded.
- DOSE-01: Dose value supports decimals such as 0.25, 0.5, 0.75, and 1.5.
- DOSE-02: Dose unit supports `정`, `mg`, and `ml`.
- DOSE-03: Dose value and unit are stored separately for V3.
- DOSE-04: The legacy `dose` string remains available for V1/V2 data compatibility.
- DOSE-05: Parseable legacy values such as `0.5정`, `10 mg`, and `2.5ml` are mapped to the structured V3 dose in memory.
- DOSE-06: Unparseable legacy free-form dose text is preserved, not discarded.
- BACKUP-01: V3 P0-2 backup includes structured medication fields and PRN logs.
- BACKUP-02: P0-2 uses backup version 2.
- BACKUP-03: P0-2 can still validate and restore backup version 1.

## V3-MED-P03: Dose Change History / Scheduled Dose Snapshot

- HIST-01: A newly registered medication does not fabricate a dose-change event.
- HIST-02: Editing a medication creates a dose-change event only when the dose meaning changes.
- HIST-03: A dose-change event stores the previous dose, new dose, and changed time.
- HIST-04: Non-dose edits such as name or schedule changes do not create a dose-change event.
- HIST-05: Semantically equal structured doses do not create false history even if legacy spacing differs (`10 mg` vs `10mg`).
- HIST-06: Removing a previously recorded dose creates a dose-change event.
- HIST-07: Dose-change history is visible on the medication edit screen.
- SNAP-01: When a scheduled medication is marked taken, the log snapshots the medication dose at that time.
- SNAP-02: Later medication dose edits do not mutate an already-taken scheduled log snapshot.
- SNAP-03: Marking a scheduled dose as not taken clears its dose snapshot.
- SNAP-04: Re-taking after a dose change snapshots the current dose.
- SNAP-05: Pre-V5 medication logs without a snapshot remain unknown; current dose is not copied backward into history.
- PRN-SNAP-01: PRN dose handling remains unchanged because PRN logs already store actual dose value/unit per event.
- DB-05: Database version increases from 4 to 5 for dose history and scheduled-log snapshots.
- BACKUP-04: P0-3 backup version is 3 and includes medication dose history plus scheduled-log dose snapshots.
- BACKUP-05: Backup versions 1 and 2 remain accepted.
- BACKUP-06: An older backup without history/snapshot restores with those fields empty instead of fabricating values.

## V3-SYM-P04: Symptom Recording

- SYM-01: A user can record symptoms by date.
- SYM-02: Symptom severity has exactly four levels: `없음`, `약함`, `보통`, and `심함`.
- SYM-03: The app stores symptom definitions separately from date-specific symptom records.
- SYM-04: The same symptom on the same date must not create duplicate records; saving again updates the existing record.
- SYM-05: A saved symptom record can be looked up again by date.
- SYM-06: Existing health, medication, lab, and statistics behavior must not be changed by symptom recording.
- SYM-07: The app records symptoms only. It must not diagnose, classify risk, infer causality, or recommend medication changes.
- SYM-08: Symptom and PRN medication relationships are not stored or interpreted in P0-4.
- SYM-09: The symptom record table remains independent so P0-5 can add a separate linkage structure later.
- SYM-10: P0-4 uses only built-in default symptoms. User symptom add/edit remains P1.
- DB-06: Database version increases from 5 to 6 for symptom definitions and symptom records.
- BACKUP-07: Symptom backup/restore remains deferred to P0-6.

## V3-SYM-P05: PRN Symptom Links

- PRN-SYM-01: When recording a PRN medication dose, the user can optionally select related symptoms.
- PRN-SYM-02: Selecting no symptoms is allowed and preserves the existing PRN log behavior.
- PRN-SYM-03: Selecting multiple symptoms for one PRN log is allowed.
- PRN-SYM-04: PRN symptom relationships are stored in a separate `prn_symptom_links` table.
- PRN-SYM-05: `prn_symptom_links` stores `prnMedicationLogId`, `symptomDefinitionId`, and `createdAt`.
- PRN-SYM-06: Duplicate `prnMedicationLogId + symptomDefinitionId` relationships are forbidden.
- PRN-SYM-07: A PRN symptom link is a neutral related-record link, not a cause relationship.
- PRN-SYM-08: A PRN symptom link is not an effect, improvement, or worsening relationship.
- PRN-SYM-09: The app must not diagnose, classify risk, infer causality, or recommend medication changes from PRN symptom links.
- PRN-SYM-10: PRN logs and `symptom_records` remain independent.
- PRN-SYM-11: Selecting symptoms from the PRN screen must not create, update, or delete `symptom_records`.
- PRN-SYM-12: Symptom severity remains independent and is not selected or changed from the PRN screen.
- PRN-SYM-13: Active symptom definitions from P0-4 are the only selectable symptoms.
- PRN-SYM-14: Deleting a PRN log must also delete its `prn_symptom_links`.
- PRN-SYM-15: Existing PRN logs without links remain readable and display normally.
- DB-07: Database version increases from 6 to 7 for `prn_symptom_links`.
- BACKUP-08: PRN symptom link backup/restore remains deferred to P0-6.

## V3-SYM-P06: Symptom Backup / Restore

- BACKUP-09: P0-6 backup version is 4.
- BACKUP-10: Backup version 4 includes `symptom_definitions`.
- BACKUP-11: Backup version 4 includes `symptom_records`.
- BACKUP-12: Backup version 4 includes `prn_symptom_links`.
- BACKUP-13: Restore replaces existing symptom definitions, symptom records, and PRN symptom links with the backup snapshot.
- BACKUP-14: Backup versions 1, 2, and 3 remain accepted.
- BACKUP-15: Older backups without symptom collections restore with empty symptom definitions, symptom records, and PRN symptom links.
- DB-08: P0-6 does not change the existing database schema or database version.

## V3-HEALTH-P1-1: Health Field Visibility

- HEALTH-VIS-01: A user can show or hide the following health-record fields: weight, blood pressure, water, exercise, sleep, and condition.
- HEALTH-VIS-02: Date is not a hideable field.
- HEALTH-VIS-03: Hidden fields are removed from the visible UI only; hiding a field does not delete existing `HealthRecord` data.
- HEALTH-VIS-04: Showing a hidden field again displays the existing stored value.
- HEALTH-VIS-05: Editing and saving a health record while fields are hidden must preserve the hidden field values.
- HEALTH-VIS-06: Visibility settings are stored with `SharedPreferences` through `HealthFieldVisibilityService`.
- HEALTH-VIS-07: Default visibility is all-visible.
- HEALTH-VIS-08: Visibility settings persist after app restart.
- HEALTH-VIS-09: Home today's health card respects the visibility settings.
- HEALTH-VIS-10: Health record list respects the visibility settings.
- HEALTH-VIS-11: Health record add/edit screen respects the visibility settings.
- HEALTH-VIS-12: Statistics respects the visibility settings: hiding weight hides the weight tab, hiding blood pressure hides the blood pressure tab, and the lab tab remains available.
- DB-09: P1-1 does not change `HealthRecord`, the `health_records` schema, or the database version.
- BACKUP-16: P1-1 visibility settings are not included in backup, do not change `BackupService`, and do not change backupVersion 4.

## V3-HEALTH-P1-2: Optional Water Input

- HEALTH-WATER-01: Water intake is optional in the visible health-record UI.
- HEALTH-WATER-02: When the water field is visible and left blank, `waterIntake` is saved as `null`.
- HEALTH-WATER-03: When the water field is visible and a positive integer is entered, that value is saved as `waterIntake`.
- HEALTH-WATER-04: When an existing record has a water value and the user clears the visible water field before saving, the value is explicitly removed and `waterIntake` is saved as `null`.
- HEALTH-WATER-05: `0` is invalid for water intake and is not treated as the same state as `null`.
- HEALTH-WATER-06: When water is hidden through P1-1 visibility settings, editing and saving the record preserves the existing `waterIntake` value.
- HEALTH-WATER-07: P1-2 does not add a separate water toggle, checkbox, water-specific setting, or "not recorded" state.
- HEALTH-WATER-08: P1-2 does not add water statistics and does not change the Home display policy.
- DB-10: P1-2 does not change `HealthRecord`, the `health_records` schema, or the database version.
- BACKUP-17: P1-2 does not change `BackupService`, backup payload shape, or backupVersion 4.

## V3-SYM-P1-3: User Symptom Add/Edit

- SYM-USER-01: A user can add a new active symptom definition.
- SYM-USER-02: Added user symptom definitions are stored with `isDefault = false` and `isActive = true`.
- SYM-USER-03: A user can rename only user-added symptom definitions where `isDefault = false`.
- SYM-USER-04: Built-in default symptoms where `isDefault = true` cannot be renamed.
- SYM-USER-05: Built-in default symptoms remain `두통`, `피로`, `메스꺼움`, and `어지러움`.
- SYM-USER-06: P1-3 does not add symptom delete, deactivate, reorder, icon, color, category, statistics, severity changes, or PRN effect/cause analysis.
- SYM-USER-07: Symptom names are trimmed before saving.
- SYM-USER-08: Blank or whitespace-only symptom names are rejected.
- SYM-USER-09: A symptom name that exactly matches another active symptom definition is rejected.
- SYM-USER-10: Renaming a symptom to its own current name is allowed.
- SYM-USER-11: P1-3 does not add arbitrary name length limits or case-insensitive duplicate matching.
- SYM-USER-12: Renaming a user symptom preserves the existing symptom definition id.
- SYM-USER-13: Existing `symptom_records` keep their existing `symptomDefinitionId` and severity after rename.
- SYM-USER-14: Existing `prn_symptom_links` keep their existing `symptomDefinitionId` after rename.
- SYM-USER-15: After rename, existing symptom records and existing PRN links display the new symptom definition name.
- DB-11: P1-3 does not change the `symptom_definitions`, `symptom_records`, or `prn_symptom_links` schema and does not change the database version.
- BACKUP-18: P1-3 does not change `BackupService`, backup payload shape, restore semantics, or backupVersion 4.

## Deferred After P1-3

- Advanced PRN/symptom statistics.

## V3.0.1 HOT FIX: Lab CRUD UX / Medication History / Home Medication Display / Statistics Date Display

### Scope

- V3.0.1 improves only high-friction V3.0.0 usage paths.
- V3.0.1 does not add V3.1.0 features such as lab reference ranges, automatic lab-unit memory, exercise restructuring, calories, GPS/distance/elevation/heart-rate capture, Samsung Health, InBody integration, or medical normal/risk judgment.

### Lab Result CRUD UX

- V301-LAB-01: A lab-result date detail row must show explicit edit and delete actions.
- V301-LAB-02: The existing row-tap edit behavior may remain available.
- V301-LAB-03: The lab-result edit form must continue to allow date changes, including correcting a result saved with today's date to a past date.
- V301-LAB-04: Lab-result delete must keep confirmation before removal.
- V301-LAB-05: Deleting the last result on a date must remove the empty date group/detail state.
- V301-LAB-06: Saving a new lab result from the main `+` flow must navigate to the saved date's detail screen.
- V301-LAB-07: Adding another result from the detail screen's `+ 검사 항목 추가` flow must keep that detail date as the initial date.
- V301-LAB-08: Multiple lab results on the same date must remain grouped on that date.
- V301-LAB-09: V3.0.1 must not change the `LabResult` model, `lab_results` schema, or `LabResultService` data structure.

### Medication History

- V301-MED-01: Today's medication screen must provide an explicit `기록` entry point while preserving the existing `관리` entry point.
- V301-MED-02: Medication history must be a separate read-only screen.
- V301-MED-03: Medication history must not add past medication edit or delete actions.
- V301-MED-04: Medication history must display only actually stored scheduled `medication_logs` and PRN `prn_medication_logs`.
- V301-MED-05: A missing scheduled log must not be fabricated or displayed as a missed-dose record.
- V301-MED-06: An actual stored scheduled log with `isTaken == false` may be displayed as a saved missed-dose record and must remain distinguishable from no log.
- V301-MED-07: A taken scheduled historical log must display its dose snapshot when a snapshot exists.
- V301-MED-08: A legacy scheduled log with no dose snapshot must not fall back to the current medication dose as historical dose.
- V301-MED-09: Inactive or soft-deleted medications may be used for historical medication-id-to-name lookup through an all-medications read API.
- V301-MED-10: V3.0.1 must not add a medication-name snapshot column or any database migration.
- V301-MED-11: PRN history must display the stored `PrnMedicationLog.takenAt`, `doseValue`, and `doseUnit`.
- V301-MED-12: PRN history must not fall back to the current medication dose.
- V301-MED-13: PRN related symptoms must be resolved through existing `prn_symptom_links`.
- V301-MED-14: PRN logs without related symptoms must still display normally.
- V301-MED-15: Multiple PRN logs on the same date must display as separate history entries.
- V301-MED-16: Related symptoms must be presented neutrally; the app must not infer cause, effect, improvement, worsening, diagnosis, risk, or medication advice.

### Home Today's Medication Display

- V301-HOME-MED-01: Home must display all scheduled medication items for today instead of limiting the preview to three items.
- V301-HOME-MED-02: Today's scheduled medication items must be grouped by time slot in this order: morning, lunch, evening, bedtime.
- V301-HOME-MED-03: Empty time-slot groups must be hidden.
- V301-HOME-MED-04: Because the group header shows the time slot, each medication row must not repeat the same time-slot label.
- V301-HOME-MED-05: Medication rows must keep medication name, dose, taken/not-taken state, and status icon.
- V301-HOME-MED-06: A completed scheduled dose must keep displaying the historical dose snapshot.
- V301-HOME-MED-07: An untaken scheduled dose must keep displaying the current medication dose.
- V301-HOME-MED-08: Home must keep using the existing `SingleChildScrollView` so all medication groups remain reachable when many medications are scheduled.
- V301-HOME-MED-09: The medication confirmation button remains after all medication groups.
- V301-HOME-MED-10: V3.0.1 must not newly display PRN medications on Home.
- V301-HOME-MED-11: V3.0.1 Home display changes must not change DB, model, service, or backup behavior.

### Statistics Date Display

- V301-STAT-01: Statistics value-list dates must display the existing `MM.dd` string on one line.
- V301-STAT-02: The shared value-row date display fix applies to weight, blood pressure, and lab statistics lists.
- V301-STAT-03: V3.0.1 must not change the date string format.
- V301-STAT-04: V3.0.1 must not change chart or x-axis date rendering.
- V301-STAT-05: The date display fix must not change statistics data calculation.

### Compatibility

- V301-COMPAT-01: `databaseVersion` remains 7.
- V301-COMPAT-02: `backupVersion` remains 4.
- V301-COMPAT-03: V3.0.1 does not change the DB schema.
- V301-COMPAT-04: V3.0.1 does not change backup payload shape.
- V301-COMPAT-05: Existing V3.0.0 data remains compatible.

## V3.1.0: Exercise Records

### Scope

- V310-EX-SCOPE-01: Exercise recording is separated from `HealthRecord.steps` into an independent `ExerciseRecord` structure.
- V310-EX-SCOPE-02: V3.1.0 supports exercise create, past-record lookup, edit, and delete.
- V310-EX-SCOPE-03: A user can save multiple exercise records on the same date.
- V310-EX-SCOPE-04: Exercise is reachable from the Health screen without adding a sixth root bottom-navigation tab.
- V310-EX-SCOPE-05: Home shows exercise through `ExerciseService`, not through legacy `HealthRecord.steps`.

### ExerciseRecord

- V310-EX-MODEL-01: `ExerciseRecord` stores `id`, `date`, `exerciseType`, `durationMinutes`, `intensity`, `weightSnapshot`, `metSnapshot`, `estimatedCalories`, `createdAt`, and `updatedAt`.
- V310-EX-MODEL-02: `ExerciseType` values are walking, running, cycling, hiking, swimming, strengthTraining, stationaryBike, treadmill, elliptical, stairs, yogaStretching, and other.
- V310-EX-MODEL-03: Exercise type labels are `걷기`, `달리기`, `자전거`, `등산`, `수영`, `근력운동`, `실내자전거`, `러닝머신`, `일립티컬`, `계단운동`, `요가·스트레칭`, and `기타`.
- V310-EX-MODEL-04: `ExerciseIntensity` values are light, moderate, and vigorous, displayed as `가볍게`, `보통`, and `강하게`.
- V310-EX-MODEL-05: Stored enum values and display labels remain distinct, with value-based restoration for DB and backup data.

### Validation and Calculation

- V310-EX-VAL-01: Exercise dates in the future are rejected.
- V310-EX-VAL-02: `durationMinutes` must be a positive integer.
- V310-EX-CAL-01: MET values are managed in one app constant source, not duplicated in screens or services.
- V310-EX-CAL-02: `metSnapshot` is stored from the selected exercise type and intensity.
- V310-EX-CAL-03: UI text must use `예상 소모 칼로리`.
- V310-EX-CAL-04: The app must not claim exact calories or Samsung Health-equivalent calorie values.
- V310-EX-CAL-05: `estimatedCalories = metSnapshot * weightSnapshot * durationMinutes / 60`.
- V310-EX-CAL-06: If `weightSnapshot` is `null`, `estimatedCalories` is `null` and UI displays that expected calorie calculation is unavailable.

### Weight Snapshot Policy

- V310-EX-SNAP-01: New exercise creation snapshots `HealthRecord.weight` for the exercise date.
- V310-EX-SNAP-02: Exercise creation succeeds even when the exercise date has no health weight record.
- V310-EX-SNAP-03: Editing an exercise without changing the date preserves the existing `weightSnapshot`.
- V310-EX-SNAP-04: Changing the exercise date creates a new `weightSnapshot` from the new date's health record.
- V310-EX-SNAP-05: Later health-record weight edits do not automatically change existing exercise snapshots.
- V310-EX-SNAP-06: Changing exercise type, intensity, or duration recalculates `metSnapshot` and `estimatedCalories` from the stored snapshot policy.

### DB and Backup

- V310-EX-DB-01: `databaseVersion` increases from 7 to 8.
- V310-EX-DB-02: V3.1.0 adds `exercise_records`.
- V310-EX-DB-03: `exercise_records.date` is not unique because multiple exercises per day are allowed.
- V310-EX-DB-04: V3.1.0 does not delete or alter `health_records.steps`.
- V310-EX-BACKUP-01: `backupVersion` increases from 4 to 5.
- V310-EX-BACKUP-02: Supported backup versions are 1, 2, 3, 4, and 5.
- V310-EX-BACKUP-03: V5 backups include `exerciseRecords`.
- V310-EX-BACKUP-04: V1 through V4 backups without `exerciseRecords` remain restorable.
- V310-EX-BACKUP-05: Legacy `healthRecords.steps` values remain preserved through backup/restore.
- V310-EX-BACKUP-06: Steps are not migrated or converted into `ExerciseRecord`.

### Legacy Steps Compatibility

- V310-EX-LEGACY-01: `HealthRecord.steps` remains in the model for legacy compatibility.
- V310-EX-LEGACY-02: `health_records.steps` remains in the DB schema.
- V310-EX-LEGACY-03: New health-record UI no longer provides steps input.
- V310-EX-LEGACY-04: Editing an existing health record preserves existing steps values even though the steps input is no longer visible.
- V310-EX-LEGACY-05: Home no longer displays legacy steps as exercise.

### Excluded Scope

- V310-EX-NON-01: V3.1.0 does not add GPS, distance, elevation, heart-rate capture, Samsung Health, Google Fit, exercise auto-detection, exercise goals, advanced exercise statistics, or custom exercise-type CRUD.
