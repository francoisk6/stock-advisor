import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../market/domain/market.dart';
import '../data/practice_api.dart';
import '../domain/practice.dart';

/// Buy or sell with practice money: dollars or units, with a live preview.
class TradeSheet extends ConsumerStatefulWidget {
  const TradeSheet({super.key, required this.asset, required this.side});

  final Asset asset;
  final String side; // buy | sell

  static Future<void> show(BuildContext context, Asset asset, String side) =>
      showModalBottomSheet<void>(
        useRootNavigator: true, // above the tab bar
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => TradeSheet(asset: asset, side: side),
      );

  @override
  ConsumerState<TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends ConsumerState<TradeSheet> {
  final _amount = TextEditingController();
  late bool _inDollars = widget.side == 'buy';
  bool _sellAll = false;
  bool _busy = false;
  String? _error;

  bool get _buy => widget.side == 'buy';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.replaceAll(',', ''));

  /// Client-side check with the preview's numbers; the server checks again.
  String? _validate(AppLocalizations l10n, PracticeQuote q) {
    final value = _value;
    if (value == null || value <= 0) return l10n.tradeErrorAmount;
    final dollars = _inDollars ? value : value * q.usdPrice;
    final units = _inDollars ? value / q.usdPrice : value;
    if (_buy && dollars > q.availableCash + 0.005) {
      return l10n.tradeErrorCash(formatMoney(q.availableCash, 'USD'));
    }
    if (!_buy &&
        !_sellAll &&
        units > q.heldQuantity * (_inDollars ? 1.01 : 1)) {
      return l10n.tradeErrorHeld(formatQuantity(q.heldQuantity));
    }
    return null;
  }

  Future<void> _submit(PracticeQuote q) async {
    final l10n = AppLocalizations.of(context);
    final problem = _validate(l10n, q);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final order = await ref
          .read(practiceProvider.notifier)
          .order(
            assetId: widget.asset.id,
            side: widget.side,
            quantity: _sellAll
                ? q.heldQuantity
                : _inDollars
                ? null
                : _value,
            amountUsd: _inDollars && !_sellAll ? _value : null,
          );
      final symbol = widget.asset.symbol;
      final text = switch (order.status) {
        'filled' => (order.isBuy ? l10n.tradeBought : l10n.tradeSold)(
          formatQuantity(order.filledQuantity!),
          symbol,
          formatMoney(order.totalUsd!, 'USD'),
        ),
        'pending' => l10n.tradeWaiting,
        _ => order.note ?? l10n.statusRejected,
      };
      navigator.pop();
      showSnack(messenger, text);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = apiErrorMessage(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quote = ref.watch(practiceQuoteProvider(widget.asset.id));
    final symbol = widget.asset.symbol;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _buy ? l10n.tradeBuyTitle(symbol) : l10n.tradeSellTitle(symbol),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...quote.when(
                loading: () => [
                  const Center(child: CircularProgressIndicator()),
                ],
                error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                data: (q) => _form(l10n, theme, q),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n, ThemeData theme, PracticeQuote q) {
    final symbol = widget.asset.symbol;
    final value = _value;
    final forex = widget.asset.assetType == 'forex';
    String? estimate;
    if (value != null && value > 0) {
      estimate = _inDollars
          ? l10n.tradeEstimateUnits(formatQuantity(value / q.usdPrice), symbol)
          : l10n.tradeEstimateCost(formatMoney(value * q.usdPrice, 'USD'));
    }
    return [
      Text(
        q.currency == 'USD'
            ? l10n.tradePrice(formatPrice(q.price, 'USD', forex: forex))
            : l10n.tradePriceConverted(
                formatPrice(q.price, q.currency, forex: forex),
                formatPrice(q.usdPrice, 'USD'),
              ),
      ),
      Text(
        _buy
            ? l10n.tradeAvailable(formatMoney(q.availableCash, 'USD'))
            : l10n.tradeHeld(formatQuantity(q.heldQuantity), symbol),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: true, label: Text(l10n.tradeInDollars)),
          ButtonSegment(value: false, label: Text(l10n.tradeInUnits)),
        ],
        selected: {_inDollars},
        onSelectionChanged: (selection) => setState(() {
          _inDollars = selection.first;
          _sellAll = false;
          _amount.clear();
          _error = null;
        }),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: _inDollars ? l10n.tradeAmountLabel : l10n.tradeUnitsLabel,
          prefixText: _inDollars ? r'$ ' : null,
          border: const OutlineInputBorder(),
          suffixIcon: _buy || q.heldQuantity <= 0
              ? null
              : TextButton(
                  onPressed: () => setState(() {
                    _inDollars = false;
                    _sellAll = true;
                    _amount.text = formatQuantity(
                      q.heldQuantity,
                    ).replaceAll(',', '');
                    _error = null;
                  }),
                  child: Text(l10n.tradeSellAll),
                ),
        ),
        onChanged: (_) => setState(() {
          _sellAll = false;
          _error = null;
        }),
        onSubmitted: (_) => _busy ? null : _submit(q),
      ),
      if (estimate != null) ...[
        const SizedBox(height: 8),
        Text(estimate, style: theme.textTheme.bodyMedium),
      ],
      if (!q.marketOpen) ...[
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.tradeClosed)),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      ErrorText(_error),
      BusyButton(
        busy: _busy,
        onPressed: () => _submit(q),
        label: _buy ? l10n.tradeConfirmBuy : l10n.tradeConfirmSell,
      ),
      const SizedBox(height: 8),
      Text(
        l10n.tradeNote,
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ];
  }
}
