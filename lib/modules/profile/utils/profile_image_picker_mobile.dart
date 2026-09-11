import 'dart:io';
import 'package:image_picker/image_picker.dart';

const _maxProfilePhotoBytes = 5 * 1024 * 1024;

Future<(List<int>?, String)> pickImage() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return (null, '');

  final localFile = File(file.path);
  if (await localFile.length() > _maxProfilePhotoBytes) {
    throw StateError('La foto no puede superar 5 MB.');
  }
  final bytes = await localFile.readAsBytes();
  return (bytes, file.name);
}
