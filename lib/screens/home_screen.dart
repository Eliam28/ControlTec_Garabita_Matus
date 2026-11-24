import 'package:flutter/material.dart';

import '../api/services/my_day_service.dart';
import '../api/services/report_service.dart';
import '../base/custom_exception.dart';
import '../models/field_day.dart';
import '../models/field_visit.dart';
import '../theme/app_theme.dart';
import '../widgets/app_brand.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/visit_card.dart';
import 'report_screen.dart';

/// Pantalla principal: los servicios que el técnico tiene agendados hoy.
/// Desde cada tarjeta se inicia o continúa el reporte del servicio.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.myDayService,
    required this.technicianName,
    this.reportService,
    super.key,
  });

  final MyDayService myDayService;
  final String technicianName;

  /// Sin él (modo de prueba) las tarjetas no llevan botón.
  final ReportService? reportService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<FieldDay> _day = widget.myDayService.load();

  /// El servicio que se está iniciando, para enseñar la rueda en su botón.
  String? _startingId;

  /// Se llama al deslizar hacia abajo o al tocar «Reintentar».
  Future<void> _reload() async {
    setState(() {
      _day = widget.myDayService.load();
    });
    try {
      await _day;
    } catch (_) {
      // El error ya lo muestra el FutureBuilder.
    }
  }

  /// Inicia el servicio si estaba programado y abre su reporte.
  Future<void> _openVisit(FieldVisit visit) async {
    final service = widget.reportService!;
    if (visit.status == 'programado') {
      setState(() => _startingId = visit.id);
      try {
        await service.start(visit.id);
      } on CustomException catch (error) {
        if (mounted) AppSnackBar.error(context, error.message);
        return;
      } finally {
        if (mounted) setState(() => _startingId = null);
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(service: service, visitId: visit.id),
      ),
    );
    // Al volver, la tarjeta cambia de estado: se vuelve a pedir el día.
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<FieldDay>(
          future: _day,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppBrand(),
              const SizedBox(height: 24),
              const Text('Mis servicios de hoy', style: AppTheme.screenTitle),
              Text(widget.technicianName, style: AppTheme.description),
              const SizedBox(height: 20),
              ..._content(snapshot),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _content(AsyncSnapshot<FieldDay> snapshot) {
    // Cargando.
    if (snapshot.connectionState != ConnectionState.done) {
      return const [Center(child: CircularProgressIndicator())];
    }
    // Error.
    if (snapshot.hasError) {
      final error = snapshot.error;
      final message = error is CustomException
          ? error.message
          : MyDayService.loadError;
      return [
        Text(message, style: AppTheme.body, textAlign: TextAlign.center),
        TextButton(onPressed: _reload, child: const Text('Reintentar')),
      ];
    }
    // Sin servicios.
    final visits = snapshot.data!.visits;
    if (visits.isEmpty) {
      return const [
        Text(
          'No tienes servicios agendados hoy.',
          style: AppTheme.body,
          textAlign: TextAlign.center,
        ),
      ];
    }
    // Lista de servicios.
    return [
      Text(
        visits.length == 1
            ? '1 servicio agendado'
            : '${visits.length} servicios agendados',
        style: AppTheme.body,
      ),
      const SizedBox(height: 12),
      for (final visit in visits)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VisitCard(
            visit: visit,
            loading: _startingId == visit.id,
            onAction: widget.reportService == null
                ? null
                : () => _openVisit(visit),
          ),
        ),
    ];
  }
}
