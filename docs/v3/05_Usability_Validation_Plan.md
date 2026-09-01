# My Health Log — Small-Scale Usability Validation Plan

## 1. Validation Purpose

The purpose of this validation is to answer one practical question:

> Can My Health Log, originally created for a real personal health-record need, also be used comfortably by other kidney-transplant or dialysis users?

This is not a business validation, clinical trial, medical-effect study, or treatment-effect evaluation.

The validation focuses on whether actual users can understand and repeatedly use the current app for personal health recording.

## 2. First Validation Scope

### Target user groups

The first validation scope is intentionally limited to:

- kidney-transplant users
- dialysis users

The app also includes management types and lab-test presets for liver transplant, lung transplant, pancreas transplant, general health, and custom use.

Those implemented options remain in the app, but they are not treated as user-validated until corresponding users actually participate.

Principle:

> Implemented scope and validated scope are separate.

## 3. Current App Baseline

The validation should use the current documented V3 code baseline unless a confirmed blocker requires a new build.

Current documented baseline:

- app version: `3.6.0+12`
- databaseVersion: 8
- backupVersion: 6
- branch: `v3`

Confirmed V3.6 evidence includes automated regression and lab-settings backup/restore verification.

A separate V3.6.0 Release APK build and separate V3.6.0 Android device QA are not confirmed by the available final evidence. Before external APK distribution, the actual distribution build and installation path must therefore be confirmed separately.

## 4. Validation Type

This activity is a usability / user-experience validation.

It evaluates:

- understandability
- ease of input
- ease of repeated input
- navigation
- historical lookup
- input-safety risk
- missing functions
- unnecessary or confusing functions
- willingness to continue using the app

It does not evaluate:

- whether the app improves health
- whether the app improves treatment outcomes
- whether the app controls specific lab values
- whether the app improves medication adherence clinically
- whether the app provides diagnosis
- whether the app provides medical recommendations

## 5. Recruitment Approach

The recruitment method is **not fixed yet**.

At the current stage:

- no specific organization, institution, community, or intermediary is selected
- no participant-recruitment route is treated as decided
- recruitment should not begin until the distributable Android build and participant-facing materials are ready
- the method should be chosen later based on practicality, participant burden, privacy, and the ability to collect usability feedback safely

The usability-validation plan remains valid even while the recruitment route is undecided.

Principle:

> Decide the recruitment method only when external validation is actually ready to begin.

## 6. Participant Count and Usage Period

The exact participant count and usage period are **not fixed yet**.

They should be decided only after confirming:

- realistic recruitment method
- participant burden
- distribution method
- whether users can install and use the Android APK
- how feedback can be collected safely

The goal is a small-scale validation, not statistical generalization.

## 7. Validation Principles

1. Use the current app rather than developing speculative new features first.
2. Do not teach every screen in advance unless the user is blocked.
3. Record where users need help.
4. Do not steer participants toward positive feedback.
5. Do not convert every opinion directly into a requirement.
6. Do not interpret health data medically.
7. Do not request unnecessary sensitive health details.
8. Preserve negative findings and abandonment as valid results.
9. Separate app defects from user preference.
10. Improve only after practical need is confirmed.

## 8. User Data / Privacy Boundary

My Health Log stores user-entered health information locally on the Android device.

For usability validation:

- participants should not be required to send raw personal health records to the tester
- feedback can focus on interaction, understanding, missing fields, and usability
- screenshots used for feedback should avoid personal identifiers when possible
- if a screenshot contains personal or health information, it should be minimized or anonymized before portfolio use
- personal backup JSON files should not be added to the Git repository
- user-specific health information must not be used in the portfolio without appropriate removal of identifying information

The validation should collect only the information needed to understand app usability.

## 9. Validation Areas

| Area | Main Question |
|---|---|
| Start | Can the user start without extensive explanation? |
| Home | Does the user understand what is shown and where to go next? |
| Health records | Can the user record the health items they actually manage? |
| Lab results | Are the lab items the user manages available and understandable? |
| Lab settings | Can the user select a management type and adjust visible lab tests? |
| Medication | Does the scheduled-medication recording flow match actual use? |
| PRN | Is actual PRN dose recording understandable? |
| Symptoms | Can the user record needed symptoms without confusion? |
| Exercise | Does the recording method fit the user’s actual exercise pattern? |
| History | Can past records be found and corrected when needed? |
| Statistics | Can the user understand and find the history they want to review? |
| Repeated input | Does daily/repeated use become too burdensome? |
| Input safety | Is there a realistic chance of misunderstanding or wrong input? |
| Missing need | What is needed but absent? |
| Unused function | What is unnecessary or rarely used? |
| Continued use | Would the user continue using the app after initial use? |

## 10. Core Task Scenarios

The validation should not require every participant to use every feature if the feature does not match their real routine.

The following tasks are a common baseline.

### Task A — Initial orientation

Without a detailed walkthrough:

- open the app
- look at Home
- identify where health records, medication, lab results, symptoms, exercise, and statistics can be accessed

Observe:

- where the user hesitates
- labels that are misunderstood
- navigation that requires explanation

### Task B — Health record

Ask the user to record a health entry using values they are comfortable entering.

Observe:

- field meaning
- optional fields
- save/edit flow
- whether visible fields match actual needs
- whether hidden/unused fields cause confusion

### Task C — Lab-result setup

Ask the user to review lab settings.

Observe:

- whether management type is understandable
- whether preset tests are useful
- whether important tests are missing
- whether unnecessary tests create confusion
- whether custom test addition is understandable

