import 'package:image_picker/image_picker.dart';

abstract class LabImagePickerService {
  Future<List<String>> pickImages();
}

class ImagePickerLabImagePickerService implements LabImagePickerService {
  ImagePickerLabImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<String>> pickImages() async {
    final images = await _picker.pickMultiImage();
    return [for (final image in images) image.path];
  }
}

class FixedLabImagePickerService implements LabImagePickerService {
  const FixedLabImagePickerService(this.paths);

  final List<String> paths;

  @override
  Future<List<String>> pickImages() async => paths;
}
