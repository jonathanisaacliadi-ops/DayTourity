import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

Future<Uint8List> _readFileBytes(html.File file) async {
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  final result = reader.result;
  if (result is ByteBuffer) {
    return result.asUint8List();
  } else if (result is Uint8List) {
    return result;
  } else {
    return _readFileBytesViaDataUrl(file);
  }
}
Future<Uint8List> _readFileBytesViaDataUrl(html.File file) async {
  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;
  final dataUrl = reader.result as String;
  final comma = dataUrl.indexOf(',');
  final b64 = dataUrl.substring(comma + 1);
  return base64Decode(b64);
}

Future<List<html.File>> _openFilePicker({bool multiple = false}) async {
  final completer = Completer<List<html.File>>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = multiple
    ..style.display = 'none';
  html.document.body!.append(input);

  input.onChange.listen((_) {
    final files = input.files ?? [];
    if (!completer.isCompleted) completer.complete(files.toList());
  });

  void onFocus(html.Event _) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete([]);
    });
  }

  html.window.addEventListener('focus', onFocus);
  input.click();

  final result = await completer.future;
  html.window.removeEventListener('focus', onFocus);
  input.remove();
  return result;
}

Future<XFile?> pickImage() async {
  final files = await _openFilePicker(multiple: false);
  if (files.isEmpty) return null;

  final file = files.first;
  final bytes = await _readFileBytes(file);
  return XFile.fromData(bytes, name: file.name, mimeType: file.type);
}

Future<List<XFile>> pickMultiImage() async {
  final files = await _openFilePicker(multiple: true);
  if (files.isEmpty) return [];

  final xfiles = <XFile>[];
  for (final file in files) {
    final bytes = await _readFileBytes(file);
    xfiles.add(XFile.fromData(bytes, name: file.name, mimeType: file.type));
  }
  return xfiles;
}
