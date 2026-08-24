# My Health Log V1.0.0 Screenshot Manifest

Capture Date: 2026-08-22  
Target: My Health Log V1 Portfolio screenshots  
Output Directory: `portfolio/screenshots/v1.0.0`  
Portfolio Emulator: `MyHealthLog_Portfolio_API37` / `emulator-5556`  
Release APK Installed: `MyHealthLog-v1.0.0.apk` installed with `adb install -r` before and after capture  
Release Artifact SHA256: `30E6AF3593754AABE5C6B103D43CDF013C83E28762E3C7BF0106CF1C611DA17E`

## Capture Method

- App screenshots 01-10 were captured automatically with `adb screencap` from the isolated portfolio emulator.
- Demo app state was created by a temporary integration screenshot harness using V1 production widgets and in-memory demo data.
- The temporary harness files were removed after capture.
- The unchanged V1 Release APK was reinstalled after capture.
- QA evidence images 11-13 were generated from actual project QA/release documents and include source references.
- Existing user/test DB on `MyHealthLog_API37` was not modified.

## Screenshot List

| ID | File | Screen | Purpose | Demo Data | Portfolio Use | Verification Status |
|---|---|---|---|---|---|---|
| SHOT-01 | `01_home_dashboard.png` | Home Dashboard | Show today health summary, today medication summary, and Bottom Navigation | Health demo values for current date; Demo Med A/B | Yes | CAPTURED / PASS |
| SHOT-02 | `02_health_list.png` | Health List | Show date-based HealthRecord list | 3 demo HealthRecords across dates | Yes | CAPTURED / PASS |
| SHOT-03 | `03_health_add_edit.png` | Health Add/Edit | Show edit form with existing demo values | Current-date HealthRecord | Yes | CAPTURED / PASS |
| SHOT-04 | `04_medication_today.png` | Medication Today | Show multiple time slots and taken/not-taken states | Demo Med A morning/evening; Demo Med B lunch | Yes | CAPTURED / PASS |
| SHOT-05 | `05_medication_add_edit.png` | Medication Add/Edit | Show medication edit form | Demo Med A, 1 tab, morning/evening | Yes | CAPTURED / PASS |
| SHOT-06 | `06_lab_result_list.png` | Lab Result List | Show date-grouped lab result records | Triglyceride/Uric Acid demo values | Yes | CAPTURED / PASS |
| SHOT-07 | `07_lab_result_detail.png` | Lab Result Detail | Show one date with multiple lab items | Same-date Triglyceride and Uric Acid | Yes | CAPTURED / PASS |
| SHOT-08 | `08_statistics_weight.png` | Statistics Weight | Show weight chart and actual value list | 60.4 / 60.2 / 60.0 kg | Yes | CAPTURED / PASS |
| SHOT-09 | `09_statistics_blood_pressure.png` | Statistics Blood Pressure | Show systolic/diastolic series and actual values | 122/82, 120/80, 118/78 mmHg | Yes | CAPTURED / PASS |
| SHOT-10 | `10_statistics_lab.png` | Statistics Lab | Show selected lab item trend and actual values | Triglyceride 210 / 195 / 180 mg/dL | Yes | CAPTURED / PASS |
| QA-01 | `11_test_case_evidence.png` | Test Case Evidence | Show TC 62 / PASS 62 / FAIL 0 / BLOCKED 0 | Source: `09_Test_Cases.md` | Yes | CAPTURED / PASS |
| QA-02 | `12_regression_evidence.png` | Regression Evidence | Show Regression 62 PASS and automated verification | Source: `11_Regression_Test.md` | Yes | CAPTURED / PASS |
| QA-03 | `13_release_evidence.png` | Release Evidence | Show V1 Release PASS and APK metadata | Source: `release/v1.0.0` and `08_Development_Log.md` | Yes | CAPTURED / PASS |

## Validation

| Check | Result |
|---|---|
| PNG file count | 13 |
| Required app screenshots 01-10 | PASS |
| QA evidence screenshots 11-13 | PASS |
| Resolution | 1080 x 2400 for all PNG files |
| Image readable by System.Drawing | PASS |
| Sensitive personal data | PASS - demo/test values only |
| Real hospital/user names | PASS - none used |
| Production Dart code final state | PASS - temporary harness files removed |
| Release artifact changed | PASS - unchanged SHA256 |

## Notes

- Demo medication and lab names use neutral test labels such as `Demo Med A`, `Demo Med B`, `Triglyceride`, and `Uric Acid`.
- The screenshots are intended for portfolio presentation and do not represent real personal health data.
- No GitHub push, external upload, or portfolio site deployment was performed.
