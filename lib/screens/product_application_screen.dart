import 'package:flutter/material.dart';

import '../models/report_context.dart';
import '../models/report_product.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/field_label.dart';
import '../widgets/option_picker.dart';
import 'controllers/report_products_controller.dart';
import 'validators/product_validator.dart';

class ProductApplicationScreen extends StatefulWidget {
  const ProductApplicationScreen({required this.controller, super.key});
  final ReportProductsController controller;
  @override
  State<ProductApplicationScreen> createState() =>
      _ProductApplicationScreenState();
}

class _ProductApplicationScreenState extends State<ProductApplicationScreen> {
  final _area = TextEditingController();
  final _extraInfo = TextEditingController();
  final _dose = TextEditingController();
  CatalogProduct? _product;
  ApplicationTechnique? _technique;
  ProductAddition? _attempt;
  bool _saving = false;
  bool _closing = false;
  bool _choosing = false;
  bool get _dirty =>
      _product != null ||
      _technique != null ||
      _area.text.isNotEmpty ||
      _extraInfo.text.isNotEmpty;

  void _changed() {
    _attempt = null;
    setState(() {});
  }

  Future<void> _select() async {
    if (_saving || _choosing || widget.controller.loading) return;
    if (widget.controller.options.isEmpty) {
      AppSnackBar.error(context, 'No hay productos disponibles en el catálogo');
      return;
    }
    _choosing = true;
    final choice = await pickOption(
      context,
      title: 'Producto',
      options: widget.controller.options
          .map((p) => Option(id: p.id, label: p.name))
          .toList(),
    );
    _choosing = false;
    if (choice == null || !mounted) return;
    for (final product in widget.controller.options) {
      if (product.id == choice.id) {
        _product = product;
        _dose.text = product.recommendedDose ?? 'No disponible';
        _changed();
        break;
      }
    }
  }

  Future<void> _save() async {
    if (_saving || widget.controller.loading) return;
    final error = ProductValidator.validate(
      product: _product,
      area: _area.text,
      technique: _technique,
      extraInfo: _extraInfo.text,
    );
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    FocusScope.of(context).unfocus();
    _attempt ??= ProductAddition(
      visitId: widget.controller.visitId,
      application: ProductApplication(
        productId: _product!.id,
        area: _area.text.trim(),
        technique: _technique!,
        extraInfo: _extraInfo.text.trim(),
      ),
    );
    setState(() => _saving = true);
    final saved = await widget.controller.add(_attempt!);
    if (!mounted) return;
    if (saved) {
      _closing = true;
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      AppSnackBar.error(
        context,
        widget.controller.error ??
            'No fue posible guardar el producto. Intenta nuevamente',
      );
    }
  }

  Future<void> _cancel() async {
    if (_saving || _closing) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Descartar producto?'),
          content: const Text('Los datos sin guardar se perderán.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    _closing = true;
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _area.dispose();
    _extraInfo.dispose();
    _dose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _closing || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          onPressed: _saving ? null : _cancel,
          icon: const Icon(Icons.close),
        ),
        title: const Text('Producto aplicado', style: AppTheme.cardTitle),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const FieldLabel('Producto', required: true),
            OptionField(
              hint: 'Elige del catálogo',
              text: _product?.name,
              onTap: _select,
            ),
            if (widget.controller.options.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.controller.error ??
                    'No hay productos disponibles en el catálogo',
                style: AppTheme.body,
              ),
              TextButton(
                onPressed: widget.controller.loading || _saving
                    ? null
                    : widget.controller.refresh,
                child: const Text('Reintentar'),
              ),
            ],
            if (widget.controller.loading) const LinearProgressIndicator(),
            const FieldLabel('Área', required: true),
            TextField(
              controller: _area,
              enabled: !_saving,
              onChanged: (_) => _changed(),
              maxLength: 200,
              style: AppTheme.body,
              decoration: const InputDecoration(
                hintText: 'Almacén norte',
                hintStyle: AppTheme.applicationHint,
                contentPadding: AppTheme.applicationInputPadding,
                counterText: '',
              ),
            ),
            const FieldLabel('Técnica utilizada', required: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final technique in ApplicationTechnique.values)
                  ChoiceChip(
                    label: Text(technique.label),
                    labelStyle: AppTheme.body.copyWith(
                      color: _technique == technique
                          ? AppColors.primary
                          : AppColors.text,
                    ),
                    selected: _technique == technique,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    shape: AppTheme.applicationTechniqueShape(
                      _technique == technique,
                    ),
                    side: AppTheme.applicationTechniqueShape(
                      _technique == technique,
                    ).side,
                    backgroundColor: AppColors.white,
                    selectedColor: AppColors.primary.withValues(alpha: .1),
                    onSelected: _saving
                        ? null
                        : (selected) {
                            _technique = selected ? technique : null;
                            _changed();
                          },
                  ),
              ],
            ),
            const FieldLabel('Dosis aplicada'),
            TextField(
              controller: _dose,
              readOnly: true,
              canRequestFocus: false,
              style: AppTheme.body,
              decoration: const InputDecoration(
                hintText: 'Elige el producto',
                hintStyle: AppTheme.applicationHint,
                contentPadding: AppTheme.applicationInputPadding,
              ),
            ),
            const FieldLabel('Más información (opcional)'),
            TextField(
              controller: _extraInfo,
              enabled: !_saving,
              onChanged: (_) => _changed(),
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              style: AppTheme.body,
              decoration: const InputDecoration(
                hintStyle: AppTheme.applicationHint,
                contentPadding: AppTheme.applicationInputPadding,
                hintText:
                    'Lo que valga la pena dejar por escrito de esta aplicación',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ColoredBox(
          color: AppColors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: AppTheme.applicationButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Agregar'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
