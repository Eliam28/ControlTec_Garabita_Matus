import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/services/evidence_draft_store.dart';
import '../../api/services/report_evidence_service.dart';
import '../../api/services/report_service.dart';
import '../../base/custom_exception.dart';
import '../../models/report_context.dart';
import '../../models/report_evidence.dart';

class ReportEvidenceController extends ChangeNotifier {
  ReportEvidenceController({
    required this.visitId,
    required this.service,
    ImagePicker? picker,
    EvidenceDraftStore? drafts,
  }) : picker = picker ?? ImagePicker(),
       drafts = drafts ?? service.evidenceDrafts ?? MemoryEvidenceDraftStore() {
    _revision = this.drafts.revision;
  }
  final String visitId;
  final ReportService service;
  final ImagePicker picker;
  final EvidenceDraftStore drafts;
  late final int _revision;
  String? _ownerId;
  String? reportId;
  int imageRevision = 0;
  List<ReportEvidence> stationPhotos = const [];
  List<ReportEvidence> savedPhotos = const [];
  List<EvidencePhoto> photos = const [];
  String? error;
  bool ready = false;
  bool loading = false;
  bool picking = false;
  bool saving = false;
  bool submitting = false;
  bool closed = false;
  bool _disposed = false;
  Future<void>? _initialization;
  final Map<String, Future<Uint8List>> _downloads = {};
  final List<Uint8List> _downloaded = [];

  bool get busy => loading || picking || saving || submitting;
  bool get navigationLocked => picking || saving || submitting;
  int get additionalCount => savedPhotos.length + photos.length;
  int get remaining => max(0, EvidencePhoto.maxPhotos - additionalCount);
  String? get completionKey => _ownerId == null ? null : visitId;
  bool get _active => !_disposed && _revision == drafts.revision;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void acceptContext(ReportContext context) {
    if (!_active || context.visitId != visitId) return;
    reportId = context.reportId;
    closed = ['completado', 'cancelado'].contains(context.visitStatus);
    if (closed && ready && _ownerId != null) unawaited(completed());
    final stations = <String, ReportEvidence>{};
    String key(String path) {
      try {
        return ReportEvidenceService.filename(path);
      } catch (_) {
        return path;
      }
    }

    for (final photo in context.evidence) {
      if (photo.stationCode?.trim().isNotEmpty == true) {
        stations[key(photo.photoPath)] = photo;
      }
    }
    for (final station in context.stations) {
      final path = station.photoPath;
      if (path?.trim().isNotEmpty == true) {
        stations[key(path!)] = ReportEvidence(
          id: station.id,
          photoPath: path,
          stationCode: station.code,
        );
      }
    }
    stationPhotos = List.unmodifiable(stations.values);
    final additional = <String, ReportEvidence>{};
    for (final photo in context.evidence) {
      if (!stations.containsKey(key(photo.photoPath))) {
        additional[key(photo.photoPath)] = photo;
      }
    }
    savedPhotos = List.unmodifiable(additional.values);
    _clearDownloads();
    imageRevision++;
    _notify();
  }

