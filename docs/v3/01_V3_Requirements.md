# My Health Log V3 Requirements

## Goal

V3 improves medication management and symptom logging based on real usage while preserving the V2 baseline and existing user data.

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
- Add symptom recording.
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
- BACKUP-01: V3 backup includes structured medication fields and PRN logs.
- BACKUP-02: V3 uses backup version 2.
- BACKUP-03: V3 can still validate and restore V2 backup version 1.

## Deferred After P0-2

- Medication dose-change history.
- Symptom recording.
- Symptom-to-PRN linkage.
- Advanced PRN/symptom statistics.
- Health-field visibility settings.
