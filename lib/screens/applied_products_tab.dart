import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/applied_product_card.dart';
import '../widgets/app_snack_bar.dart';
import 'controllers/report_products_controller.dart';
import 'product_application_screen.dart';

/// The report provides the header and stage indicator; this is its middle tab.
class AppliedProductsTab extends StatefulWidget {
  const AppliedProductsTab({
    required this.controller,
    required this.onContinue,
    super.key,
  });
  final ReportProductsController controller;
  final VoidCallback onContinue;

  @override
  State<AppliedProductsTab> createState() => _AppliedProductsTabState();
}

class _AppliedProductsTabState extends State<AppliedProductsTab>
    with AutomaticKeepAliveClientMixin {
  bool _opening = false;
  @override
  bool get wantKeepAlive => true;

  Future<void> _add() async {
    if (_opening || widget.controller.saving) return;
    setState(() => _opening = true);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductApplicationScreen(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (saved == true) {
      AppSnackBar.success(context, 'Producto agregado correctamente');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                  children: [
                    const Text(
                      'Productos aplicados',
                      style: AppTheme.applicationTitle,
                    ),
                    if (controller.loading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                    if (controller.error != null) ...[
                      const SizedBox(height: 16),
                      Text(controller.error!, style: AppTheme.body),
                      TextButton(
                        onPressed: controller.loading
                            ? null
                            : controller.refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                    if (controller.products.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 52),
                        child: Column(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 36,
                              color: AppColors.muted,
                            ),
                            SizedBox(height: 18),
                            Text(
                              'Sin productos aplicados',
                              style: AppTheme.description,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const SizedBox(height: 20),
                      for (final product in controller.products)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppliedProductCard(product: product),
                        ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      style: AppTheme.profileSecondaryButton,
                      onPressed:
                          _opening || controller.saving || controller.loading
                          ? null
                          : _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar producto'),
                    ),
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
                    onPressed: controller.saving || _opening
                        ? null
                        : widget.onContinue,
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
