/// The closed vocabulary published by FastAPI's ServiceTechnique schema.
enum ApplicationTechnique {
  aspersion('Aspersión'),
  termonebulizacion('Termonebulización'),
  micronizacion('Micronización'),
  inyeccion('Inyección'),
  monitoreo('Monitoreo'),
  espolvoreo('Espolvoreo');

  const ApplicationTechnique(this.label);
  final String label;

  static ApplicationTechnique? fromCode(String? code) {
    for (final technique in values) {
      if (technique.name == code) return technique;
    }
    return null;
  }
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    this.recommendedDose,
  });
  final String id;
  final String name;
  final String? recommendedDose;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    recommendedDose: json['recommended_dose'] as String?,
  );
}

class AppliedProduct {
  const AppliedProduct({
    required this.id,
    required this.productId,
    required this.name,
    this.area,
    this.technique,
    this.appliedDose,
    this.extraInfo,
  });

  final String id;
  final String productId;
  final String name;
  final String? area;
  final String? technique;
  final String? appliedDose;
  final String? extraInfo;

  factory AppliedProduct.fromJson(Map<String, dynamic> json) => AppliedProduct(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    name: json['product_name'] as String,
    area: json['area'] as String?,
    technique: json['technique'] as String?,
    appliedDose: json['applied_dose'] as String?,
    extraInfo: json['extra_info'] as String?,
  );

  Map<String, dynamic> toWriteJson() => {
    'product_id': productId,
    'area': area,
    'technique': technique,
    'applied_dose': appliedDose,
    'extra_info': extraInfo,
  };
}

class ProductApplication {
  const ProductApplication({
    required this.productId,
    required this.area,
    required this.technique,
    required this.extraInfo,
  });

  final String productId;
  final String area;
  final ApplicationTechnique technique;
  final String extraInfo;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'area': area,
    'technique': technique.name,
    'extra_info': extraInfo,
  };

  bool matches(AppliedProduct product) =>
      product.productId == productId &&
      product.area == area &&
      product.technique == technique.name &&
      product.extraInfo == extraInfo;
}

/// Retained by one form across retries. A lost PUT response must not add twice.
class ProductAddition {
  ProductAddition({required this.visitId, required this.application});
  final String visitId;
  final ProductApplication application;
  int? previousMatches;
}
