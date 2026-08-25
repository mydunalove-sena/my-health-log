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

## Regression

For each feature commit:

1. Run feature-specific automated tests.
2. Run the complete `flutter test` suite.
3. Run `flutter analyze`.
4. Run relevant Android manual checks.
5. Verify Git working tree before commit.
