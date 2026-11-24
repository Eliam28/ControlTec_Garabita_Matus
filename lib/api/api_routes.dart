abstract final class ApiRoutes {
  static const login = '/auth/mobile/login';
  static const refresh = '/auth/mobile/refresh';
  static const logout = '/auth/mobile/logout';
  static const me = '/auth/mobile/me';
  static const myDay = '/scheduling/my-day';

  // Reporte de un servicio.
  static String startReport(String visitId) =>
      '/scheduling/visits/$visitId/report/start';
  static String reportContext(String visitId) =>
      '/reports/visits/$visitId/context';
  static String reportStation(String visitId, String stationId) =>
      '/reports/visits/$visitId/stations/$stationId';
  static String completeReport(String visitId) =>
      '/reports/visits/$visitId/complete';
  static String reportPayment(String visitId) =>
      '/reports/visits/$visitId/payment';
}
