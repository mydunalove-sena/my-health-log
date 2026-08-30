import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/screens/lab/lab_test_settings_screen.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'settings screen opens from lab screen and shows management types',
    (tester) async {
      final labService = await _labService();
      final settings = await _settings();

      await tester.pumpWidget(
        MaterialApp(
          home: LabScreen(
            service: labService,
            labTestSettingsService: settings,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('lab-settings-button')));
      await tester.pumpAndSettle();

      expect(find.text('검사 설정'), findsOneWidget);
      expect(find.text(settings.managementType.displayName), findsOneWidget);
      for (final type in LabManagementType.values) {
        expect(find.text(type.displayName), findsOneWidget);
        expect(
          find.byKey(Key('lab-management-type-${type.id}')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('management type change applies preset when confirmed', (
    tester,
  ) async {
    final settings = await _settings();
    await settings.setEnabledLabTestIds(['creatinine']);

    await _pumpSettings(tester, settings);
    await tester.tap(find.byKey(const Key('lab-management-type-dialysis')));
    await tester.pumpAndSettle();

    expect(find.text('관리 유형 변경'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('lab-management-change-cancel-button')),
    );
    await tester.pumpAndSettle();
    expect(settings.managementType, LabManagementType.generalHealth);
    expect(settings.enabledLabTestIds, ['creatinine']);

    await tester.tap(find.byKey(const Key('lab-management-type-dialysis')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('lab-management-change-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(settings.managementType, LabManagementType.dialysis);
    expect(
      settings.enabledLabTestIds,
      defaultLabTestIdsByManagementType[LabManagementType.dialysis],
    );
  });

  testWidgets('custom management type uses an empty preset', (tester) async {
    final settings = await _settings();

    await _pumpSettings(tester, settings);
    await tester.tap(find.byKey(const Key('lab-management-type-custom')));
    await tester.pumpAndSettle();

    expect(settings.managementType, LabManagementType.custom);
    expect(settings.enabledLabTestIds, isEmpty);
  });

  testWidgets('predefined definitions show units and null units safely', (
    tester,
  ) async {
    final settings = await _settings();

    await _pumpSettings(tester, settings);

    expect(find.text('Creatinine'), findsWidgets);
    expect(find.text('mg/dL'), findsWidgets);
    await _dragUntilFound(tester, find.text('Kt/V'));
    expect(find.text('Kt/V'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets(
    'definition checkbox changes persist after reopening and reload',
    (tester) async {
      final settings = await _settings();

      await _pumpSettings(tester, settings);
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('lab-definition-checkbox-creatinine')),
      );
      await tester.pumpAndSettle();
      expect(settings.enabledLabTestIds, isNot(contains('creatinine')));

      await tester.tap(
        find.byKey(const Key('lab-definition-checkbox-creatinine')),
      );
      await tester.pumpAndSettle();
      expect(settings.enabledLabTestIds, contains('creatinine'));

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpSettings(tester, settings);
      expect(settings.enabledLabTestIds, contains('creatinine'));

      final reloaded = await _settings();
      expect(reloaded.enabledLabTestIds, contains('creatinine'));
    },
  );

  testWidgets('custom definition can be added and is immediately enabled', (
    tester,
  ) async {
    final settings = await _settings();

    await _pumpSettings(tester, settings);
    await tester.tap(find.byKey(const Key('lab-settings-add-custom-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lab-custom-name-field')),
      ' CRP ',
    );
    await tester.enterText(
      find.byKey(const Key('lab-custom-unit-field')),
      ' mg/L ',
    );
    await tester.tap(find.byKey(const Key('lab-custom-save-button')));
    await tester.pumpAndSettle();

    final custom = settings.customDefinitions.single;
    expect(custom.displayName, 'CRP');
    expect(custom.defaultUnit, 'mg/L');
    expect(settings.enabledLabTestIds, contains(custom.id));
    expect(find.text('CRP'), findsOneWidget);
    expect(find.text('mg/L'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpSettings(tester, settings);
    expect(find.text('CRP'), findsOneWidget);
  });

  testWidgets('blank custom unit is stored as null', (tester) async {
    final settings = await _settings();

    await _pumpSettings(tester, settings);
    await tester.tap(find.byKey(const Key('lab-settings-add-custom-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lab-custom-name-field')),
      'No Unit Test',
    );
    await tester.enterText(find.byKey(const Key('lab-custom-unit-field')), ' ');
    await tester.tap(find.byKey(const Key('lab-custom-save-button')));
    await tester.pumpAndSettle();

    expect(settings.customDefinitions.single.defaultUnit, isNull);
    expect(
      settings.enabledLabTestIds,
      contains(settings.customDefinitions.single.id),
    );
  });

  testWidgets('custom definition validation blocks blank and duplicate names', (
    tester,
  ) async {
    final settings = await _settings();
    await settings.addCustomDefinition(displayName: 'Cyclosporine');

    await _pumpSettings(tester, settings);
    await _expectCustomError(tester, name: ' ', message: '검사 항목명을 입력해주세요.');
    await _expectCustomError(
      tester,
      name: 'Creatinine',
      message: '이미 등록된 검사 항목입니다.',
    );
    await _expectCustomError(
      tester,
      name: 'creatinine',
      message: '이미 등록된 검사 항목입니다.',
    );
    await _expectCustomError(
      tester,
      name: ' Creatinine ',
      message: '이미 등록된 검사 항목입니다.',
    );
    await _expectCustomError(
      tester,
      name: ' cyclosporine ',
      message: '이미 등록된 검사 항목입니다.',
    );
  });

  testWidgets('custom definition persists after service recreation', (
    tester,
  ) async {
    final settings = await _settings();

    await _pumpSettings(tester, settings);
    await tester.tap(find.byKey(const Key('lab-settings-add-custom-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lab-custom-name-field')),
      'Everolimus',
    );
    await tester.tap(find.byKey(const Key('lab-custom-save-button')));
    await tester.pumpAndSettle();

    final reloaded = await _settings();
    expect(reloaded.customDefinitions.single.displayName, 'Everolimus');
    expect(
      reloaded.enabledLabTestIds,
      contains(reloaded.customDefinitions.single.id),
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  LabTestSettingsService settings,
) async {
  await tester.pumpWidget(
    MaterialApp(home: LabTestSettingsScreen(service: settings)),
  );
  await tester.pumpAndSettle();
}

Future<LabTestSettingsService> _settings() async {
  final service = LabTestSettingsService();
  await service.load();
  return service;
}

Future<LabResultService> _labService() async {
  final service = LabResultService(InMemoryLabResultStorage());
  await service.load();
  return service;
}

Future<void> _dragUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 8 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

Future<void> _expectCustomError(
  WidgetTester tester, {
  required String name,
  required String message,
}) async {
  await tester.tap(find.byKey(const Key('lab-settings-add-custom-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('lab-custom-name-field')), name);
  await tester.tap(find.byKey(const Key('lab-custom-save-button')));
  await tester.pumpAndSettle();
  expect(find.text(message), findsOneWidget);
  await tester.tap(find.text('취소').last);
  await tester.pumpAndSettle();
}
