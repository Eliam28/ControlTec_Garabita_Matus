import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../api/services/day_snapshot_api.dart';
import '../../api/services/login_service.dart';
import '../../api/services/my_day_service.dart';
import '../../api/services/profile_api.dart';
import '../../api/services/profile_service.dart';
import '../../api/services/evidence_draft_store.dart';
import '../../base/custom_exception.dart';
import '../../models/field_day.dart';
import '../../models/signature_image.dart';
import '../../models/technician.dart';
import 'login_controller.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.authentication,
    required this.loginService,
    required this.profileService,
    required this.myDayService,
    required this.daySnapshot,
    this.evidenceDrafts,
  }) : technician = authentication.session!.technician {
    daySnapshot.snapshot.addListener(_dayChanged);
  }

  final LoginController authentication;
  final LoginService loginService;
  final ProfileService profileService;
  final MyDayService myDayService;
  final DaySnapshotApi daySnapshot;
  final EvidenceDraftStore? evidenceDrafts;
  Technician technician;
  FieldDay? day;
  Uint8List? signature;
  String? error;
  String? dayError;
  String? signatureError;
  String? saveError;
  bool loading = false;
  bool saving = false;
  bool _disposed = false;
  int _operation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _dayChanged() {
    day = daySnapshot.current;
    _notify();
  }

  Future<void> load() async {
    if (loading || saving || _disposed) return;
    final operation = ++_operation;
    loading = true;
    error = null;
    dayError = null;
    _notify();
    final dayLoad = _loadDay(operation);
    try {
      final restored = await loginService.restoreSession();
      if (_disposed || operation != _operation || restored == null) return;
      technician = restored.technician;
      authentication.updateTechnician(technician);
      if (technician.hasSignature) {
        await loadSignature();
      } else {
        _replaceSignature(null);
        signatureError = null;
      }
    } catch (_) {
      if (!_disposed && operation == _operation) {
        error = 'No fue posible actualizar tu perfil';
      }
    } finally {
      await dayLoad;
      if (!_disposed && operation == _operation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _loadDay(int operation) async {
    try {
      final result = await daySnapshot.forProfile(myDayService);
      if (!_disposed && operation == _operation) day = result;
    } catch (_) {
      if (!_disposed && operation == _operation) {
        dayError = 'No fue posible consultar tus servicios';
      }
    }
  }

  Future<void> loadSignature() async {
    try {
      final image = await profileService.signature();
      if (_disposed) return;
      _replaceSignature(image);
      signatureError = null;
    } catch (_) {
      if (!_disposed) signatureError = ProfileApi.previewError;
    }
    _notify();
  }

  Future<bool> save(SignatureImage image) async {
    if (saving || loading || _disposed) return false;
    saving = true;
    saveError = null;
    _notify();
    try {
      final updated = await profileService.execute(image);
      if (_disposed) return false;
      technician = updated;
      authentication.updateTechnician(updated);
      _replaceSignature(null);
      await loadSignature();
      return !_disposed;
    } on CustomException catch (exception) {
      saveError = exception.message;
      return false;
    } catch (_) {
      saveError = ProfileApi.saveError;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _replaceSignature(Uint8List? value) {
    final previous = signature;
    signature = value;
    if (previous != null) unawaited(MemoryImage(previous).evict());
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    daySnapshot.snapshot.removeListener(_dayChanged);
    _replaceSignature(null);
    day = null;
    super.dispose();
  }
}
