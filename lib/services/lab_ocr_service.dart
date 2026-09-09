import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/lab_capture_candidate.dart';

abstract class LabOcrService {
  Future<List<LabOcrDocument>> recognize(List<String> imagePaths);
}

class MlKitLabOcrService implements LabOcrService {
  MlKitLabOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.korean);

  final TextRecognizer _recognizer;

  @override
  Future<List<LabOcrDocument>> recognize(List<String> imagePaths) async {
    final documents = <LabOcrDocument>[];
    for (var index = 0; index < imagePaths.length; index += 1) {
      final path = imagePaths[index];
      final size = await _readImageSize(path);
      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      documents.add(
        LabOcrDocument(
          sourceImageIndex: index,
          imageWidth: size.width,
          imageHeight: size.height,
          lines: [
            for (final block in recognized.blocks)
              for (final line in block.lines)
                LabOcrLine(
                  text: line.text,
                  left: line.boundingBox.left,
                  top: line.boundingBox.top,
                  right: line.boundingBox.right,
                  bottom: line.boundingBox.bottom,
                  sourceImageIndex: index,
                  imageWidth: size.width,
                  imageHeight: size.height,
                ),
          ],
        ),
      );
    }
    return documents;
  }

  Future<void> close() async {
    await _recognizer.close();
  }

  Future<ui.Size> _readImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }
}

class LabCaptureException implements Exception {
  const LabCaptureException(this.message);

  final String message;
}

class AssetLabOcrService implements LabOcrService {
  const AssetLabOcrService(this.documents);

  final List<LabOcrDocument> documents;

  @override
  Future<List<LabOcrDocument>> recognize(List<String> imagePaths) async {
    return documents;
  }
}

class FailingLabOcrService implements LabOcrService {
  const FailingLabOcrService(this.message);

  final String message;

  @override
  Future<List<LabOcrDocument>> recognize(List<String> imagePaths) {
    throw LabCaptureException(message);
  }
}
