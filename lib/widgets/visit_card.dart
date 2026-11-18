import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../theme/app_theme.dart';

/// Tarjeta de un servicio agendado. Solo muestra información.
class VisitCard extends StatelessWidget {
  const VisitCard({required this.visit, super.key});

  final FieldVisit visit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
