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
