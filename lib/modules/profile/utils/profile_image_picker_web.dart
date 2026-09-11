import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

const _maxProfilePhotoBytes = 5 * 1024 * 1024;

Future<(List<int>?, String)> pickImage() async {
  final completer = Completer<(List<int>?, String)>();
  final input = html.FileUploadInputElement()..accept = 'image/jpeg,image/png';
  input.click();

  input.onChange.listen((_) {
    final file = input.files?.first;
    if (file != null) {
      if (file.size > _maxProfilePhotoBytes) {
        completer.completeError(StateError('La foto no puede superar 5 MB.'));
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final dataUrl = reader.result as String;
        final base64Data = dataUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        completer.complete((bytes, file.name));
      });
    } else {
      completer.complete((null, ''));
    }
  });

  return completer.future;
}
