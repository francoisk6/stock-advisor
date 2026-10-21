import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../market/domain/market.dart';
import '../data/alerts_api.dart';
import '../domain/alert.dart';
import 'alert_text.dart';

/// Bottom sheet to create an alert, prefilled with sensible values around today's price.
class CreateAlertSheet extends ConsumerStatefulWidget {
  const CreateAlertSheet({super.key, required this.asset, required this.price});

  final Asset asset;
  final double? price;

  static Future<bool?> show(BuildContext context, Asset asset, double? price) =>
      showModalBottomSheet<bool>(
        useRootNavigator: true, // above the tab bar
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CreateAlertSheet(asset: asset, price: price),
      );

  @override
  ConsumerState<CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<CreateAlertSheet> {
  final _formKey = GlobalKey<FormState>();
  final _threshold = TextEditingController();
  AlertKind _kind = AlertKind.priceAbove;
  bool _email = true;
  bool _busy = false;
  String? _error;

  bool get _forex => widget.asset.assetType == 'forex';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  /// Price alerts start 5% away from today's price; move alerts at 5%.
  void _prefill() {
    final price = widget.price;
    if (_kind.isPrice && price != null) {
      final target = price * (_kind == AlertKind.priceAbove ? 1.05 : 0.95);
      final digits = _forex
          ? 4
          : target >= 1
          ? 2
          : 6;
      _threshold.text = target.toStringAsFixed(digits);
    } else if (!_kind.isPrice) {
      _threshold.text = '5';
    } else {
      _threshold.clear();
    }
  }

  double? get _value => double.tryParse(_threshold.text.replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(alertsApiProvider)
          .create(
            assetId: widget.asset.id,
            kind: _kind,
            threshold: _value!,
            notifyEmail: _email,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(e, AppLocalizations.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final verified =
        ref.watch(
          authControllerProvider.select((s) => s.user?.emailVerified),
        ) ??
        false;
    final currency = widget.asset.quote?.currency ?? widget.asset.currency;
    final value = _value;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.alertCreate} · ${widget.asset.symbol}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(l10n.alertsIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            RadioGroup<AlertKind>(
              groupValue: _kind,
              onChanged: (kind) => setState(() {
                _kind = kind!;
                _prefill();
              }),
              child: Column(
                children: [
                  for (final kind in AlertKind.values)
                    RadioListTile<AlertKind>(
                      value: kind,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(alertKindLabel(l10n, kind)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _kind.isPrice
                    ? '${l10n.alertTargetPrice}${currency == null ? '' : ' ($currency)'}'
                    : l10n.alertDailyMove,
                helperText: _kind.isPrice && widget.price != null
                    ? l10n.alertCurrentPrice(
                        formatPrice(widget.price!, currency, forex: _forex),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              validator: (_) =>
                  (_value ?? 0) > 0 ? null : l10n.alertThresholdInvalid,
            ),
            if (value != null && value > 0) ...[
              const SizedBox(height: 12),
              Text(
                alertDescription(l10n, _kind, value, currency, forex: _forex),
                style: theme.textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _kind.isPrice ? l10n.alertOneShotNote : l10n.alertMoveNote,
              style: theme.textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _email && verified,
              onChanged: verified ? (v) => setState(() => _email = v) : null,
              title: Text(l10n.alertEmail),
              subtitle: verified ? null : Text(l10n.alertEmailUnverified),
            ),
            const SizedBox(height: 8),
            ErrorText(_error),
            BusyButton(label: l10n.alertCreate, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
