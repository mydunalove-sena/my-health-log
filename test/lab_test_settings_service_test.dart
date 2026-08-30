import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('predefined lab test definition IDs are unique', () {
    final ids = predefinedLabTestDefinitions.map((item) => item.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
  });

  test('predefined lab test display names are unique case-insensitively', () {
    final names = predefinedLabTestDefinitions
        .map((item) => item.displayName.trim().toLowerCase())
        .toList();

    expect(names.toSet(), hasLength(names.length));
  });

  test('every management type preset references existing IDs', () {
    final predefinedIds = predefinedLabTestDefinitions
        .map((item) => item.id)
        .toSet();

    for (final entry in defaultLabTestIdsByManagementType.entries) {
      expect(
        entry.value.where((id) => !predefinedIds.contains(id)),
        isEmpty,
        reason: '${entry.key.id} contains an unknown lab test ID',
      );
    }
  });

  test('custom management type preset is empty', () {
    expect(
      defaultLabTestIdsByManagementType[LabManagementType.custom],
      isEmpty,
    );
  });

  test('management type is saved and loaded', () async {
    final service = await _persistentService();

    await service.setManagementType(LabManagementType.kidneyTransplant);
    final reloaded = await _persistentService();

    expect(reloaded.managementType, LabManagementType.kidneyTransplant);
    expect(
      reloaded.enabledLabTestIds,
      defaultLabTestIdsByManagementType[LabManagementType.kidneyTransplant],
    );
  });

  test('enabled lab test IDs are saved and loaded', () async {
    final service = await _persistentService();

    await service.setEnabledLabTestIds(['creatinine', 'bun', 'tacrolimus']);
    final reloaded = await _persistentService();

    expect(reloaded.enabledLabTestIds, ['creatinine', 'bun', 'tacrolimus']);
  });

  test('persistent settings survive service recreation', () async {
    final service = await _persistentService();
    await service.setManagementType(LabManagementType.dialysis);
    await service.setEnabledLabTestIds(['ktv', 'urr']);
    final custom = await service.addCustomDefinition(
      displayName: 'Cyclosporine',
      defaultUnit: 'ng/mL',
    );

    final reloaded = await _persistentService();

    expect(reloaded.managementType, LabManagementType.dialysis);
    expect(reloaded.customDefinitions.single.displayName, 'Cyclosporine');
    expect(reloaded.customDefinitions.single.defaultUnit, 'ng/mL');
    expect(reloaded.customDefinitions.single.id, custom.id);
    expect(reloaded.enabledLabTestIds, ['ktv', 'urr', custom.id]);
  });

  test('inMemory service keeps settings without SharedPreferences', () async {
    final service = LabTestSettingsService.inMemory();
    await service.load();

    await service.setManagementType(LabManagementType.custom);
    final custom = await service.addCustomDefinition(
      displayName: 'Custom Marker',
    );
    await service.excludeLabTest(custom.id);

    expect(service.managementType, LabManagementType.custom);
    expect(service.customDefinitions.single.displayName, 'Custom Marker');
    expect(service.enabledLabTestIds, isEmpty);
  });

  test('custom lab test can be added', () async {
    final service = await _persistentService();

    final definition = await service.addCustomDefinition(
      displayName: 'C-Peptide',
    );

    expect(definition.id, startsWith('custom-'));
    expect(definition.displayName, 'C-Peptide');
    expect(service.customDefinitions, contains(definition));
    expect(service.enabledLabTestIds, contains(definition.id));
  });

  test('custom lab test unit is saved', () async {
    final service = await _persistentService();

    await service.addCustomDefinition(
      displayName: 'Sirolimus',
      defaultUnit: ' ng/mL ',
    );

    expect(service.customDefinitions.single.defaultUnit, 'ng/mL');
  });

  test('blank custom lab test unit is stored as null', () async {
    final service = await _persistentService();

    await service.addCustomDefinition(
      displayName: 'No Unit Test',
      defaultUnit: ' ',
    );

    expect(service.customDefinitions.single.defaultUnit, isNull);
  });

  test('blank custom lab test name is rejected', () async {
    final service = await _persistentService();

    expect(
      () => service.addCustomDefinition(displayName: '  '),
      throwsA(isA<EmptyCustomLabTestNameException>()),
    );
  });

  test('custom lab test cannot duplicate a predefined name', () async {
    final service = await _persistentService();

    expect(
      () => service.addCustomDefinition(displayName: 'Creatinine'),
      throwsA(isA<DuplicateLabTestDefinitionException>()),
    );
  });

  test('custom lab test duplicate check is case-insensitive', () async {
    final service = await _persistentService();

    expect(
      () => service.addCustomDefinition(displayName: 'creatinine'),
      throwsA(isA<DuplicateLabTestDefinitionException>()),
    );
  });

  test('custom lab test duplicate check trims whitespace', () async {
    final service = await _persistentService();

    expect(
      () => service.addCustomDefinition(displayName: ' Creatinine '),
      throwsA(isA<DuplicateLabTestDefinitionException>()),
    );
  });

  test('custom lab test cannot duplicate another custom name', () async {
    final service = await _persistentService();

    await service.addCustomDefinition(displayName: 'Everolimus');

    expect(
      () => service.addCustomDefinition(displayName: ' everolimus '),
      throwsA(isA<DuplicateLabTestDefinitionException>()),
    );
  });

  test('excluding a lab test removes only the enabled state', () async {
    final service = await _persistentService();
    final custom = await service.addCustomDefinition(displayName: 'CMV PCR');

    await service.excludeLabTest(custom.id);
    final reloaded = await _persistentService();

    expect(reloaded.enabledLabTestIds, isNot(contains(custom.id)));
    expect(reloaded.customDefinitions.single.id, custom.id);
  });

  test('user enabled list is not overwritten by preset on reload', () async {
    final service = await _persistentService();

    await service.setManagementType(LabManagementType.kidneyTransplant);
    await service.setEnabledLabTestIds(['creatinine', 'tacrolimus']);
    final reloaded = await _persistentService();

    expect(reloaded.managementType, LabManagementType.kidneyTransplant);
    expect(reloaded.enabledLabTestIds, ['creatinine', 'tacrolimus']);
  });

  test('invalid custom JSON falls back without crashing', () async {
    SharedPreferences.setMockInitialValues({
      LabTestSettingsService.customLabDefinitionsKey: '{',
      LabTestSettingsService.enabledLabTestIdsKey: ['creatinine'],
    });

    final service = await _persistentService();

    expect(service.customDefinitions, isEmpty);
    expect(service.enabledLabTestIds, ['creatinine']);
  });

  test('LabResult remains separate from lab test definitions', () {
    const definition = LabTestDefinition(
      id: 'sample',
      displayName: 'Sample Test',
      defaultUnit: 'mg/dL',
    );

    expect(definition.toJson().keys, ['id', 'displayName', 'defaultUnit']);
  });
}

Future<LabTestSettingsService> _persistentService() async {
  final service = LabTestSettingsService();
  await service.load();
  return service;
}
