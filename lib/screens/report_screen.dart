import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/services/report_service.dart';
import '../api/services/report_products_service.dart';
import '../base/custom_exception.dart';
import '../models/report_context.dart';
import '../theme/app_theme.dart';
import 'applied_products_tab.dart';
import 'controllers/report_products_controller.dart';
import 'controllers/report_evidence_controller.dart';
import 'evidence_tab.dart';
import 'signoff_tab.dart';
import 'station_screen.dart';

/// El reporte conserva sus estaciones y firma e intercala los productos.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    required this.service,
    required this.visitId,
    this.evidencePicker,
    super.key,
  });

  final ReportService service;
  final String visitId;
  final ImagePicker? evidencePicker;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this)
    ..addListener(_stageChanged);
  late final _products = ReportProductsController(
    visitId: widget.visitId,
    service: ReportProductsService(widget.service),
  );
  late Future<ReportContext> _report = _loadReport();
  late final _evidence = ReportEvidenceController(
    visitId: widget.visitId,
    service: widget.service,
    picker: widget.evidencePicker,
  );
  bool _productsDone = false;
  bool _evidenceDone = false;

  @override
  void initState() {
    super.initState();
    _evidence.addListener(_evidenceChanged);
  }

  void _evidenceChanged() {
    if (_evidence.picking || _evidence.saving) _evidenceDone = false;
    if (mounted) setState(() {});
  }

  Future<ReportContext> _loadReport() async {
    final report = await widget.service.load(widget.visitId);
    if (mounted) {
      _products.acceptContext(report);
      _evidence.acceptContext(report);
    }
    return report;
  }

  void _stageChanged() {
    if (mounted) setState(() {});
  }

  void _back() {
    if (_evidence.navigationLocked) return;
    if (_tabs.index > 0) {
      _tabs.animateTo(_tabs.index - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_stageChanged);
    _tabs.dispose();
    _products.dispose();
    _evidence.removeListener(_evidenceChanged);
    _evidence.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _report = _loadReport();
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
      return PopScope(
        canPop: _tabs.index == 0 && !_evidence.navigationLocked,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.white,
            leading: BackButton(onPressed: _back),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: AbsorbPointer(
                absorbing: _evidence.navigationLocked,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const titles = [
                      'Estaciones',
                      'Aplicación',
                      'Evidencias',
                      'Firma',
                    ];
                    final available = constraints.maxWidth / titles.length;
                    final labelWidth = titles
                        .map(
                          (title) => TextPainter.computeWidth(
                            text: TextSpan(
                              text: title,
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .merge(AppTheme.chip),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          ),
                        )
                        .reduce((a, b) => a > b ? a : b);
                    final scrollable = labelWidth + 12 > available;
                    final width = scrollable ? labelWidth + 12 : available;
                    return TabBar(
                      controller: _tabs,
                      labelStyle: AppTheme.chip,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.muted,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      isScrollable: scrollable,
                      tabAlignment: scrollable
                          ? TabAlignment.start
                          : TabAlignment.fill,
                      indicator: const BoxDecoration(),
                      tabs: [
                        _stage(
                          'Estaciones',
                          0,
                          report.stations.isEmpty ||
                              report.doneStations == report.stations.length,
                          width,
                        ),
                        _stage('Aplicación', 1, _productsDone, width),
                        _stage('Evidencias', 2, _evidenceDone, width),
                        _stage('Firma', 3, false, width),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            physics: _evidence.navigationLocked
                ? const NeverScrollableScrollPhysics()
                : null,
            children: [
              _StationsTab(
                report: report,
                onOpen: (i) => _openStation(report, i),
                onContinue: () => _tabs.animateTo(1),
              ),
              AppliedProductsTab(
                controller: _products,
                onContinue: () {
                  if (!_evidence.navigationLocked) {
                    _productsDone = true;
                    _tabs.animateTo(2);
                  }
                },
              ),
              EvidenceTab(
                controller: _evidence,
                onContinue: () {
                  _evidenceDone = true;
                  _tabs.animateTo(3);
                },
              ),
              SignoffTab(
                service: widget.service,
                report: report,
                evidenceController: _evidence,
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

  Widget _stage(String title, int index, bool complete, double width) => Tab(
    height: 56,
    child: SizedBox(
      // Identical widths in every phase, including the accessible scroll mode.
      width: width - 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 3,
                  color: _tabs.index == index
                      ? AppColors.primary
                      : complete
                      ? AppColors.success
                      : AppColors.border,
                ),
                if (complete && index != _tabs.index)
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ColoredBox(
                      color: AppColors.white,
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(child: Text(title, maxLines: 1, softWrap: false)),
          ),
        ],
      ),
    ),
  );
}

/// Pestaña 1: la lista de estaciones con cuántas van revisadas.
class _StationsTab extends StatelessWidget {
  const _StationsTab({
    required this.report,
    required this.onOpen,
    required this.onContinue,
  });

  final ReportContext report;
  final void Function(int index) onOpen;
  final VoidCallback onContinue;

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
                  'Este servicio no tiene estaciones. Continúa a productos aplicados.',
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
              onPressed: onContinue,
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
