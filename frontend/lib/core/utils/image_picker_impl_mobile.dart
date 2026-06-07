import 'package:image_picker/image_picker.dart';

final _picker = ImagePicker();

Future<XFile?> pickImage() => _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

Future<List<XFile>> pickMultiImage() => _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
