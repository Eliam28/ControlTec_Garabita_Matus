import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EvidencePhotoTile extends StatefulWidget {
  const EvidencePhotoTile({
    required this.caption,
    required this.load,
    this.onRemove,
    super.key,
  });
  final String caption;
  final Future<Uint8List> Function(bool retry) load;
  final VoidCallback? onRemove;
  @override
  State<EvidencePhotoTile> createState() => _EvidencePhotoTileState();
}

class _EvidencePhotoTileState extends State<EvidencePhotoTile> {
  late Future<Uint8List> _image = widget.load(false);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 1.3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EvidencePhotoViewer(
                      caption: widget.caption,
                      initial: _image,
                      load: widget.load,
                    ),
                  ),
                ),
                child: FutureBuilder<Uint8List>(
                  future: _image,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _image = widget.load(true);
                          }),
                          child: const Text('Reintentar foto'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _image = widget.load(true);
                          }),
                          child: const Text('Reintentar foto'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: AppColors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Quitar fotografía',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close, color: AppColors.error),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        widget.caption,
        style: AppTheme.footer,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class EvidencePhotoViewer extends StatefulWidget {
  const EvidencePhotoViewer({
    required this.caption,
    required this.initial,
    required this.load,
    super.key,
  });
  final String caption;
  final Future<Uint8List> initial;
  final Future<Uint8List> Function(bool retry) load;
  @override
  State<EvidencePhotoViewer> createState() => _EvidencePhotoViewerState();
}

class _EvidencePhotoViewerState extends State<EvidencePhotoViewer> {
  late Future<Uint8List> _image = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.white,
      title: Text(widget.caption, style: AppTheme.cardTitle),
    ),
    body: SafeArea(
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No fue posible cargar la fotografía',
                    style: AppTheme.body,
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _image = widget.load(true);
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'No fue posible mostrar la fotografía',
                  style: AppTheme.body,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
