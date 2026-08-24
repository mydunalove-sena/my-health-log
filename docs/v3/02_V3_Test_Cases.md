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
| V3-MED-TC-18 | Backup | Create V3 backup | Uses backupVersion 2 and includes PRN logs |
| V3-MED-TC-19 | Backup | Restore V2 backupVersion 1 | Accepted; V3 defaults applied |
| V3-MED-TC-20 | Regression | Existing Home scheduled medication | Remains displayed correctly |

## Regression

For each feature commit:

1. Run feature-specific automated tests.
2. Run the complete `flutter test` suite.
3. Run `flutter analyze`.
4. Run relevant Android manual checks.
5. Verify Git working tree before commit.