  Future<void> initialize() => _initialization ??= _initialize().whenComplete(
    () => _initialization = null,
  );
  Future<void> _initialize() async {
    if (ready || !_active) return;
    // A tab can initialize while its parent's PageView is being laid out.
    await Future<void>.value();
    if (!_active) return;
    loading = true;
    error = null;
    _notify();
    try {
      final owner = await service.profile();
      if (!_active) return;
      _ownerId = owner.id;
      if (_ownerId == null) throw const FormatException();
      final draft = await drafts.load(_ownerId!, visitId, _revision);
      for (final photo in draft.photos) {
        await validateImage(photo.bytes);
      }
      if (!_active) return;
      photos = closed ? const [] : List.unmodifiable(draft.photos);
      if (closed) await drafts.remove(_ownerId!, visitId, _revision);
      ready = true;
      if (!closed &&
          draft.pickerPending &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final lost = await picker.retrieveLostData();
        if (lost.exception != null) throw lost.exception!;
        if (lost.files?.isNotEmpty == true) await _accept(lost.files!);
        await drafts.save(_ownerId!, visitId, photos, _revision);
      }
    } catch (_) {
      if (_active) error = 'No fue posible recuperar las fotografías pendientes. Reintenta antes de continuar';
      ready = false;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (busy || !_active) return;
    if (!ready) {
      await initialize();
      return;
    }
    loading = true;
    _notify();
    try {
      acceptContext(await service.load(visitId));
      error = null;
    } catch (_) {
      error = 'No fue posible actualizar las fotografías del servicio';
    } finally {
      loading = false;
      _notify();
    }
  }

  static Future<void> validateImage(
    Uint8List bytes, {
    int maxBytes = EvidencePhoto.maxBytes,
  }) async {
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        EvidencePhoto.imageType(bytes) == null) {
      throw const CustomException(
        message: 'Elige una imagen JPG, PNG o WebP válida de hasta 5 MB',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 20000000) {
        throw const FormatException();
      }
      final codec = await descriptor.instantiateCodec();
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const CustomException(
        message: 'La fotografía está dañada o no puede leerse',
      );
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> pick({required bool camera}) async {
    if (busy || !ready || closed || !_active) return;
    if (remaining == 0) {
      throw const CustomException(
        message: 'Puedes agregar hasta 4 fotografías adicionales',
      );
    }
    picking = true;
    error = null;
    _notify();
    try {
      await drafts.save(
        _ownerId!,
        visitId,
        photos,
        _revision,
        pickerPending: true,
      );
      final files = camera
          ? [
              await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 85,
                requestFullMetadata: false,
              ),
            ].whereType<XFile>().toList()
          : await picker.pickMultiImage(
              limit: remaining,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85,
              requestFullMetadata: false,
            );
      if (_active) await _accept(files);
    } on PlatformException catch (exception) {
      throw CustomException(
        message:
            exception.code.contains('denied') ||
                exception.code.contains('restricted')
            ? 'Permite el acceso a la cámara o a las fotografías desde los ajustes del dispositivo'
            : 'No fue posible abrir la cámara o la galería',
      );
    } on CustomException {
      rethrow;
    } catch (_) {
      throw const CustomException(
        message: 'No fue posible conservar las fotografías. Intenta nuevamente',
      );
    } finally {
      if (_active) {
        try {
          await drafts.save(_ownerId!, visitId, photos, _revision);
        } catch (_) {
          error = 'No fue posible actualizar el borrador de fotografías';
        }
      }
      picking = false;
      _notify();
    }
  }

  Future<void> _accept(List<XFile> files) async {
    if (files.length > remaining) {
      throw const CustomException(
        message: 'La selección supera el máximo de 4 fotografías adicionales',
      );
    }
    final selected = <EvidencePhoto>[];
    for (final file in files) {
      if (await file.length() > EvidencePhoto.maxBytes) {
        throw const CustomException(
          message: 'Cada fotografía debe ocupar hasta 5 MB',
        );
      }
      final bytes = await file.readAsBytes();
      await validateImage(bytes);
      if ([
        ...photos,
        ...selected,
      ].any((photo) => listEquals(photo.bytes, bytes))) {
        continue;
      }
      selected.add(
        EvidencePhoto(
          id: 'photo-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
          bytes: bytes,
          mimeType: EvidencePhoto.imageType(bytes)!,
        ),
      );
    }
    if (!_active || selected.isEmpty) return;
    final next = List<EvidencePhoto>.unmodifiable([...photos, ...selected]);
    await drafts.save(_ownerId!, visitId, next, _revision);
    if (_active) {
      photos = next;
      _notify();
    }
  }

  Future<void> remove(EvidencePhoto photo) async {
    if (busy || !ready || closed || !_active) return;
    saving = true;
    _notify();
    try {
      final next = photos.where((p) => p.id != photo.id).toList();
      await drafts.save(_ownerId!, visitId, next, _revision);
      if (_active) {
        photos = List.unmodifiable(next);
        unawaited(MemoryImage(photo.bytes).evict());
      }
    } catch (_) {
      throw const CustomException(
        message: 'No fue posible quitar la fotografía del borrador',
      );
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<Uint8List> image(ReportEvidence photo, {bool retry = false}) {
    final key = '${reportId ?? ''}/${photo.photoPath}';
    if (retry) _downloads.remove(key);
    return _downloads.putIfAbsent(key, () async {
      final bytes = await ReportEvidenceService(service)
          .execute((reportId: reportId ?? '', photoPath: photo.photoPath));
      await validateImage(
        bytes,
        maxBytes: ReportEvidenceService.maxDownloadBytes,
      );
      if (_active) _downloaded.add(bytes);
      return bytes;
    });
  }

  bool beginCompletion() {
    if (!_active ||
        !ready ||
        closed ||
        busy ||
        additionalCount > EvidencePhoto.maxPhotos) {
      return false;
    }
    submitting = true;
    _notify();
    return true;
  }

  void endCompletion() {
    submitting = false;
    _notify();
  }

  Future<void> completed() async {
    closed = true;
    final previous = photos;
    photos = const [];
    for (final photo in previous) {
      unawaited(MemoryImage(photo.bytes).evict());
    }
    try {
      if (_ownerId != null) await drafts.remove(_ownerId!, visitId, _revision);
    } catch (_) {
      /* Server confirmation remains authoritative. */
    }
    _notify();
  }

  void _clearDownloads() {
    _downloads.clear();
    for (final bytes in _downloaded) {
      unawaited(MemoryImage(bytes).evict());
    }
    _downloaded.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final photo in photos) {
      unawaited(MemoryImage(photo.bytes).evict());
    }
    photos = const [];
    _clearDownloads();
    super.dispose();
  }
}
