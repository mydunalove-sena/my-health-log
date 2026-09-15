import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/screens/health/weight_capture_review_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_ocr_service.dart';
import 'package:my_health_log/services/weight_capture_orchestrator.dart';
import 'package:my_health_log/services/weight_capture_parser_service.dart';
import 'package:my_health_log/services/weight_image_picker_service.dart';

void main() {
  group('WeightCaptureOrchestrator final production path', () {
    test('InBody 50.3 uses one OCR pass and returns candidate', () async {
      final ocr = FakeLabOcrService([_inBody503Document()]);
      const orchestrator = WeightCaptureOrchestrator();

      final result = await orchestrator.capture(
        imagePath: 'inbody.jpg',
        ocrService: ocr,
      );

      expect(ocr.callCount, 1);
      expect(ocr.paths.single, 'inbody.jpg');
      expect(result.firstOcrCallCount, 1);
      expect(result.branch, WeightCaptureProductionBranch.inBody);
      expect(result.candidate, isNotNull);
      expect(result.candidate!.value, 50.3);
      expect(result.candidate!.warning.name, 'none');
    });

    test('non-InBody OCR goes to manual review without LCD auto', () async {
      final ocr = FakeLabOcrService([_lcdTextDocument('51.9kg')]);
      const orchestrator = WeightCaptureOrchestrator();

      final result = await orchestrator.capture(
        imagePath: 'lcd.jpg',
        ocrService: ocr,
      );

      expect(ocr.callCount, 1);
      expect(result.firstOcrCallCount, 1);
      expect(result.branch, WeightCaptureProductionBranch.manualReview);
      expect(result.candidate, isNull);
    });

    test('candidate null goes to manual review', () async {
      final ocr = FakeLabOcrService([_emptyDocument()]);
      const orchestrator = WeightCaptureOrchestrator();

      final result = await orchestrator.capture(
        imagePath: 'unknown.jpg',
        ocrService: ocr,
      );

      expect(ocr.callCount, 1);
      expect(result.branch, WeightCaptureProductionBranch.manualReview);
      expect(result.candidate, isNull);
    });
  });

  group('WeightCaptureParserService final routing', () {
    test('routes real InBody label-unit OCR to InBody parser', () {
      final candidate = const WeightCaptureParserService().parse([
        _inBody503Document(),
      ]);

      expect(candidate, isNotNull);
      expect(candidate!.value, 50.3);
    });

    test('does not parse label-less LCD text as automatic weight', () {
      final candidate = const WeightCaptureParserService().parse([
        _lcdTextDocument('51.9kg'),
      ]);

      expect(candidate, isNull);
    });
  });

  group('WeightCaptureReviewScreen final safety', () {
    testWidgets('opening review does not write before explicit save', (
      tester,
    ) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );

      expect(storage.writeCount, 0);
      expect(
        find.byKey(const Key('weight-capture-value-field')),
        findsOneWidget,
      );
    });

    testWidgets('cancel leaves HealthRecordService unchanged', (tester) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('weight-capture-cancel-button')));
      await tester.pumpAndSettle();

      expect(storage.writeCount, 0);
      expect(service.records, isEmpty);
    });

    testWidgets('manual review save writes only after confirmation', (
      tester,
    ) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('weight-capture-value-field')),
        '50.3',
      );
      await _tapVisible(tester, const Key('weight-capture-save-button'));
      await tester.pumpAndSettle();

      expect(storage.writeCount, 1);
      expect(service.records.single.weight, 50.3);
    });

    testWidgets('same-date save preserves existing non-weight fields', (
      tester,
    ) async {
      final existing = HealthRecord(
        id: 'existing',
        date: DateTime(2026, 9, 15),
        weight: 49.8,
        systolicBloodPressure: 121,
        diastolicBloodPressure: 79,
        waterIntake: 1500,
        steps: 6400,
        sleepHours: 6.5,
        condition: HealthCondition.normal,
        createdAt: DateTime(2026, 9, 15, 7),
        updatedAt: DateTime(2026, 9, 15, 8),
      );
      final storage = CountingHealthRecordStorage([existing]);
      final service = HealthRecordService(storage);
      await service.load();

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('weight-capture-value-field')),
        '50.3',
      );
      await _tapVisible(tester, const Key('weight-capture-save-button'));
      await tester.pumpAndSettle();

      final saved = service.records.single;
      expect(storage.insertCount, 0);
      expect(storage.updateCount, 1);
      expect(saved.id, existing.id);
      expect(saved.createdAt, existing.createdAt);
      expect(saved.weight, 50.3);
      expect(saved.systolicBloodPressure, 121);
      expect(saved.diastolicBloodPressure, 79);
      expect(saved.waterIntake, 1500);
      expect(saved.steps, 6400);
      expect(saved.sleepHours, 6.5);
      expect(saved.condition, HealthCondition.normal);
    });

    testWidgets('new-date save creates one weight-only record', (tester) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await tester.pumpWidget(
        MaterialApp(
          home: WeightCaptureReviewScreen(
            service: service,
            candidate: null,
            initialDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('weight-capture-value-field')),
        '51.0',
      );
      await _tapVisible(tester, const Key('weight-capture-save-button'));
      await tester.pumpAndSettle();

      expect(storage.insertCount, 1);
      expect(service.records.single.weight, 51.0);
      expect(service.records.single.systolicBloodPressure, isNull);
      expect(service.records.single.diastolicBloodPressure, isNull);
      expect(service.records.single.waterIntake, isNull);
      expect(service.records.single.steps, isNull);
      expect(service.records.single.sleepHours, isNull);
      expect(service.records.single.condition, isNull);
    });
  });

  group('HealthFormScreen weight capture final integration', () {
    testWidgets(
      'gallery InBody flow reaches review without pre-save DB write',
      (tester) async {
        final storage = CountingHealthRecordStorage();
        final service = HealthRecordService(storage);
        await service.load();

        await _pumpHealthForm(
          tester,
          service: service,
          picker: const FixedWeightImagePickerService({
            WeightImageSource.gallery: 'gallery.jpg',
          }),
          ocr: FakeLabOcrService([_inBody503Document()]),
        );

        await _openWeightSource(
          tester,
          const Key('weight-capture-gallery-button'),
        );

        expect(storage.writeCount, 0);
        final field = tester.widget<TextFormField>(
          find.byKey(const Key('weight-capture-value-field')),
        );
        expect(field.controller!.text, '50.3');
      },
    );

    testWidgets('camera non-InBody flow opens blank manual review', (
      tester,
    ) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await _pumpHealthForm(
        tester,
        service: service,
        picker: const FixedWeightImagePickerService({
          WeightImageSource.camera: 'camera.jpg',
        }),
        ocr: FakeLabOcrService([_lcdTextDocument('51.9kg')]),
      );

      await _openWeightSource(
        tester,
        const Key('weight-capture-camera-button'),
      );

      expect(storage.writeCount, 0);
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('weight-capture-value-field')),
      );
      expect(field.controller!.text, '');
    });

    testWidgets('capture save exits form and stores merged weight', (
      tester,
    ) async {
      final existing = HealthRecord(
        id: 'same-day',
        date: DateTime(2026, 9, 15),
        systolicBloodPressure: 118,
        diastolicBloodPressure: 76,
        waterIntake: 1700,
        steps: 7200,
        sleepHours: 7,
        condition: HealthCondition.good,
        createdAt: DateTime(2026, 9, 15, 6),
        updatedAt: DateTime(2026, 9, 15, 7),
      );
      final storage = CountingHealthRecordStorage([existing]);
      final service = HealthRecordService(storage);
      await service.load();

      await _pumpHealthForm(
        tester,
        service: service,
        picker: const FixedWeightImagePickerService({
          WeightImageSource.gallery: 'gallery.jpg',
        }),
        ocr: FakeLabOcrService([_inBody503Document()]),
      );

      await _openWeightSource(
        tester,
        const Key('weight-capture-gallery-button'),
      );
      await _tapVisible(tester, const Key('weight-capture-save-button'));
      await tester.pumpAndSettle();

      final saved = service.records.single;
      expect(saved.id, 'same-day');
      expect(saved.weight, 50.3);
      expect(saved.systolicBloodPressure, 118);
      expect(saved.diastolicBloodPressure, 76);
      expect(saved.waterIntake, 1700);
      expect(saved.steps, 7200);
      expect(saved.sleepHours, 7);
      expect(saved.condition, HealthCondition.good);
    });

    testWidgets('direct health input still saves weight and blood pressure', (
      tester,
    ) async {
      final storage = CountingHealthRecordStorage();
      final service = HealthRecordService(storage);
      await service.load();

      await _pumpHealthForm(tester, service: service);
      await tester.enterText(
        find.byKey(const Key('health-weight-field')),
        '52',
      );
      await tester.enterText(
        find.byKey(const Key('health-systolic-field')),
        '120',
      );
      await tester.enterText(
        find.byKey(const Key('health-diastolic-field')),
        '80',
      );
      await _tapVisible(tester, const Key('health-save-button'));
      await tester.pumpAndSettle();

      expect(storage.insertCount, 1);
      expect(service.records.single.weight, 52);
      expect(service.records.single.systolicBloodPressure, 120);
      expect(service.records.single.diastolicBloodPressure, 80);
    });
  });
}

