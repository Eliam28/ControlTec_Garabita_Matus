import 'package:flutter/material.dart';

import '../api/services/my_day_service.dart';
import '../base/custom_exception.dart';
import '../models/field_day.dart';
import '../theme/app_theme.dart';
import '../widgets/app_brand.dart';
import '../widgets/visit_card.dart';

/// Pantalla principal: los servicios que el técnico tiene agendados hoy.
/// Por ahora solo se consultan; todavía no se pueden realizar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.myDayService,
    required this.technicianName,
    super.key,
  });

  final MyDayService myDayService;
  final String technicianName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<FieldDay> _day = widget.myDayService.load();

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
          child: VisitCard(visit: visit),
        ),
    ];
  }
}
