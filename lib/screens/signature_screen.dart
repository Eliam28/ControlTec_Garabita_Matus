import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla para firmar con el dedo. Devuelve la firma como imagen PNG.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({required this.title, super.key});

  final String title;

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  /// Cada trazo es la lista de puntos desde que se apoya el dedo hasta que se levanta.
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  /// Dibuja los trazos en una imagen blanca y la convierte a PNG.
  Future<void> _save() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = AppColors.white);
    _SignaturePainter(_strokes).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(
      _size.width.round(),
      _size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List>(data!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.white,
      title: Text(widget.title, style: AppTheme.cardTitle),
      actions: [
        TextButton(
          onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
          child: const Text('Borrar'),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: GestureDetector(
              onPanStart: (details) =>
                  setState(() => _strokes.add([details.localPosition])),
              onPanUpdate: (details) =>
                  setState(() => _strokes.last.add(details.localPosition)),
              child: CustomPaint(
                painter: _SignaturePainter(_strokes),
                size: Size.infinite,
                child: _strokes.isEmpty
                    ? const Center(
                        child: Text('Firma aquí', style: AppTheme.description),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.muted,
          ),
          onPressed: _strokes.isEmpty ? null : _save,
          child: const Text('Guardar firma'),
        ),
      ),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = AppColors.text
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      // Un toque sin mover el dedo deja un punto.
      if (stroke.length == 1) path.lineTo(stroke.first.dx, stroke.first.dy);
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
