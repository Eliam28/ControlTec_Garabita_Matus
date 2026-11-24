import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../theme/app_theme.dart';

/// Tarjeta de un servicio agendado. Si hay [onAction], abajo lleva el botón
/// para iniciar o continuar el servicio.
class VisitCard extends StatelessWidget {
  const VisitCard({
    required this.visit,
    this.onAction,
    this.loading = false,
    super.key,
  });

  final FieldVisit visit;
  final VoidCallback? onAction;
  final bool loading;

  /// El texto del botón según cómo va el servicio. Null: no lleva botón.
  String? get _actionLabel => switch (visit.status) {
    'programado' => 'Iniciar servicio',
    'en_progreso' => 'Continuar servicio',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: visit.status == 'en_progreso'
          ? Border.all(color: AppColors.primary, width: 1.5)
          : Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrap: si la hora y el estado no caben juntos, el estado baja.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${visit.startTime} – ${visit.endTime}', style: AppTheme.time),
            _StatusChip(visit),
          ],
        ),
        const SizedBox(height: 10),
        Text(visit.customerName, style: AppTheme.cardTitle),
        Text(visit.serviceName, style: AppTheme.service),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.place_outlined, text: visit.address),
        if (visit.notes != null)
          _InfoRow(icon: Icons.sticky_note_2_outlined, text: visit.notes!),
        if (onAction != null && _actionLabel != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: loading ? null : onAction,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.edit_outlined, size: 20),
            label: Text(_actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.visit);

  final FieldVisit visit;

  @override
  Widget build(BuildContext context) {
    final color = switch (visit.status) {
      'completado' => AppColors.success,
      'en_progreso' => AppColors.progress,
      'cancelado' => AppColors.error,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        visit.statusLabel,
        style: AppTheme.chip.copyWith(color: color),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTheme.body)),
      ],
    ),
  );
}
