import 'dart:typed_data';

import '../../base/abstract_service_handler.dart';
import '../../base/custom_exception.dart';
import '../../models/report_evidence.dart';
import '../api_routes.dart';
import '../auth_messages.dart';
import 'report_service.dart';

class ReportEvidenceService
    extends
        AbstractServiceHandler<
          ({String reportId, String photoPath}),
          Uint8List
        > {
  const ReportEvidenceService(this.reportService)
    : super(
        failureMessage: 'No fue posible cargar la fotografía',
        connectionMessage: AuthMessages.connection,
      );
  final ReportService reportService;
  static const maxDownloadBytes = 20 * 1024 * 1024;

  /// Storage paths are reduced to a filename; never fetch third-party URLs.
  static String filename(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.isEmpty ||
        uri.pathSegments.any((s) => s == '..' || s == '.')) {
      throw const FormatException('Invalid photo path');
    }
    final name = uri.pathSegments.last;
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        RegExp(r'[\x00-\x1F]').hasMatch(name)) {
      throw const FormatException('Invalid photo filename');
    }
    return name;
  }

  @override
  Future<Uint8List> doExecute(
    ({String reportId, String photoPath}) input,
  ) async {
    if (input.reportId.isEmpty) throw const FormatException('Missing report');
    final base = Uri.parse(reportService.baseUrl);
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const FormatException('Invalid API URL');
    }
    final tokens = await reportService.tokenStore.read();
    if (tokens == null) {
      throw const CustomException(
        message: AuthMessages.expiredSession,
        status: 401,
      );
    }
    final uri = Uri.parse(
      '${reportService.baseUrl.replaceFirst(RegExp(r'/+$'), '')}${ApiRoutes.reportFile(input.reportId, filename(input.photoPath))}',
    );
    final response = await reportService.httpClient
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer ${tokens.accessToken}',
            'Accept': 'image/*',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw CustomException(
        message: response.statusCode == 401
            ? AuthMessages.expiredSession
            : failureMessage,
        status: response.statusCode,
      );
    }
    if (response.bodyBytes.length > maxDownloadBytes ||
        EvidencePhoto.imageType(response.bodyBytes) == null) {
      throw const FormatException('Invalid photo');
    }
    return response.bodyBytes;
  }
}
