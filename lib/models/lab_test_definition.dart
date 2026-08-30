class LabTestDefinition {
  const LabTestDefinition({
    required this.id,
    required this.displayName,
    this.defaultUnit,
  });

  final String id;
  final String displayName;
  final String? defaultUnit;

  Map<String, Object?> toJson() {
    return {'id': id, 'displayName': displayName, 'defaultUnit': defaultUnit};
  }

  factory LabTestDefinition.fromJson(Map<String, Object?> json) {
    return LabTestDefinition(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      defaultUnit: json['defaultUnit'] as String?,
    );
  }
}

enum LabManagementType {
  kidneyTransplant('kidney_transplant', '신장이식'),
  dialysis('dialysis', '투석'),
  liverTransplant('liver_transplant', '간이식'),
  lungTransplant('lung_transplant', '폐이식'),
  pancreasTransplant('pancreas_transplant', '췌장이식'),
  generalHealth('general_health', '일반 건강관리'),
  custom('custom', '사용자 직접 설정');

  const LabManagementType(this.id, this.displayName);

  final String id;
  final String displayName;

  static LabManagementType fromId(String? id) {
    for (final type in values) {
      if (type.id == id) {
        return type;
      }
    }
    return LabManagementType.generalHealth;
  }
}
