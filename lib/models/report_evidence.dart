import 'dart:convert';
import 'dart:typed_data';

/// Metadata returned by ReportContextRead.evidence, never a public Storage URL.
class ReportEvidence {
  const ReportEvidence({
    required this.id,
    required this.photoPath,
    this.stationCode,
  });
  final String id;
  final String photoPath;
  final String? stationCode;

  factory ReportEvidence.fromJson(Map<String, dynamic> json) => ReportEvidence(
    id: json['id'] as String,
    photoPath: json['photo_path'] as String,
    stationCode: json['station_code'] as String?,
  );
}

/// A private copy of a selected photo; independent of the picker's cache file.
class EvidencePhoto {
  const EvidencePhoto({
    required this.id,
    required this.bytes,
    required this.mimeType,
  });
  static const maxPhotos = 4;
  // Client-side limit: OpenAPI does not document a per-file byte limit.
  static const maxBytes = 5 * 1024 * 1024;
  final String id;
  final Uint8List bytes;
  final String mimeType;
  String get filename =>
      '$id.${switch (mimeType) {
        'image/jpeg' => 'jpg',
        'image/webp' => 'webp',
        _ => 'png',
      }}';

  static String? imageType(List<int> bytes) {
    if (bytes.length >= 8 &&
        [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ].asMap().entries.every((e) => bytes[e.key] == e.value)) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mime_type': mimeType,
    'bytes': base64Encode(bytes),
  };
  factory EvidencePhoto.fromJson(Map<String, dynamic> json) {
    final bytes = base64Decode(json['bytes'] as String);
    final mime = EvidencePhoto.imageType(bytes);
    final id = json['id'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        mime == null ||
        mime != json['mime_type'] ||
        bytes.length > maxBytes) {
      throw const FormatException('Invalid draft photo');
    }
    return EvidencePhoto(id: id, bytes: bytes, mimeType: mime);
  }
}

class EvidenceDraft {
  const EvidenceDraft({this.photos = const [], this.pickerPending = false});
  final List<EvidencePhoto> photos;
  final bool pickerPending;
}
