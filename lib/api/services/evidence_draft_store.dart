import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../base/custom_exception.dart';
import '../../models/report_evidence.dart';

/// Local draft only. Uploading is exclusively the existing report completion.
abstract class EvidenceDraftStore {
  int get revision;
  Future<EvidenceDraft> load(String ownerId, String visitId, int revision);
  Future<void> save(
    String ownerId,
    String visitId,
    List<EvidencePhoto> photos,
    int revision, {
    bool pickerPending = false,
  });
  Future<void> remove(String ownerId, String visitId, int revision);
  Future<void> clearAll();
  Future<bool> hasPendingPicker(String ownerId);
}

class FileEvidenceDraftStore implements EvidenceDraftStore {
  FileEvidenceDraftStore({Future<Directory> Function()? directory})
    : _directory =
          directory ??
          (() async => Directory(
            '${(await getApplicationSupportDirectory()).path}/evidence_drafts',
          ));
  final Future<Directory> Function() _directory;
  Future<void> _queue = Future.value();
  int _revision = 0;
  @override
  int get revision => _revision;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _check(int expected) {
    if (expected != _revision) {
      throw const CustomException(
        message: 'La sesión ha cambiado',
        code: 'stale_session',
      );
    }
  }

  Future<File> _file(String ownerId, String visitId) async {
    if (![
      ownerId,
      visitId,
    ].every((id) => RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id))) {
      throw const FormatException('Invalid draft identity');
    }
    return File('${(await _directory()).path}/$ownerId/$visitId.json');
  }

  @override
  Future<EvidenceDraft> load(String ownerId, String visitId, int revision) =>
      _serial(() async {
        _check(revision);
        final file = await _file(ownerId, visitId);
        if (!await file.exists()) return const EvidenceDraft();
        if (await file.length() >
            EvidencePhoto.maxBytes * EvidencePhoto.maxPhotos * 2) {
          throw const FormatException('Invalid draft size');
        }
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Invalid draft version');
        }
        final photos = (data['photos'] as List)
            .map((p) => EvidencePhoto.fromJson(p as Map<String, dynamic>))
            .toList();
        if (photos.length > EvidencePhoto.maxPhotos) {
          throw const FormatException('Invalid photo count');
        }
        _check(revision);
        return EvidenceDraft(
          photos: photos,
          pickerPending: data['picker_pending'] == true,
        );
      });

  @override
  Future<void> save(
    String ownerId,
    String visitId,
    List<EvidencePhoto> photos,
    int revision, {
    bool pickerPending = false,
  }) => _serial(() async {
    _check(revision);
    if (photos.length > EvidencePhoto.maxPhotos ||
        photos.any(
          (p) => p.bytes.isEmpty || p.bytes.length > EvidencePhoto.maxBytes,
        )) {
      throw const FormatException('Invalid photos');
    }
    final file = await _file(ownerId, visitId);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'version': 1,
        'picker_pending': pickerPending,
        'photos': photos.map((p) => p.toJson()).toList(),
      }),
      flush: true,
    );
    _check(revision);
    await temp.rename(file.path);
  });

  @override
  Future<void> remove(String ownerId, String visitId, int revision) =>
      _serial(() async {
        _check(revision);
        final file = await _file(ownerId, visitId);
        if (await file.exists()) await file.delete();
      });

  @override
  Future<void> clearAll() {
    _revision++;
    return _serial(() async {
      final directory = await _directory();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
  }

  @override
  Future<bool> hasPendingPicker(String ownerId) => _serial(() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(ownerId)) return false;
    final owner = Directory('${(await _directory()).path}/$ownerId');
    if (!await owner.exists()) return false;
    await for (final entry in owner.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final length = await entry.length();
      // The marker precedes the photo data; avoid decoding entire draft images.
      final header = await entry
          .openRead(0, length < 128 ? length : 128)
          .transform(utf8.decoder)
          .join();
      if (header.contains('"picker_pending":true')) return true;
    }
    return false;
  });
}

class MemoryEvidenceDraftStore implements EvidenceDraftStore {
  final Map<String, EvidenceDraft> _drafts = {};
  int _revision = 0;
  @override
  int get revision => _revision;
  void _check(int revision) {
    if (revision != _revision) {
      throw const CustomException(
        message: 'La sesión ha cambiado',
        code: 'stale_session',
      );
    }
  }

  @override
  Future<EvidenceDraft> load(
    String ownerId,
    String visitId,
    int revision,
  ) async {
    _check(revision);
    return _drafts['$ownerId/$visitId'] ?? const EvidenceDraft();
  }

  @override
  Future<void> save(
    String ownerId,
    String visitId,
    List<EvidencePhoto> photos,
    int revision, {
    bool pickerPending = false,
  }) async {
    _check(revision);
    _drafts['$ownerId/$visitId'] = EvidenceDraft(
      photos: List.unmodifiable(photos),
      pickerPending: pickerPending,
    );
  }

  @override
  Future<void> remove(String ownerId, String visitId, int revision) async {
    _check(revision);
    _drafts.remove('$ownerId/$visitId');
  }

  @override
  Future<void> clearAll() async {
    _revision++;
    _drafts.clear();
  }

  @override
  Future<bool> hasPendingPicker(String ownerId) async => _drafts.entries.any(
    (entry) => entry.key.startsWith('$ownerId/') && entry.value.pickerPending,
  );
}
