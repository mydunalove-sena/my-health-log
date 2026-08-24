# My Health Log

## 프로젝트 소개

My Health Log는 개인이 자신의 건강 정보를 날짜별로 기록하고 변화 추이를 확인할 수 있도록 만든 Flutter 기반 개인 건강 기록 앱입니다.

이 프로젝트는 개인 건강 기록 앱을 직접 기획하고 Flutter로 구현한 뒤 요구사항 기반 QA, Regression Test, Android Release APK 생성까지 수행한 개인 프로젝트입니다.

## 프로젝트 목적

단순히 Flutter 화면을 만드는 것보다, 하나의 작은 제품을 끝까지 다루는 과정을 경험하고 기록하는 것을 목표로 했습니다.

진행 범위는 다음 흐름으로 정리했습니다.

```text
기획 -> 요구사항 정의 -> IA -> User Flow -> Wireframe -> Data Model -> 구현 -> QA -> Regression -> Release
```

QA 관점에서는 요구사항과 실제 구현 결과의 연결, CRUD 동작, 데이터 상태 변화, Local Persistence, DB Migration, Regression, Release Smoke Test를 중점적으로 확인했습니다.

## 주요 기능

### Home

- 오늘 건강 상태 요약
- 오늘 복약 상태 요약
- Health / Medication 주요 흐름 진입
- 데이터가 없을 때 Empty State 표시

### Health Record

- 체중 기록
- 혈압 기록
- 수분 기록
- 운동 기록
- 수면 기록
- 컨디션 선택
- Add / Edit / Delete
- 날짜별 1개 Record 제한
- Local SQLite Persistence

### Medication

- 약 등록 / 수정
- 복용량 선택 입력
- 복용 시간 선택
- Soft Delete
- 활성 약만 현재 목록에 표시

### Medication Log

- 날짜별 복용 여부 기록
- 복용 Toggle
- `takenAt` 저장 / 초기화
- 날짜별 상태 분리
- Medication Soft Delete 후 기존 MedicationLog 보존

### Lab Result

- 검사 결과 등록
- 날짜별 그룹 표시
- 날짜별 Detail 화면
- Add / Edit / Delete
- 동일 날짜 + 동일 검사 항목 중복 방지

### Statistics

- 체중 변화 표시
- 혈압 변화 표시
- 검사 결과 변화 표시
- 그래프 아래 실제 기록값 함께 표시
- 별도 Statistics table 없이 저장된 HealthRecord / LabResult 데이터 조회

## 기술

- Flutter
- Dart
- SQLite
- sqflite
- Android Emulator
- Flutter Test
- Integration Test
- Git CLI status check

Chart 전용 외부 package는 추가하지 않았습니다. V1 통계 그래프는 Flutter `CustomPainter` 기반으로 구현했습니다.

## QA Approach

V1 QA는 요구사항 기반으로 수행했습니다.

검증 범위:

- 요구사항 기반 검증
- CRUD 검증
- Validation
- Empty State
- 데이터 Persistence
- DB Migration
- Cross Feature 영향
- Regression
- Release APK Smoke Test

QA 결과:

| 항목 | 결과 |
|---|---:|
| Requirement-based Test Cases | 62 |
| PASS | 62 |
| FAIL | 0 |
| BLOCKED | 0 |
| Automated Tests | 64 PASS |
| Regression | 62 PASS |
| Release Candidate | PASS |
| V1 Release | PASS |

이번 테스트 범위에서 발견된 결함 없음.

## 기술적으로 의미 있었던 구현

### SQLite Migration

V1 개발 중 기능 확장에 따라 같은 SQLite DB 파일을 유지하면서 table을 확장했습니다.

```text
DB v1
- health_records

DB v2
- medications
- medication_logs 추가

DB v3
- lab_results 추가
```

기존 데이터를 삭제하거나 초기화하지 않고 `onUpgrade` migration으로 확장했습니다.

### Medication Soft Delete

Medication 삭제 시 과거 MedicationLog 보존을 위해 실제 DELETE 대신 `isActive = false`로 처리했습니다.

현재 Medication Today / Medication List에서는 비활성 약을 숨기고, 기존 MedicationLog는 이후 과거 기록 조회에 사용할 수 있도록 유지했습니다.

### Statistics

Statistics용 별도 DB table을 만들지 않고, 저장된 HealthRecord / LabResult 데이터를 조회해 체중, 혈압, 검사 결과 변화로 표시했습니다.

그래프만으로 값을 추정하지 않도록 실제 날짜와 수치 목록을 함께 표시했습니다.

## V2 Backup / Restore

V2에서는 로컬 건강 기록 데이터의 JSON 백업·복원 기능을 추가했습니다.

### 목표

- 사용자가 입력한 전체 건강 기록 데이터를 하나의 JSON 파일로 백업합니다.
- JSON 백업 파일을 선택해 현재 로컬 데이터를 전체 교체 방식으로 복원합니다.
- V1의 CRUD, Soft Delete, Statistics 동작과 SQLite 데이터 구조를 유지합니다.

### 로컬 저장 방식

- 저장 기술: SQLite / sqflite
- DB 파일: `my_health_log.db`
- DB 버전: 3
- 테이블: `health_records`, `medications`, `medication_logs`, `lab_results`
- Soft Delete: `medications.isActive = 0`

### 백업 파일 형식

```json
{
  "app": "My Health Log",
  "backupVersion": 1,
  "createdAt": "ISO-8601",
  "appVersion": "1.0.1+2",
  "data": {
    "healthRecords": [],
    "medications": [],
    "medicationLogs": [],
    "labResults": []
  }
}
```

