import 'package:flutter/material.dart';

import '../api/services/report_service.dart';
import '../base/custom_exception.dart';
import '../models/report_context.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/field_label.dart';
import '../widgets/option_picker.dart';

/// Revisión de una estación: hallazgo, estado, plagas y observaciones.
/// «Guardar y siguiente» la manda a la API y pasa a la siguiente estación;
/// en la última, vuelve a la lista.
class StationScreen extends StatefulWidget {
  const StationScreen({
    required this.service,
    required this.report,
    required this.index,
    super.key,
  });

  final ReportService service;
  final ReportContext report;
  final int index;

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late int _index = widget.index;

  /// Estaciones ya revisadas, para el contador de arriba.
  late final Set<String> _doneIds = {
    for (final s in widget.report.stations)
      if (s.isDone) s.id,
  };

  // El formulario de la estación actual.
  Option? _finding;
  Option? _condition;
  List<String> _pestIds = [];
  final _notes = TextEditingController();
  bool _saving = false;

  ReportStation get _station => widget.report.stations[_index];
  bool get _isLast => _index == widget.report.stations.length - 1;

  @override
  void initState() {
    super.initState();
    _fillForm();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Si la estación ya se había revisado, se cargan sus datos para corregirlos.
  void _fillForm() {
    final station = _station;
    _finding = station.findings
        .where((f) => f.id == station.findingId)
        .firstOrNull;
    _condition = stationConditions
        .where((c) => c.id == station.condition)
        .firstOrNull;
    _pestIds = [...station.pestIds];
    _notes.text = station.notes ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.saveStation(
        visitId: widget.report.visitId,
        stationId: _station.id,
        findingId: _finding!.id,
        condition: _condition!.id,
        pestIds: _pestIds,
        notes: _notes.text.trim(),
      );
    } on CustomException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, error.message);
      }
      return;
    }
    if (!mounted) return;
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _doneIds.add(_station.id);
      _saving = false;
      _index++;
      _fillForm();
    });
  }

  String get _pestsText {
    if (_pestIds.isEmpty) return 'Ninguna';
    return widget.report.pests
        .where((p) => _pestIds.contains(p.id))
        .map((p) => p.label)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final station = _station;
    final canSave = _finding != null && _condition != null && !_saving;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(station.code, style: AppTheme.stationCode),
            Text(station.typeName, style: AppTheme.footer),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_doneIds.length}/${widget.report.stations.length}',
              style: AppTheme.footer,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FieldLabel('Hallazgo', required: true),
          OptionField(
            hint: 'Selecciona un hallazgo',
            text: _finding?.label,
            dotColor: _finding == null
                ? null
                : severityColor(_finding!.severity),
            onTap: () async {
              final option = await pickOption(
                context,
                title: '¿Qué encontraste en ${station.code}?',
                options: station.findings,
              );
              if (option != null) setState(() => _finding = option);
            },
          ),
          const FieldLabel('Estado de la estación', required: true),
          OptionField(
            hint: 'Selecciona el estado',
            text: _condition?.label,
            dotColor: _condition == null
                ? null
                : severityColor(_condition!.severity),
            onTap: () async {
              final option = await pickOption(
                context,
                title: '¿Cómo quedó ${station.code}?',
                options: stationConditions,
              );
              if (option != null) setState(() => _condition = option);
            },
          ),
          const FieldLabel('Plagas detectadas'),
          OptionField(
            hint: 'Ninguna',
            text: _pestsText,
            onTap: () async {
              final ids = await pickManyOptions(
                context,
                title: 'Plagas en ${station.code}',
                options: widget.report.pests,
                selected: _pestIds,
              );
              if (ids != null) setState(() => _pestIds = ids);
            },
          ),
          const FieldLabel('Observaciones'),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 5,
            style: AppTheme.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              hintText:
                  'Lo que valga la pena dejar por escrito de esta estación',
              hintStyle: TextStyle(fontSize: 16, color: AppColors.hint),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.muted,
            ),
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.muted,
                    ),
                  )
                : Text(_isLast ? 'Guardar' : 'Guardar y siguiente'),
          ),
        ),
      ),
    );
  }
}
