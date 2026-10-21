import 'package:flutter/material.dart';

import '../../../../core/format/numbers.dart';

/// Up/down colors that stay readable in light and dark themes.
Color changeColor(BuildContext context, double? value) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (value == null || value == 0) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  if (value > 0) {
    return dark ? const Color(0xFF6DD58C) : const Color(0xFF1B7F3B);
  }
  return dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
}

/// "▲ +1.23%" (or "▲ +$12.30 (+1.23%)" with [amount]) — arrow + sign, so the direction
/// never depends on color alone.
class PriceChange extends StatelessWidget {
  const PriceChange({
    super.key,
    required this.percent,
    this.style,
    this.amount,
  });

  final double? percent;
  final TextStyle? style;

  /// Signed money text shown before the percent, e.g. "+$12.30".
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    final color = changeColor(context, value);
    final textStyle = (style ?? Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w600);
    if (value == null) return Text('—', style: textStyle);
    final icon = value > 0
        ? Icons.arrow_drop_up
        : value < 0
        ? Icons.arrow_drop_down
        : Icons.remove;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: (textStyle?.fontSize ?? 14) + 6),
        Text(
          amount == null
              ? formatPercent(value)
              : '$amount (${formatPercent(value)})',
          style: textStyle,
        ),
      ],
    );
  }
}
