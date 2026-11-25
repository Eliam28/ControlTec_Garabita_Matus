import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/services/report_service.dart';
import '../base/custom_exception.dart';
import '../models/report_context.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/field_label.dart';
import 'signature_screen.dart';

/// Pestaña 2 del reporte: quién recibe, importe, recomendaciones y las dos
/// firmas. «Terminar servicio» cierra el reporte y avisa con [onCompleted]
/// el estado de pago que devolvió la API.
class SignoffTab extends StatefulWidget {
  const SignoffTab({
    required this.service,
    required this.report,
    required this.onCompleted,
    super.key,
  });

  final ReportService service;
  final ReportContext report;
  final void Function(String paymentStatus) onCompleted;

  @override
  State<SignoffTab> createState() => _SignoffTabState();
}

class _SignoffTabState extends State<SignoffTab>
    with AutomaticKeepAliveClientMixin {
  // Que no se borre lo escrito al ir a la pestaña de estaciones y volver.
  @override
  bool get wantKeepAlive => true;

  late final _receivedBy = TextEditingController(
    text: widget.report.receivedByName.isEmpty
        ? widget.report.customerName
        : widget.report.receivedByName,
  );
  late final _amount = TextEditingController(text: widget.report.chargedAmount);
  late final _recommendations = TextEditingController(
    text: widget.report.recommendations,
  );
  late final _notes = TextEditingController(text: widget.report.generalNotes);
  Uint8List? _customerSignature;
  Uint8List? _technicianSignature;
  Uint8List? _storedTechnicianSignature;
  bool? _hasProfileSignature;
  bool _checkingSignature = false;
  String? _signatureCheckError;
  String? _signaturePreviewError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTechnicianSignature());
  }

  Future<void> _loadTechnicianSignature() async {
    if (_checkingSignature || _sending || !mounted) return;
    setState(() {
      _checkingSignature = true;
      _signatureCheckError = null;
      _signaturePreviewError = null;
    });
    try {
      final technician = await widget.service.profile();
      if (!mounted) return;
      _hasProfileSignature = technician.hasSignature;
      _replaceStoredSignature(null);
      if (technician.hasSignature) {
        try {
          final image = await widget.service.profileSignature();
          if (!mounted) return;
          _replaceStoredSignature(image);
        } catch (_) {
          if (mounted) {
            _signaturePreviewError =
                'No fue posible mostrar tu firma registrada';
          }
        }
      }
    } catch (_) {
      if (mounted) {
        _signatureCheckError =
            'No fue posible consultar si tienes una firma registrada';
      }
    } finally {
      if (mounted) setState(() => _checkingSignature = false);
    }
  }

  void _replaceStoredSignature(Uint8List? value) {
    final previous = _storedTechnicianSignature;
    _storedTechnicianSignature = value;
    if (previous != null) unawaited(MemoryImage(previous).evict());
  }

  @override
  void dispose() {
    _replaceStoredSignature(null);
    _receivedBy.dispose();
    _amount.dispose();
    _recommendations.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _receivedBy.text.trim().isNotEmpty &&
      double.tryParse(_amount.text.trim()) != null &&
      _recommendations.text.trim().isNotEmpty &&
      _customerSignature != null &&
      !_checkingSignature &&
      _signatureCheckError == null &&
      (_hasProfileSignature == true || _technicianSignature != null);

  Future<Uint8List?> _sign(String title) async {
    if (_sending) return null;
    return Navigator.of(context).push(
      MaterialPageRoute<Uint8List>(
        builder: (_) => SignatureScreen(title: title),
      ),
    );
  }

  Future<void> _finish() async {
    if (_sending || !_isComplete) return;
    setState(() => _sending = true);
    try {
      final paymentStatus = await widget.service.complete(
        visitId: widget.report.visitId,
        receivedBy: _receivedBy.text.trim(),
        amount: _amount.text.trim(),
        recommendations: _recommendations.text.trim(),
        notes: _notes.text.trim(),
        signature: _customerSignature!,
        technicianSignature: _hasProfileSignature == true
            ? null
            : _technicianSignature,
      );
      if (mounted) widget.onCompleted(paymentStatus);
    } on CustomException catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        AppSnackBar.error(context, error.message);
        // Si se quitó la firma del perfil mientras se llenaba el reporte,
        // conservar la firma del cliente y permitir capturar la del técnico.
        if (_hasProfileSignature == true && error.status == 422) {
          await _loadTechnicianSignature();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const FieldLabel('Nombre de quien recibe', required: true),
              _input(_receivedBy),
              const FieldLabel('Importe del servicio', required: true),
              _input(
                _amount,
                prefix: '\$ ',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const FieldLabel(
                'Recomendaciones para el cliente',
                required: true,
              ),
              _input(_recommendations, lines: 3),
              const FieldLabel('Observaciones del servicio'),
              _input(_notes, lines: 3),
              const FieldLabel('Firma del cliente', required: true),
              _SignatureBox(
                image: _customerSignature,
                onSign: () async {
                  final png = await _sign('Firma del cliente');
                  if (png != null && mounted) {
                    setState(() => _customerSignature = png);
                  }
                },
              ),
              const FieldLabel('Firma del técnico', required: true),
              _technicianSignatureSection(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 54),
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.muted,
              ),
              onPressed: _isComplete && !_sending ? _finish : null,
              child: _sending
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.muted,
                      ),
                    )
                  : const Text('Terminar servicio'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _technicianSignatureSection() {
    if (_checkingSignature) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text('Consultando tu firma…', style: AppTheme.body),
          ],
        ),
      );
    }
    if (_signatureCheckError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_signatureCheckError!, style: AppTheme.body),
          TextButton(
            onPressed: _loadTechnicianSignature,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (_hasProfileSignature == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_storedTechnicianSignature != null)
            Container(
              height: 120,
              decoration: AppTheme.profileCard,
              padding: const EdgeInsets.all(8),
              child: Image.memory(
                _storedTechnicianSignature!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => TextButton(
                  onPressed: _loadTechnicianSignature,
                  child: const Text('Reintentar vista previa'),
                ),
              ),
            )
          else ...[
            Text(
              _signaturePreviewError ??
                  'No fue posible mostrar tu firma registrada',
              style: AppTheme.body,
            ),
            TextButton(
              onPressed: _loadTechnicianSignature,
              child: const Text('Reintentar vista previa'),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Se usará la firma registrada en tu perfil.',
            style: AppTheme.body,
          ),
        ],
      );
    }
    return _SignatureBox(
      image: _technicianSignature,
      onSign: () async {
        final png = await _sign('Firma del técnico');
        if (png != null && mounted) setState(() => _technicianSignature = png);
      },
    );
  }

  Widget _input(
    TextEditingController controller, {
    int lines = 1,
    String? prefix,
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines == 1 ? 1 : 5,
    keyboardType: keyboard,
    // Cada letra puede habilitar o no el botón de terminar.
    onChanged: (_) => setState(() {}),
    style: AppTheme.body.copyWith(color: AppColors.text),
    decoration: InputDecoration(prefixText: prefix),
  );
}

/// Botón «Capturar firma» o, si ya se firmó, la firma con opción a repetirla.
class _SignatureBox extends StatelessWidget {
  const _SignatureBox({required this.image, required this.onSign});

  final Uint8List? image;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        onPressed: onSign,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('Capturar firma'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.memory(image!),
        ),
        TextButton(onPressed: onSign, child: const Text('Volver a firmar')),
      ],
    );
  }
}
