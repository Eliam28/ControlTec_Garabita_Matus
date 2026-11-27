import 'package:flutter/material.dart';

import '../models/report_product.dart';
import '../theme/app_theme.dart';

class AppliedProductCard extends StatelessWidget {
  const AppliedProductCard({required this.product, super.key});
  final AppliedProduct product;

  String _value(String? text) =>
      text?.trim().isNotEmpty == true ? text! : 'No disponible';

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.profileCard,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: AppTheme.cardTitle),
        const SizedBox(height: 10),
        Text('Área: ${_value(product.area)}', style: AppTheme.body),
        const SizedBox(height: 6),
        Text(
          'Técnica: ${ApplicationTechnique.fromCode(product.technique)?.label ?? 'No disponible'}',
          style: AppTheme.body,
        ),
        const SizedBox(height: 6),
        Text(
          'Dosis aplicada: ${_value(product.appliedDose)}',
          style: AppTheme.body,
        ),
        if (product.extraInfo?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text('Más información: ${product.extraInfo}', style: AppTheme.body),
        ],
      ],
    ),
  );
}
