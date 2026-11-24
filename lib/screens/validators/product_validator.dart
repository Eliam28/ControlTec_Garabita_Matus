import '../../models/report_product.dart';

abstract final class ProductValidator {
  static String? validate({
    required CatalogProduct? product,
    required String area,
    required ApplicationTechnique? technique,
    required String extraInfo,
  }) {
    if (product == null) return 'Seleccione un producto del catálogo';
    if (area.trim().isEmpty || technique == null || extraInfo.trim().isEmpty) {
      return 'Complete todos los campos obligatorios';
    }
    if (area.trim().runes.length > 200 ||
        extraInfo.trim().runes.length > 1000) {
      return 'El área admite hasta 200 caracteres y más información hasta 1000';
    }
    // The actual API copies the recommended dose; it accepts no quantity/unit.
    return null;
  }
}
