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
- Support decimal medication doses.
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

## Deferred From This Feature Commit

Medication, PRN, dose history, symptoms, health-field visibility, and advanced statistics are not implemented in the future-date feature commit.
