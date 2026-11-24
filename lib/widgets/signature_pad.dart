import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/signature_image.dart';
import '../theme/app_theme.dart';

class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  bool get isEmpty => _strokes.isEmpty;

  void start(Offset point, Size size) {
    _strokes.add([_normalize(point, size)]);
    notifyListeners();
  }

  void add(Offset point, Size size) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(_normalize(point, size));
    notifyListeners();
  }

  Offset _normalize(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text
      ..strokeWidth = size.width / 160
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(stroke.first.dx * size.width, stroke.first.dy * size.height),
          paint.strokeWidth / 2,
          Paint()..color = AppColors.text,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
        for (final point in stroke.skip(1)) {
          path.lineTo(point.dx * size.width, point.dy * size.height);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  Future<SignatureImage> export() async {
    if (isEmpty) throw StateError('Empty signature');
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), const Size(1200, 480));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1200, 480);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Signature encoding failed');
      return SignatureImage(
        bytes: bytes.buffer.asUint8List(),
        filename: 'firma.png',
      );
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({
    required this.controller,
    this.enabled = true,
    super.key,
  });
  final SignaturePadController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Lienzo para dibujar tu firma',
    child: AspectRatio(
      aspectRatio: 2.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: enabled
                    ? (details) => controller.start(details.localPosition, size)
                    : null,
                onPanUpdate: enabled
                    ? (details) => controller.add(details.localPosition, size)
                    : null,
                child: CustomPaint(
                  painter: _SignaturePainter(controller),
                  size: size,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.controller) : super(repaint: controller);
  final SignaturePadController controller;
  @override
  void paint(Canvas canvas, Size size) => controller.paint(canvas, size);
  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      oldDelegate.controller != controller;
}
