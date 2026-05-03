import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StorageService {
  static const String cloudName = 'df0e45ux4';
  static const String uploadPreset = 'flutter_upload';

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final data = json.decode(await response.stream.bytesToString());
      return data['secure_url'];
    } catch (e) {
      return null;
    }
  }
}