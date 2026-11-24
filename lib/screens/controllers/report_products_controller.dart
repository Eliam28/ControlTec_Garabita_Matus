import 'package:flutter/foundation.dart';

import '../../api/services/report_products_service.dart';
import '../../base/custom_exception.dart';
import '../../models/report_context.dart';
import '../../models/report_product.dart';

class ReportProductsController extends ChangeNotifier {
  ReportProductsController({required this.visitId, required this.service});
  final String visitId;
  final ReportProductsService service;
  List<AppliedProduct> products = const [];
  List<CatalogProduct> options = const [];
  bool loading = false;
  bool saving = false;
  String? error;
  bool _disposed = false;

  void acceptContext(ReportContext context) {
    if (_disposed || context.visitId != visitId) return;
    products = List.unmodifiable(context.products);
    options = List.unmodifiable(context.productOptions);
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (loading || saving || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      acceptContext(await service.load(visitId));
    } on CustomException catch (exception) {
      if (!_disposed) error = exception.message;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> add(ProductAddition addition) async {
    if (saving || loading || _disposed || addition.visitId != visitId) {
      return false;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      final saved = await service.execute(addition);
      if (_disposed) return false;
      products = List.unmodifiable(saved);
      return true;
    } on CustomException catch (exception) {
      if (!_disposed) error = exception.message;
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    products = const [];
    options = const [];
    super.dispose();
  }
}
