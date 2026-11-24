import 'dart:typed_data';

class SignatureImage {
  const SignatureImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}