Future<void> _pumpHealthForm(
  WidgetTester tester, {
  required HealthRecordService service,
  WeightImagePickerService? picker,
  LabOcrService? ocr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HealthFormScreen(
        service: service,
        weightImagePickerService: picker,
        weightOcrService: ocr,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openWeightSource(WidgetTester tester, Key sourceKey) async {
  await tester.tap(find.byKey(const Key('health-weight-photo-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(sourceKey));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

LabOcrDocument _inBody503Document() {
  return const LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 1080,
    imageHeight: 2400,
    lines: [
      LabOcrLine(
        text: '\uCCB4\uC911 (kg)',
        left: 80,
        top: 510,
        right: 280,
        bottom: 560,
        sourceImageIndex: 0,
        imageWidth: 1080,
        imageHeight: 2400,
      ),
      LabOcrLine(
        text: '50.3',
        left: 315,
        top: 512,
        right: 445,
        bottom: 560,
        sourceImageIndex: 0,
        imageWidth: 1080,
        imageHeight: 2400,
      ),
    ],
  );
}

LabOcrDocument _lcdTextDocument(String text) {
  return LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 1080,
    imageHeight: 2400,
    lines: [
      LabOcrLine(
        text: text,
        left: 420,
        top: 1200,
        right: 650,
        bottom: 1310,
        sourceImageIndex: 0,
        imageWidth: 1080,
        imageHeight: 2400,
      ),
    ],
  );
}

LabOcrDocument _emptyDocument() {
  return const LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 1080,
    imageHeight: 2400,
    lines: [],
  );
}

class FakeLabOcrService implements LabOcrService {
  FakeLabOcrService(this.documents);

  final List<LabOcrDocument> documents;
  final paths = <String>[];
  int callCount = 0;

  @override
  Future<List<LabOcrDocument>> recognize(List<String> imagePaths) async {
    callCount += 1;
    paths.addAll(imagePaths);
    return documents;
  }
}

class CountingHealthRecordStorage extends InMemoryHealthRecordStorage {
  CountingHealthRecordStorage([super.records]);

  int insertCount = 0;
  int updateCount = 0;
  int deleteCount = 0;

  int get writeCount => insertCount + updateCount + deleteCount;

  @override
  Future<void> insert(HealthRecord record) async {
    insertCount += 1;
    await super.insert(record);
  }

  @override
  Future<void> update(HealthRecord record) async {
    updateCount += 1;
    await super.update(record);
  }

  @override
  Future<void> delete(String id) async {
    deleteCount += 1;
    await super.delete(id);
  }
}
