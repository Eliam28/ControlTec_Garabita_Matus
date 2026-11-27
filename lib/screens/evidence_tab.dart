import 'dart:async';

import 'package:flutter/material.dart';

import '../base/custom_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/evidence_photo_tile.dart';
import 'controllers/report_evidence_controller.dart';

class EvidenceTab extends StatefulWidget {
  const EvidenceTab({
    required this.controller,
    required this.onContinue,
    super.key,
  });
  final ReportEvidenceController controller;
  final VoidCallback onContinue;
  @override
  State<EvidenceTab> createState() => _EvidenceTabState();
}

class _EvidenceTabState extends State<EvidenceTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  Future<void> _pick(bool camera) async {
    try {
      await widget.controller.pick(camera: camera);
    } on CustomException catch (error) {
      if (mounted) AppSnackBar.error(context, error.message);
    }
  }

  Future<void> _remove(int index) async {
    try {
      await widget.controller.remove(widget.controller.photos[index]);
    } on CustomException catch (error) {
      if (mounted) AppSnackBar.error(context, error.message);
    }
  }

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 650 ? 3 : 2;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 12) / columns,
              child: child,
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final enabled = c.ready && !c.busy && !c.closed;
        Widget button(bool camera) => OutlinedButton.icon(
          style: AppTheme.profileSecondaryButton,
          onPressed: enabled ? () => _pick(camera) : null,
          icon: Icon(camera ? Icons.camera_alt_outlined : Icons.image_outlined),
          label: Text(camera ? 'Tomar foto' : 'Elegir fotos'),
        );
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: c.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                  children: [
                    Text(
                      'Fotografías de estaciones · ${c.stationPhotos.length}',
                      style: AppTheme.applicationTitle,
                    ),
                    const SizedBox(height: 18),
                    if (c.stationPhotos.isEmpty)
                      const Text(
                        'Ninguna estación lleva fotografía.',
                        style: AppTheme.description,
                      )
                    else
                      _grid([
                        for (final photo in c.stationPhotos)
                          EvidencePhotoTile(
                            key: ValueKey(
                              'station-${photo.photoPath}-${c.imageRevision}',
                            ),
                            caption: 'Estación ${photo.stationCode}',
                            load: (retry) => c.image(photo, retry: retry),
                          ),
                      ]),
                    const SizedBox(height: 36),
                    Text(
                      'Fotografías adicionales · ${c.additionalCount}/4',
                      style: AppTheme.applicationTitle,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < 350 ||
                              MediaQuery.textScalerOf(context).scale(16) > 20
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                button(true),
                                const SizedBox(height: 12),
                                button(false),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: button(true)),
                                const SizedBox(width: 12),
                                Expanded(child: button(false)),
                              ],
                            ),
                    ),
                    if (c.loading || c.picking || c.saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (c.error != null) ...[
                      const SizedBox(height: 16),
                      Text(c.error!, style: AppTheme.body),
                      TextButton(
                        onPressed: c.busy ? null : c.refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                    if (c.additionalCount > 0) ...[
                      const SizedBox(height: 24),
                      _grid([
                        for (final photo in c.savedPhotos)
                          EvidencePhotoTile(
                            key: ValueKey(
                              'saved-${photo.photoPath}-${c.imageRevision}',
                            ),
                            caption: 'Fotografía guardada',
                            load: (retry) => c.image(photo, retry: retry),
                          ),
                        for (var i = 0; i < c.photos.length; i++)
                          EvidencePhotoTile(
                            key: ValueKey(c.photos[i].id),
                            caption: 'Fotografía adicional ${i + 1}',
                            load: (_) => Future.value(c.photos[i].bytes),
                            onRemove: enabled ? () => _remove(i) : null,
                          ),
                      ]),
                      const SizedBox(height: 12),
                      if (c.photos.isNotEmpty)
                        const Text(
                          'Las fotografías pendientes se enviarán al terminar el servicio.',
                          style: AppTheme.footer,
                        ),
                      if (c.savedPhotos.isNotEmpty)
                        const Text(
                          'Las fotografías ya guardadas solo pueden consultarse.',
                          style: AppTheme.footer,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: AppColors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    style: AppTheme.applicationButton,
                    onPressed: c.ready && !c.busy ? widget.onContinue : null,
                    child: const Text('Continuar'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
