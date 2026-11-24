import 'dart:async';

import 'package:flutter/material.dart';

import '../models/signature_image.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/signature_pad.dart';

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({required this.onSave, super.key});
  final Future<bool> Function(SignatureImage) onSave;
  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final _pad = SignaturePadController();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || _pad.isEmpty) return;
    setState(() => _saving = true);
    try {
      final image = await _pad.export();
      if (!mounted) return;
      final saved = await widget.onSave(image);
      if (saved && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'No fue posible preparar la firma');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Dibujar mi firma', style: AppTheme.profileHeading),
              const SizedBox(height: 8),
              const Text(
                'Firma dentro del recuadro.',
                style: AppTheme.profileBody,
              ),
              const SizedBox(height: 16),
              SignaturePad(controller: _pad, enabled: !_saving),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _saving ? null : _pad.clear,
                icon: const Icon(Icons.refresh),
                label: const Text('Limpiar'),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _pad,
                builder: (context, _) => FilledButton(
                  style: AppTheme.profilePrimaryButton,
                  onPressed: _saving || _pad.isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SignaturePhotoDialog extends StatefulWidget {
  const SignaturePhotoDialog({
    required this.image,
    required this.onSave,
    super.key,
  });
  final SignatureImage image;
  final Future<bool> Function(SignatureImage) onSave;
  @override
  State<SignaturePhotoDialog> createState() => _SignaturePhotoDialogState();
}

class _SignaturePhotoDialogState extends State<SignaturePhotoDialog> {
  bool _saving = false;
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (await widget.onSave(widget.image) && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    unawaited(MemoryImage(widget.image.bytes).evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Foto de mi firma', style: AppTheme.profileHeading),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .28,
                child: ColoredBox(
                  color: AppColors.white,
                  child: Image.memory(widget.image.bytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El servidor quitará el fondo claro al guardar.',
                style: AppTheme.profileBody,
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: AppTheme.profilePrimaryButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Guardar'),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
