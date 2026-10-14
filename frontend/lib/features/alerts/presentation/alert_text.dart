import '../../../core/format/numbers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/alert.dart';

String alertKindLabel(AppLocalizations l, AlertKind kind) => switch (kind) {
  AlertKind.priceAbove => l.alertKindPriceAbove,
  AlertKind.priceBelow => l.alertKindPriceBelow,
  AlertKind.moveUp => l.alertKindMoveUp,
  AlertKind.moveDown => l.alertKindMoveDown,
};

/// "Price goes above $90,000.00" / "Rises 5.00% or more in a day".
String alertDescription(
  AppLocalizations l,
  AlertKind kind,
  double threshold,
  String? currency, {
  bool forex = false,
}) {
  final price = formatPrice(threshold, currency, forex: forex);
  final percent = formatPercent(threshold, signed: false);
  return switch (kind) {
    AlertKind.priceAbove => l.alertDescPriceAbove(price),
    AlertKind.priceBelow => l.alertDescPriceBelow(price),
    AlertKind.moveUp => l.alertDescMoveUp(percent),
    AlertKind.moveDown => l.alertDescMoveDown(percent),
  };
}
