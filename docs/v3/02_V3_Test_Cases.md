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

## Regression

After implementation:

1. Run the new `future_date_test.dart`.
2. Run the complete `flutter test` suite.
3. Run `flutter analyze`.
4. Perform manual DatePicker checks for Health and Lab on an Android target.
