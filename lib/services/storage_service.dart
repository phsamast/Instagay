import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StorageService {
  static const String cloudName = 'df0e45ux4';
  static const String uploadPreset = 'flutter_upload';

  // Upload ảnh
  static Future<String?> uploadImage(File imageFile) async {
    return _upload(imageFile, 'image');
  }

  // Upload video
  static Future<String?> uploadVideo(File videoFile) async {
    return _upload(videoFile, 'video');
  }

  // Upload nhiều ảnh cùng lúc
  static Future<List<String>> uploadMultipleImages(List<File> files) async {
    final List<String> urls = [];
    for (final file in files) {
      final url = await uploadImage(file);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  static Future<String?> _upload(File file, String resourceType) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['resource_type'] = resourceType
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final data = json.decode(await response.stream.bytesToString());

      if (data['secure_url'] != null) {
        return data['secure_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}