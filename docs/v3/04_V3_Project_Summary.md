# My Health Log V3 Project Summary

## 1. Project Purpose

My Health Log is a personal health-record app created for two practical goals:

1. Build an app that can be used for real personal health-record management.
2. Build a QA portfolio project that demonstrates the full flow from problem discovery and requirements definition through implementation, QA, regression, Android device verification, release work, and real use.

The project was not started as a commercial product, medical device, or business plan.

## 2. Current Project Position

The current code baseline is `V3.6.0+12` on branch `v3`.

Confirmed current data versions:

- databaseVersion: 8
- backupVersion: 6

The main feature-development and QA cycle has been completed through the confirmed V3.6.0 release and real-device verification scope.

The project is now moving from continuous feature expansion toward:

- personal real-use observation
- evidence-based issue collection
- usability-validation preparation for a small number of kidney-transplant and dialysis users

V3.6.0 itself has confirmed automated QA, release APK build evidence, Git evidence, Android User 0 update-install smoke QA, and real-device Backup v6 lab-settings restore evidence.

## 3. Product Direction

My Health Log remains a record-centered app.

It records user-entered information and preserves historical meaning where possible, but it does not:

- diagnose conditions
- classify medical risk
- interpret lab results as normal/abnormal
- recommend medication changes
- recommend medication doses
- infer medical causality from symptoms and PRN medication records
- claim treatment or health-improvement effects

The project therefore separates health-record usability from medical-effect validation.

## 4. Core Functional Scope

### Health Records

- weight
- blood pressure
- water intake
- sleep
- condition
- add / edit / delete
- field visibility settings
- optional water input
- historical data preservation when fields are hidden

### Exercise Records

- independent exercise records separated from legacy `HealthRecord.steps`
- multiple exercise records per day
- exercise type
- duration
- 3-level intensity
- weight snapshot for the exercise date
- MET snapshot
- estimated calories
- history lookup / edit / delete

### Medication

- scheduled medication
- PRN medication
- decimal dose support
- dose units such as `정`, `mg`, `ml`
- medication dose-change history
- scheduled-dose historical snapshot
- medication soft delete
- historical medication-log lookup
- historical scheduled / PRN correction

### Symptoms / PRN Relationships

- symptom recording by date
- 4-level severity
- default symptom definitions
- user-added symptom definitions
- user-symptom rename
- optional PRN-to-symptom relationship
- independent relationship storage without medical cause/effect interpretation

### Lab Results

- add / edit / delete
- same-date grouping
- multi-lab entry for one test date
- predefined lab-test definitions
- management-type presets
- individual test enable/disable
- custom lab-test definitions
- default unit display
- existing-value prefill/update
- numeric-input visibility improvement
- explicit known-name alias handling for Statistics

### Statistics

- weight trend
- blood-pressure trend
- lab-result trend
- original stored values shown with charts
- lab-test + year filtering
- all original results for the selected year without recent-N truncation
- chart oldest -> newest
- list newest -> oldest
- horizontal chart scrolling for dense result sets

### Backup / Restore

- JSON backup / restore
- transactional DB replacement
- legacy backup compatibility
- symptom and PRN relationship backup
- exercise-record backup
- V3.6 lab-test-settings backup
- restore rollback protection

## 5. Major Version Flow

### V3.0.0

Core V3 improvements based on real-use requirements:

- future-date protection
- scheduled / PRN medication separation
- structured decimal dose handling
- dose-change history
- scheduled dose snapshot
- symptom recording
- PRN symptom links
- symptom backup / restore
- health-field visibility
- optional water input
- user symptom add / rename

### V3.0.1

Real-use hot fix:

- lab result edit/delete UX
- same-date lab-entry navigation
- medication history lookup
- Home scheduled-medication display expansion
- Statistics date-display correction

### V3.1.x

Exercise restructuring:

- independent exercise records
- multiple exercises per day
- weight / MET snapshot policy
- estimated calories
- exercise history CRUD
- exercise backup compatibility