기본 파일명은 `my_health_log_backup_YYYYMMDD_HHMMSS.json`입니다.

### 복원 정책

- 복원 전 JSON 구조, 앱 식별자, 백업 버전, 필수 컬렉션, 개별 record 구조를 검증합니다.
- `medicationLogs.medicationId`가 백업 내 `medications.id`를 참조하는지 확인합니다.
- 복원은 현재 데이터를 백업 데이터로 전체 교체합니다.
- SQLite transaction 안에서 삭제와 삽입을 수행해 복원 실패 시 반쯤 삭제된 상태를 피합니다.
- 복원 성공 후 Health, Medication, Lab 서비스 상태를 다시 로드합니다.

### 데이터 손실 방지

복원 화면에는 다음 경고를 표시합니다.

```text
백업 데이터를 복원하면 현재 저장된 데이터가 백업 데이터로 교체됩니다. 현재 데이터를 보관하려면 먼저 백업해 주세요.
```

실제 건강 데이터나 생성된 개인 백업 JSON은 저장소에 포함하지 않습니다.

### 테스트 범위

- 빈 데이터 백업
- 4개 엔티티 혼합 데이터 백업
- null, 0, 한글, 특수문자, 긴 문자열 보존
- invalid JSON, 다른 앱 파일, 누락/미지원 backupVersion, 잘못된 data 구조 거부
- 전체 복원과 기존 데이터 전체 교체
- ID/관계 유지
- 실패 시 기존 데이터 보존
- 반복 복원 시 중복 없는 동일 상태 유지
- 원본 데이터 생성 -> backup JSON 생성 -> 저장소 삭제/변경 -> restore -> 전체 데이터 비교

자동 검증 결과, 로컬 건강 기록 데이터의 JSON 백업·복원 기능을 구현하고, 백업→삭제/변경→복원 후 원본과의 데이터 무결성을 검증했습니다.

### 실행 방법

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
android\gradlew.bat -p android assembleDebug
flutter build apk --release
```

### 실제 Android 기기 QA 설치 절차

Samsung SM-S918N 실제 기기 QA에서는 다중 사용자 영역을 먼저 확인합니다.

```bash
adb shell pm list users
```

테스트 기기에 User 0(기본 사용자), User 95(Samsung DUAL_APP), User 150(Secure Folder) 같은 사용자 영역이 함께 존재할 수 있습니다. 개발용 ADB sideload 설치는 기본 사용자만 대상으로 명시합니다.

```bash
adb install --user 0 -r build/app/outputs/flutter-apk/app-release.apk
```

Android SDK 전체 경로를 사용할 때도 동일하게 `--user 0`을 포함합니다.

```bash
%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe install --user 0 -r build\app\outputs\flutter-apk\app-release.apk
```

설치 후 사용자별 패키지 상태를 확인합니다.

```bash
adb shell pm list packages --user 0 | findstr my_health_log
adb shell pm list packages --user 95 | findstr my_health_log
```

정상 기준:

- User 0: `com.example.my_health_log` 존재
- User 95: `com.example.my_health_log` 없음

User 95에 잘못 설치된 경우에는 User 0 앱과 데이터를 삭제하지 않고 DUAL_APP 사용자 영역에서만 제거합니다.

```bash
adb shell pm uninstall --user 95 com.example.my_health_log
```

V2 상세 문서는 `docs/v2/`에서 확인할 수 있습니다.

## Final V2 QA Status

최종 V2 공개 기준본은 실제 확인된 결과만 기록합니다.

| Item | Result |
| --- | --- |
| `flutter analyze` | PASS |
| `flutter test` | PASS: 73 tests |
| Android Debug build | PASS |
| Android Release build | PASS |
| Samsung SM-S918N APK install/run | PASS |
| Backup JSON creation | PASS |
| Android file save UI | PASS |
| Save backup JSON to Downloads | PASS |
| Add health record after backup | PASS |
| Restore saved JSON file | PASS |
| Full replacement restore policy | PASS |
| Data persistence after app restart | PASS |
| Home health summary UI regression | Fixed |
| Exercise unit label | Fixed: `steps` -> `걸음` |
| ADB multi-user install issue | Documented and recovered for User 95 DUAL_APP |

## Release

- Current Version: `1.0.1+2`
- Current Release Type: Internal Portfolio V2 Release
- Current Release APK: `release/v1.0.1/MyHealthLog-v1.0.1.apk`
- Current Release Notes: `release/v1.0.1/RELEASE_NOTES.md`
- Current SHA256: `release/v1.0.1/SHA256.txt`

V1 baseline artifact remains available:

- V1 Version: `1.0.0+1`
- V1 Release APK: `release/v1.0.0/MyHealthLog-v1.0.0.apk`
- V1 Release Notes: `release/v1.0.0/RELEASE_NOTES.md`
- V1 SHA256: `release/v1.0.0/SHA256.txt`

APK 다운로드 링크나 외부 배포 링크는 이 README에 포함하지 않습니다.

## 개인정보 및 의료 기능 범위

V1은 사용자가 직접 입력한 건강 정보를 Local SQLite DB에 기록하는 개인 기록 앱입니다.

포함하지 않은 범위:

- 로그인
- 서버 전송
- Cloud Sync
- 의료적 정상 / 위험 판정
- 약물 효과 분석
- 복용량 추천
- 검사 수치 의료 해석
- 사용자 대상 공개 운영