Do not describe the preset as medically required.

### Task D — Lab-result entry

Ask the user to enter one test date with several lab items they actually track or with non-sensitive sample values.

Observe:

- unit understanding
- numeric-entry visibility
- scrolling burden
- multi-entry flow
- confidence before save
- edit/delete discoverability

### Task E — Medication

For users who want to test medication recording:

- review scheduled medication
- record actual taken state
- view medication history

Observe:

- scheduled-time model fit
- dose/unit clarity
- history lookup
- correction flow

### Task F — PRN

If the participant actually uses PRN medication or is comfortable testing the flow:

- record a PRN event
- optionally link a symptom
- review the history

Observe:

- `복용` vs `추가 복용` meaning
- event-based recording understanding
- whether related symptoms are interpreted incorrectly as cause/effect

### Task G — Symptoms

Ask the user to record a symptom if relevant.

Observe:

- severity-level understanding
- default symptom usefulness
- need for custom symptoms
- confusion between symptom recording and PRN linking

### Task H — Exercise

If relevant to the participant:

- record an exercise
- review estimated calories and history

Observe:

- exercise-type fit
- duration/intensity burden
- understanding that calories are estimated
- need for features that are currently outside scope

### Task I — Historical lookup

Ask the user to find:

- a past health record
- a past medication record if applicable
- a past lab result
- a lab Statistics series for a selected year

Observe search/navigation burden and whether users can locate the intended record without help.

## 11. Observation Rules

During task execution, record:

- completed without help
- completed after hesitation
- completed after hint
- failed / abandoned
- misunderstood
- wrong input risk
- feature not relevant to participant

Do not treat "feature not relevant" as a defect.

Do not treat a single preference as a confirmed general requirement.

## 12. Feedback Questions

After real use, feedback can be collected with concise questions such as:

1. Which part was easiest to use?
2. Which part was hardest to understand?
3. Was there any point where you did not know what to press next?
4. Were any input fields unnecessary for you?
5. Was anything you normally record missing?
6. Was any number/unit field easy to misunderstand or enter incorrectly?
7. Was repeated input burdensome?
8. Was it easy to find a past record?
9. Was there any feature you would probably never use?
10. If you stopped using the app, what would be the main reason?
11. Would you continue using the current version? Why or why not?
12. What is the one change that would make the app most useful to you?

## 13. Feedback Classification

Every finding should first be classified before development work begins.

| Category | Meaning |
|---|---|
| Bug | Current implemented behavior does not work as intended |
| Usability issue | Function works, but the user struggles to understand or operate it |
| Input-safety issue | UI may lead to misunderstanding or incorrect data entry |
| Improvement idea | Current behavior works; change may make it easier |
| New requirement | Needed workflow or information is not currently supported |
| Personal preference | Individual preference without broader evidence yet |
| Repeated-use problem | Friction emerges only after repeated real use |
| Not relevant | Feature is not used by that participant’s real routine |

## 14. Priority Decision Rule

Do not prioritize solely by how strongly one user complains.

Consider:

- frequency across participants
- severity of wrong-input or data-loss risk
- frequency in real repeated use
- whether a workaround exists
- implementation impact
- regression risk
- whether the request belongs to the current record-centered scope

Input-safety and data-loss risks should generally be reviewed before convenience-only improvements.

## 15. Evidence to Preserve

For portfolio use, preserve evidence without exposing sensitive personal data.

Useful evidence includes:

- validation plan version
- participant group category without identifying details
- task result summary
- anonymized observations
- feedback classification
- confirmed problem statements
- before/after screenshots with sensitive information removed
- improvement decision rationale
- test cases for implemented improvements
- regression result

The portfolio should not claim:

- that all kidney-transplant users have the same need
- that all dialysis users have the same need
- that the app improves health outcomes
- that an untested transplant group has been validated

## 16. Success Criteria for This Validation

This validation is successful if it produces reliable findings, not only if users like the app.

Valid outcomes include:

- users can use most flows without help
- a critical usability problem is discovered
- an input-safety issue is discovered
- a feature is found to be unnecessary
- a missing requirement is identified
- repeated-use burden causes abandonment
- the app is useful only for a narrower group than expected
- the current app is already sufficient for some users

The quality of the observation and analysis is more important than a positive evaluation.

## 17. Stop / Change Conditions

Pause or revise the validation approach if:

- distribution requires a procedure that has not been confirmed
- participants cannot reasonably install the current Android build
- a data-loss or critical input-safety defect is found
- the app crashes or cannot preserve user records
- participants misunderstand the app as providing medical judgment
- the feedback method exposes unnecessary sensitive information

A confirmed blocker should be handled before continuing broader validation.

## 18. Next Preparation Items

Before actual participant validation:

1. confirm the actual distributable Android APK baseline
2. prepare a short installation guide
3. prepare a short participant-facing app explanation
4. prepare a feedback / observation sheet
5. confirm a realistic recruitment / distribution method when external validation is ready
6. only then decide participant count and usage period

## 19. Out of Scope

The following remain outside this validation plan:

- business plan
- market-size estimation
- investment material
- revenue model
- pricing
- clinical trial
- treatment-effect validation
- automatic medical judgment
- medication-dose recommendation
- forced expansion to all transplant groups
- feature development based only on speculation

## 20. Final Validation Question

> Can kidney-transplant or dialysis users use the current My Health Log as a practical personal health-record tool, and what evidence-based changes are needed before the next version?
