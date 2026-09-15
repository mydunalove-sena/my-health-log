import 'package:image_picker/image_picker.dart';

enum WeightImageSource { camera, gallery }

abstract class WeightImagePickerService {
  Future<String?> pickImage(WeightImageSource source);
}

class ImagePickerWeightImagePickerService implements WeightImagePickerService {
  ImagePickerWeightImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage(WeightImageSource source) async {
    final picked = await _picker.pickImage(
      source: switch (source) {
        WeightImageSource.camera => ImageSource.camera,
        WeightImageSource.gallery => ImageSource.gallery,
      },
    );
    return picked?.path;
  }
}

class FixedWeightImagePickerService implements WeightImagePickerService {
  const FixedWeightImagePickerService(this.paths);

  final Map<WeightImageSource, String?> paths;

  @override
  Future<String?> pickImage(WeightImageSource source) async => paths[source];
}
