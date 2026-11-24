import 'package:flutter/material.dart';

import '../api/services/report_service.dart';
import '../base/custom_exception.dart';
import '../models/report_context.dart';
import '../theme/app_theme.dart';
import 'signoff_tab.dart';
import 'station_screen.dart';

/// El reporte de un servicio en curso, con dos pestañas:
/// las estaciones que hay que revisar y la firma del cliente.
class ReportScreen extends StatefulWidget {
  const ReportScreen({required this.service, required this.visitId, super.key});

  final ReportService service;
  final String visitId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<ReportContext> _report = widget.service.load(widget.visitId);

  void _reload() {
    setState(() {
      _report = widget.service.load(widget.visitId);
    });
  }

  /// Abre la estación [index]; al volver se recarga para ver lo guardado.
  Future<void> _openStation(ReportContext report, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationScreen(
          service: widget.service,
          report: report,
          index: index,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReportContext>(
    future: _report,
    builder: (context, snapshot) {
      // Cargando o error: pantalla sencilla con flecha para volver.
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error is CustomException
                            ? (snapshot.error as CustomException).message
                            : 'No se pudo abrir el reporte',
                        style: AppTheme.body,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      final report = snapshot.data!;
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.white,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.customerName, style: AppTheme.cardTitle),
                Text(
                  '${report.startTime} · ${report.locationName}',
                  style: AppTheme.footer,
                ),
              ],
            ),
            bottom: const TabBar(
              labelStyle: AppTheme.chip,
              tabs: [
                Tab(text: 'Estaciones'),
                Tab(text: 'Firma'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _StationsTab(
                report: report,
                onOpen: (i) => _openStation(report, i),
              ),
              SignoffTab(
                service: widget.service,
                report: report,
                // Se cierra devolviendo el estado de pago a la pantalla de inicio.
                onCompleted: (paymentStatus) =>
                    Navigator.of(context).pop(paymentStatus),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Pestaña 1: la lista de estaciones con cuántas van revisadas.
class _StationsTab extends StatelessWidget {
  const _StationsTab({required this.report, required this.onOpen});

  final ReportContext report;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final total = report.stations.length;
    final done = report.doneStations;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: AppColors.border,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$done de $total', style: AppTheme.chip),
                ],
              ),
              const SizedBox(height: 16),
              if (total == 0)
                const Text(
                  'Este servicio no tiene estaciones. Pasa a la firma.',
                  style: AppTheme.body,
                  textAlign: TextAlign.center,
                ),
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StationTile(
                    station: report.stations[i],
                    onTap: () => onOpen(i),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({required this.station, required this.onTap});

  final ReportStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    child: ListTile(
      onTap: onTap,
      leading: station.isDone
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : const Icon(Icons.radio_button_unchecked, color: AppColors.muted),
      title: Text(station.code, style: AppTheme.stationCode),
      subtitle: Text(station.typeName, style: AppTheme.footer),
      trailing: const Icon(Icons.chevron_right, color: AppColors.hint),
    ),
  );
}
