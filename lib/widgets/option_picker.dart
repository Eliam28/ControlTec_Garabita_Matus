import 'package:flutter/material.dart';

import '../models/report_context.dart';
import '../theme/app_theme.dart';

/// Color del punto de cada opción: verde si está bien, ámbar si es un aviso
/// y rojo si es grave.
Color severityColor(int severity) => switch (severity) {
  0 => const Color(0xFF22A45D),
  1 || 2 => const Color(0xFFF59E0B),
  _ => AppColors.error,
};

/// Campo que parece un desplegable: enseña lo elegido o [hint].
/// Al tocarlo se abre una hoja desde abajo ([onTap]).
class OptionField extends StatelessWidget {
  const OptionField({
    required this.hint,
    required this.onTap,
    this.text,
    this.dotColor,
    super.key,
  });

  final String hint;
  final String? text;
  final Color? dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: dotColor?.withValues(alpha: 0.08) ?? AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: dotColor ?? AppColors.border, width: 1.5),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            if (dotColor != null) ...[
              _Dot(dotColor!),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                text ?? hint,
                style: AppTheme.body.copyWith(
                  color: text == null ? AppColors.hint : AppColors.text,
                  fontWeight: dotColor == null ? null : FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

/// Hoja para elegir una sola opción. Devuelve la elegida o null si se cierra.
Future<Option?> pickOption(
  BuildContext context, {
  required String title,
  required List<Option> options,
}) => showModalBottomSheet<Option>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.white,
  builder: (context) => _Sheet(
    title: title,
    children: [
      for (final option in options)
        _OptionTile(
          label: option.label,
          leading: _Dot(severityColor(option.severity)),
          onTap: () => Navigator.of(context).pop(option),
        ),
    ],
  ),
);

/// Hoja para marcar varias opciones (las plagas). Devuelve los id marcados
/// al tocar «Listo», o null si se cierra sin confirmar.
Future<List<String>?> pickManyOptions(
  BuildContext context, {
  required String title,
  required List<Option> options,
  required List<String> selected,
}) {
  final marked = {...selected};
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => _Sheet(
        title: title,
        footer: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
          onPressed: () => Navigator.of(context).pop(marked.toList()),
          child: const Text('Listo'),
        ),
        children: [
          for (final option in options)
            _OptionTile(
              label: option.label,
              leading: Icon(
                marked.contains(option.id)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: AppColors.primary,
              ),
              onTap: () => setSheetState(() {
                if (!marked.remove(option.id)) marked.add(option.id);
              }),
            ),
        ],
      ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // Que no tape toda la pantalla aunque haya muchas opciones.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTheme.cardTitle)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(child: ListView(shrinkWrap: true, children: children)),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: leading,
        minLeadingWidth: 0,
        title: Text(
          label,
          style: AppTheme.body.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
