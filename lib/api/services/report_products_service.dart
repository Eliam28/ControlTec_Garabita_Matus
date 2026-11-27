import '../../base/abstract_service_handler.dart';
import '../../base/custom_exception.dart';
import '../../models/report_context.dart';
import '../../models/report_product.dart';
import '../auth_messages.dart';
import 'report_service.dart';

/// Reuses the report transport, token store and session refresh interceptor.
class ReportProductsService
    extends AbstractServiceHandler<ProductAddition, List<AppliedProduct>> {
  const ReportProductsService(this.reportService)
    : super(
        failureMessage:
            'No fue posible guardar el producto. Intenta nuevamente',
        connectionMessage: AuthMessages.connection,
      );

  final ReportService reportService;

  Future<ReportContext> load(String visitId) => runSafely(() async {
    try {
      final context = await reportService.load(visitId);
      if (context.visitId != visitId) throw const FormatException();
      return context;
    } on CustomException catch (error) {
      throw _safeError(error);
    }
  });

  @override
  Future<List<AppliedProduct>> doExecute(ProductAddition input) async {
    try {
      // Read immediately before the replacing PUT, including other saved rows.
      final current = await load(input.visitId);
      final matching = current.products.where(input.application.matches).length;
      input.previousMatches ??= matching;
      if (matching > input.previousMatches!) return current.products;

      if (current.products.any(
        (p) => ApplicationTechnique.fromCode(p.technique) == null,
      )) {
        throw const CustomException(
          message: 'Hay un producto registrado sin una técnica válida. Solicita su revisión antes de agregar otro',
          code: 'legacy_product',
        );
      }
      final products = await reportService.saveProducts(input.visitId, [
        ...current.products.map((p) => p.toWriteJson()),
        input.application.toJson(),
      ]);
      // Do not announce success for an incomplete or malformed confirmation.
      if (products.where(input.application.matches).length <=
              input.previousMatches! ||
          !_retainsExisting(current.products, products)) {
        throw const FormatException();
      }
      return products;
    } on CustomException catch (error) {
      throw _safeError(error);
    }
  }

  bool _retainsExisting(
    List<AppliedProduct> before,
    List<AppliedProduct> after,
  ) {
    final remaining = [...after];
    for (final product in before) {
      final index = remaining.indexWhere(
        (saved) =>
            saved.productId == product.productId &&
            saved.area == product.area &&
            saved.technique == product.technique &&
            (saved.extraInfo ?? '').trim() == (product.extraInfo ?? '').trim(),
      );
      if (index < 0) return false;
      remaining.removeAt(index);
    }
    return true;
  }

  CustomException _safeError(CustomException error) => switch (error.status) {
    401 => const CustomException(
      message: AuthMessages.expiredSession,
      status: 401,
    ),
    403 => const CustomException(
      message: 'No tienes permiso para modificar este servicio',
      status: 403,
    ),
    404 => const CustomException(
      message: 'No se encontró el servicio o uno de los productos. Actualiza e intenta nuevamente',
      status: 404,
    ),
    409 => const CustomException(
      message:
          'El servicio cambió o ya fue cerrado. Actualiza antes de continuar',
      status: 409,
    ),
    400 || 422 => const CustomException(
      message: 'Revisa los datos del producto. El servidor no pudo guardarlos',
      status: 422,
    ),
    final int status when status >= 500 => CustomException(
      message: failureMessage,
      status: status,
    ),
    final int status => CustomException(
      message: failureMessage,
      status: status,
    ),
    _ => error,
  };
}
