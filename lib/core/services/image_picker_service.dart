import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickImagePath({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
    );

    return image?.path;
  }
}
