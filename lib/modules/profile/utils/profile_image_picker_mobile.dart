import 'dart:io';
import 'package:image_picker/image_picker.dart';

Future<(List<int>?, String)> pickImage() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return (null, '');

  final bytes = await File(file.path).readAsBytes();
  return (bytes, file.name);
}