### V3.2.0

Lab-input workflow improvement:

- 31 predefined lab tests
- seven management types
- preset lab-test sets
- lab-test visibility settings
- custom lab tests
- multi-entry lab screen
- automatic default-unit display

The management presets are input-convenience defaults, not medical requirements.

### V3.3.0

Lab Statistics improvement:

- explicit year selector
- current-year default
- complete selected-year result display
- no recent-N truncation
- no monthly averaging or sampling

### V3.4.0

Lab-input safety and known aliases:

- numeric-field visibility improvements for decimal values
- `HDL-Cholesterol` -> `HDL Cholesterol`
- `Inorganic P(인)` -> `P(인)`

The alias rule is explicit compatibility handling, not fuzzy matching.

### V3.5.0

Medication-history / PRN usability:

- Home displays only actual PRN records for today
- `복용` / `추가 복용` action distinction
- historical scheduled-log addition/edit
- historical PRN-log addition/edit
- safe historical-dose handling
- PRN-symptom link correction per log

### V3.5.1

Health-record list hot fix:

- water summary display
- sleep summary display
- visibility-setting consistency

### V3.6.0

Lab-test-settings backup gap closure:

- backupVersion 6
- management type backup
- enabled lab-test ID backup
- custom lab-test definition backup
- SharedPreferences restore
- v1-v5 backup compatibility
- restore rollback coverage

## 6. Confirmed QA Evidence

### Core V3 baseline

The original V3 P0/P1 completion included requirement-based testing, automated regression, Android regression, release APK generation, and physical-device verification for the confirmed scope at that time.

### V3.1.0

- focused tests: 73 PASS
- final full regression: 200 PASS
- `flutter analyze`: PASS
- release APK build: PASS
- Android exercise QA: PASS
- confirmed app functional failures: 0

### V3.2.0

- full regression: 243 PASS
- `flutter analyze`: PASS
- `git diff --check`: PASS
- Android update-install/data-preservation smoke: PASS
- launch stability: 3/3 PASS

### V3.3.0

- Statistics focused tests: 30 PASS
- related regression: 115 PASS
- full regression: 246 PASS
- Android yearly-lab-statistics checks: PASS
- launch stability: 3/3 PASS

### V3.4.0

- focused tests: 16 PASS
- related regression: 124 PASS
- full regression: 262 PASS
- release APK build: PASS
- Android numeric-input / alias Statistics QA: PASS
- final BLOCKED: 0

### V3.5.0

- focused tests: 15 PASS
- related regression: 110 PASS
- full regression: 277 PASS
- release APK build: PASS
- Android PRN / medication-history smoke: PASS

### V3.5.1

- focused tests: 17 PASS
- related regression: 48 PASS
- full regression: 281 PASS
- release APK build: PASS
- Android water/sleep list-display QA: PASS

### V3.6.0

Confirmed evidence:

- related regression: 65 PASS
- full `flutter test`: 285 PASS
- `flutter analyze`: PASS
- `git diff --check`: PASS
- backup v1-v5 compatibility: PASS
- Backup v6 lab-settings payload / validation / restore / rollback coverage: PASS
- databaseVersion remains 8
- backupVersion is 6

Evidence boundary:

- V3.6.0 Release APK build: PASS, 54,607,645 bytes, SHA-256 `FB22E909A47627EBDA31D5BAC2931F6A04A637A9D3C103543FA022428499562A`
- V3.6.0 Android device QA: PASS, Samsung SM-S918N, Android 16, SDK 36, User 0 update install, User 95 package absent
- V3.6.0 real-device Backup v6 lab-settings restore QA: PASS

## 7. QA Characteristics Demonstrated by the Project

### Requirement Traceability

Requirements were documented and linked to dedicated test cases and regression checks.

### Data-State Validation

Testing covered not only visible screens but also:

- create / update / delete state changes
- persistence after reload
- historical-data preservation
- snapshot semantics
- relationship integrity
- legacy-data compatibility

### Regression Discipline

