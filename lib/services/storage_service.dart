import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class StorageService {
  static const String cloudName = 'df0e45ux4';
  static const String uploadPreset = 'flutter_upload';

  static Future<String?> uploadImage(
    File imageFile, {
    void Function(double progress)? onProgress,
  }) {
    return _upload(imageFile, 'image', onProgress: onProgress);
  }

  static Future<String?> uploadVideo(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) {
    return _upload(videoFile, 'video', onProgress: onProgress);
  }

  static Future<List<String>> uploadMultipleImages(
    List<File> files, {
    void Function(double progress)? onProgress,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final url = await uploadImage(
        files[i],
        onProgress: (fileProgress) {
          onProgress?.call((i + fileProgress) / files.length);
        },
      );
      if (url != null) urls.add(url);
    }
    return urls;
  }

  static Future<String?> _upload(
    File file,
    String resourceType, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );
      final length = await file.length();
      var uploaded = 0;
      final stream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            uploaded += data.length;
            if (length > 0) {
              onProgress?.call((uploaded / length).clamp(0, 1).toDouble());
            }
            sink.add(data);
          },
        ),
      );
      final filename = file.path.split(Platform.pathSeparator).last;

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['resource_type'] = resourceType
        ..files.add(
            http.MultipartFile('file', stream, length, filename: filename));

      final response = await request.send();
      final data = json.decode(await response.stream.bytesToString());

      if (data['secure_url'] != null) {
        onProgress?.call(1);
        return data['secure_url'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
