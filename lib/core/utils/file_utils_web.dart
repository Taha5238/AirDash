import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) async {
  throw Exception("Cannot read local file path on Web. Use content bytes.");
}
