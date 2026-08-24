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

Added coverage for:

- today save
- past-date save
- tomorrow rejection
- far-future rejection
- edit/update to future rejection
- DatePicker maximum date
- direct service bypass prevention
- legacy future-data preservation and UI-list exclusion
- Statistics exclusion

### Regression

- lutter analyze: PASS
- Future-date automated tests: 12 PASS
- Full regression: 85 PASS
- Android manual QA: Health DatePicker future dates disabled
- Android manual QA: Lab DatePicker future dates disabled