Feature-focused tests were followed by broader regression. When a failure came from a stale test expectation rather than a product defect, the cause was separated and documented instead of being reported as an application bug.

### Device-Specific QA

Android testing included actual-device install/update behavior, persistence, launch cycles, logcat checks, and multi-user installation risks such as Samsung DUAL_APP User 95.

### Data-Safety Awareness

Real-device destructive restore testing was intentionally limited when it could put personal data at risk. Automated Backup/Restore coverage and non-destructive device checks were used where appropriate, and these limitations were documented rather than hidden.

## 8. Key Issues Found Through Real Use

Real use led to concrete improvements rather than speculative feature expansion.

Examples include:

- lab-result edit/delete friction
- limited medication-history context
- yearly lab-result visibility needs
- numeric-input truncation risk for values such as `22.3`
- inconsistent lab-test naming in Statistics
- PRN Home/history usability
- missing water/sleep summary lines in the Health list
- lab-test settings not being included in backupVersion 5

These issues were addressed after actual need or confirmed behavior was identified.

## 9. Current Documentation State

The V3 documentation set is organized as:

- `01_V3_Requirements.md` — V3 requirements through V3.6
- `02_V3_Test_Cases.md` — test cases and confirmed QA evidence through V3.6
- `03_V3_Change_History.md` — implementation / QA / version history through V3.6
- `04_V3_Project_Summary.md` — project-level completion and portfolio summary

`README.md` provides the repository-level overview and current V3 status.

## 10. Current Phase: Real Use and Usability Validation Preparation

The next question is not whether the app can be commercialized.

The next question is:

> Can an app created for a real personal health-record need also be used comfortably by other kidney-transplant or dialysis users?

The first validation scope is intentionally limited to:

- kidney-transplant users
- dialysis users

Other management types already considered in the app, including liver transplant, lung transplant, and pancreas transplant, remain implemented but are not described as user-validated.

Implementation and user validation are treated as separate states.

## 11. What the Next Validation Will Measure

The planned validation is usability / user-experience validation, not clinical-effect validation.

The intended questions include:

- Can a user start without extensive explanation?
- Can the user record the health information they actually need?
- Are the lab items they manage available?
- Is medication / PRN recording understandable?
- Are symptom and exercise flows usable in repeated daily life?
- Can historical records be found easily?
- Is repeated entry burdensome?
- Is there a realistic risk of misunderstanding or wrong input?
- What is missing?
- What is unnecessary or confusing?
- Would the user continue using the app after an initial period?

The validation does not attempt to prove that the app improves treatment outcomes or health status.

## 12. Feedback Classification Policy

Future user feedback should first be recorded and classified rather than immediately converted into development work.

Planned categories:

- Bug
- Usability issue
- Input-safety issue
- Improvement idea
- New requirement
- Personal preference
- Repeated-use problem

Only improvements with confirmed practical need should be prioritized for another development cycle.

## 13. Portfolio Narrative

The project can now be described as the following end-to-end flow:

```text
Real problem discovery
-> Requirements definition
-> Implementation
-> Requirement-based QA
-> Regression
-> Android device verification
-> Release work
-> Personal real use
-> Real-use issue discovery
-> Iterative improvement
-> Current documentation completion
-> Usability validation preparation
```

If external usability validation is completed later, the portfolio flow can extend to:

```text
-> User feedback collection
-> Feedback classification
-> Improvement prioritization
-> Evidence-based next-version development
-> Regression
```

Positive user feedback is not required for the validation to be meaningful. Confusing features, unused features, abandoned usage, or missing requirements are also valid findings when they are recorded and analyzed accurately.

## 14. Current Boundary

At this stage, the project does not include:

- business plan
- market-size analysis
- investment materials
- revenue projection
- monetization model
- clinical trial
- medical-effect validation
- treatment-effect claims
- automatic medical judgment
- unverified claims that every transplant-user group has been validated

The project remains a personal health-record and QA portfolio project moving into a small-scale usability-validation phase.
