import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'session_test_support.dart';

Uint8List evidencePng(int marker) =>
    Uint8List.fromList([...signaturePng(), marker]);
XFile evidenceFile(int marker) => XFile.fromData(
  evidencePng(marker),
  name: 'photo-$marker.png',
  mimeType: 'image/png',
);

class EvidenceTestPicker extends ImagePicker {
  XFile? camera;
  List<XFile> gallery = [];
  PlatformException? failure;
  Completer<XFile?>? cameraGate;
  int cameraCalls = 0;
  int galleryCalls = 0;
  int? requestedLimit;
  LostDataResponse lostData = LostDataResponse.empty();
  int lostReads = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    cameraCalls++;
    if (failure != null) throw failure!;
    return cameraGate != null ? cameraGate!.future : camera;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    galleryCalls++;
    requestedLimit = limit;
    if (failure != null) throw failure!;
    return gallery;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    lostReads++;
    return lostData;
  }
}
