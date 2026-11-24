import 'package:flutter/material.dart';

import '../api/services/report_service.dart';
import '../base/custom_exception.dart';
import '../models/report_context.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/field_label.dart';

/// Después de firmar: el técnico dice si el cliente pagó y con qué.
/// Si no pagó, se pide con qué va a pagar.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    required this.service,
    required this.visitId,
    required this.customerName,
    super.key,
  });

  final ReportService service;
  final String visitId;
  final String customerName;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool? _paid;
  String? _method;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.declarePayment(
        visitId: widget.visitId,
        paid: _paid!,
        method: _method!,
      );
      if (mounted) Navigator.of(context).pop();
    } on CustomException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.white,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.customerName, style: AppTheme.cardTitle),
          const Text('Servicio firmado', style: AppTheme.footer),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FieldLabel('¿El cliente pagó el servicio?', required: true),
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: 'Pagado',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                selected: _paid == true,
                onTap: () => setState(() => _paid = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Choice(
                label: 'Sin pagar',
                icon: Icons.schedule,
                color: AppColors.error,
                selected: _paid == false,
                onTap: () => setState(() => _paid = false),
              ),
            ),
          ],
        ),
        if (_paid != null) ...[
          FieldLabel(
            _paid! ? '¿Con qué pagó?' : '¿Con qué va a pagar?',
            required: true,
          ),
          for (final method in paymentMethods)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Choice(
                label: method.label,
                color: AppColors.primary,
                selected: _method == method.id,
                onTap: () => setState(() => _method = method.id),
              ),
            ),
        ],
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.muted,
          ),
          onPressed: _paid != null && _method != null && !_saving
              ? _save
              : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.muted,
                  ),
                )
              : const Text('Guardar'),
        ),
      ),
    ),
  );
}

/// Una opción en forma de tarjeta; la elegida se pinta de su color.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? color.withValues(alpha: 0.1) : AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? color : AppColors.border,
        width: selected ? 2 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: icon == null
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: selected ? color : AppColors.muted),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
