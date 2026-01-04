import 'dart:typed_data';
import 'file_utils_web.dart' if (dart.library.io) 'file_utils_mobile.dart';

class FileUtils {
  static Future<Uint8List> readBytes(String path) => readFileBytes(path);
}
