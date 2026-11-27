import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/signature_image.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import 'controllers/profile_controller.dart';
import 'signature_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.controller, this.imagePicker, super.key});
  final ProfileController controller;
  final ImagePicker? imagePicker;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _picker = widget.imagePicker ?? ImagePicker();
  late final _listenables = Listenable.merge([
    widget.controller,
    widget.controller.authentication,
  ]);
  bool _picking = false;
  ProfileController get _profile => widget.controller;
  bool get _busy =>
      _profile.saving || _profile.authentication.isSigningOut || _picking;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _profile.load();
    if (!mounted || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final ownerId = _profile.authentication.session?.technician.id;
      if (ownerId != null &&
          (await _profile.evidenceDrafts?.hasPendingPicker(ownerId) ?? false)) {
        return;
      }
      if (!mounted) return;
      final result = await _picker.retrieveLostData();
      if (result.exception != null) throw result.exception!;
      if (result.files?.isNotEmpty == true && mounted) {
        await _previewPhoto(result.files!.first);
      }
    } on MissingPluginException {
      // Gallery recovery is unavailable on some desktop/test platforms.
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'No fue posible recuperar la fotografía seleccionada',
        );
      }
    }
  }

  Future<bool> _save(SignatureImage image) async {
    final saved = await _profile.save(image);
    if (!saved && mounted) {
      AppSnackBar.error(
        context,
        _profile.saveError ?? 'No fue posible guardar la firma',
      );
    }
    return saved;
  }

  Future<void> _draw() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignatureDialog(onSave: _save),
    );
    if (saved == true && mounted) {
      AppSnackBar.success(context, 'Firma guardada correctamente');
    }
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file != null && mounted) await _previewPhoto(file);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'No fue posible abrir la galería o leer la imagen',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _previewPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    codec.dispose();
    if (!mounted) return;
    final image = SignatureImage(bytes: bytes, filename: file.name);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignaturePhotoDialog(image: image, onSave: _save),
    );
    if (saved == true && mounted) {
      AppSnackBar.success(context, 'Firma guardada correctamente');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _profile.authentication.logout();
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.profileBody)),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTheme.profileValue,
          ),
        ),
      ],
    ),
  );

  Widget _signatureCard() => Container(
    decoration: AppTheme.profileCard,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Mi firma', style: AppTheme.profileHeading),
        const SizedBox(height: 12),
        const Text(
          'Se pone sola como tu firma en los reportes que cierres, sin dibujarla cada vez.',
          style: AppTheme.profileBody,
        ),
        const SizedBox(height: 12),
        if (!_profile.technician.hasSignature)
          const Text(
            'Aún no registras tu firma: al cerrar un reporte se te pedirá dibujarla.',
            style: AppTheme.profileBody,
          )
        else if (_profile.signature != null)
          Container(
            height: 100,
            color: AppColors.white,
            child: Image.memory(
              _profile.signature!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text(
                  'No fue posible mostrar la firma',
                  style: AppTheme.profileBody,
                ),
              ),
            ),
          )
        else if (_profile.signatureError != null) ...[
          Text(_profile.signatureError!, style: AppTheme.profileBody),
          TextButton(
            onPressed: _busy ? null : _profile.loadSignature,
            child: const Text('Reintentar'),
          ),
        ] else
          const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: AppTheme.profilePrimaryButton,
          onPressed: _busy || _profile.loading ? null : _draw,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Dibujar mi firma'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: AppTheme.profileSecondaryButton,
          onPressed: _busy || _profile.loading ? null : _choosePhoto,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Elegir una foto de mi firma'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Foto: tu firma sobre papel blanco. El fondo se quita al guardar.',
          style: AppTheme.photoHelp,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _listenables,
        builder: (context, _) {
          final name = _profile.technician.name.trim();
          final initial = name.isEmpty
              ? '—'
              : name.characters.first.toUpperCase();
          final day = _profile.day;
          final completed = day?.visits
              .where((visit) => visit.status == 'completado')
              .length;
          return RefreshIndicator(
            onRefresh: _profile.load,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                initial,
                                style: AppTheme.avatarInitial,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name.isEmpty ? 'Sin nombre disponible' : name,
                            style: AppTheme.profileName,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.profileTag,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Técnico',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: AppTheme.profileCard,
                            child: Column(
                              children: [
                                _row(
                                  'Servicios de hoy',
                                  day == null
                                      ? 'Sin información'
                                      : '$completed / ${day.visits.length}',
                                ),
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                                _row(
                                  'Correo',
                                  _profile.technician.email
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? _profile.technician.email!
                                      : 'No disponible',
                                ),
                              ],
                            ),
                          ),
                          if (_profile.loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(),
                            ),
                          if (_profile.error != null ||
                              _profile.dayError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _profile.error ?? _profile.dayError!,
                              style: AppTheme.profileBody,
                            ),
                            TextButton(
                              onPressed: _busy ? null : _profile.load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _signatureCard(),
                          const SizedBox(height: 40),
                          const Spacer(),
                          OutlinedButton.icon(
                            style: AppTheme.logoutButton,
                            onPressed: _busy ? null : _logout,
                            icon: _profile.authentication.isSigningOut
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.error,
                                    ),
                                  )
                                : const Icon(Icons.logout),
                            label: Text(
                              _profile.authentication.isSigningOut
                                  ? 'Cerrando sesión…'
                                  : 'Cerrar sesión',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
