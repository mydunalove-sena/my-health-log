# V2 Test Cases

## Backup

| ID | Case | Expected |
|---|---|---|
| V2-BK-001 | Empty data backup | Valid JSON with empty collections |
| V2-BK-002 | One record backup | Record fields are preserved |
| V2-BK-003 | Four entity mixed data | All entity collections are preserved |
| V2-BK-004 | Null values | Null remains null |
| V2-BK-005 | Zero values | Zero remains zero |
| V2-BK-006 | Korean text | Korean text remains unchanged |
| V2-BK-007 | Special characters | Special characters remain unchanged |
| V2-BK-008 | Long text | Full string is preserved |
| V2-BK-009 | Metadata | App, backupVersion, createdAt, appVersion exist |
| V2-BK-010 | Decode comparison | Decoded backup equals source snapshot |
| V2-BK-011 | Backup file name | Uses `my_health_log_backup_YYYYMMDD_HHMMSS.json` |
| V2-BK-012 | Backup file save | Android system file save UI opens and writes JSON to the selected location |
| V2-BK-013 | Backup file share | Share Sheet remains available as a separate optional action |

## Validation

| ID | Case | Expected |
|---|---|---|
| V2-VAL-001 | Valid file | Validation succeeds |
| V2-VAL-002 | Invalid JSON | Rejected |
| V2-VAL-003 | Different app value | Rejected |
| V2-VAL-004 | Missing backupVersion | Rejected |
| V2-VAL-005 | Unsupported backupVersion | Rejected |
| V2-VAL-006 | Missing data structure | Rejected |
| V2-VAL-007 | Required collection type error | Rejected |
| V2-VAL-008 | Individual record structure error | Rejected |
| V2-VAL-009 | Missing medication relation | Rejected |

## Restore

| ID | Case | Expected |
|---|---|---|
| V2-RS-001 | Full restore | Repository equals backup snapshot |
| V2-RS-002 | Existing data replacement | Previous data is removed |
| V2-RS-003 | ID and relationship preservation | IDs and medication log relationships remain |
| V2-RS-004 | healthRecords comparison | Restored fields equal source fields |
| V2-RS-005 | medications comparison | Restored fields equal source fields |
| V2-RS-006 | medicationLogs comparison | Restored fields equal source fields |
| V2-RS-007 | labResults comparison | Restored fields equal source fields |
| V2-RS-008 | Failure rollback | Existing data remains |
| V2-RS-009 | Repeat restore | Same final state, no duplicates |

## Round Trip

| ID | Case | Expected |
|---|---|---|
| V2-RT-001 | Source data -> backup JSON -> delete/change storage -> restore -> compare all fields | Restored data equals original data |
