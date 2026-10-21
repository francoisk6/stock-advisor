import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../market/data/market_api.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/labels.dart';
import '../../market/presentation/widgets/asset_avatar.dart';
import '../data/portfolio_api.dart';
import '../domain/portfolio.dart';

String _plain(double value) => formatQuantity(value).replaceAll(',', '');

/// Add an asset to the portfolio, or edit / remove a holding.
class HoldingSheet extends ConsumerStatefulWidget {
  const HoldingSheet({super.key, required this.asset, this.holding});

  final Asset asset;
  final Holding? holding; // null: adding

  static Future<void> show(
    BuildContext context,
    Asset asset, {
    Holding? holding,
  }) => showModalBottomSheet<void>(
    useRootNavigator: true, // above the tab bar
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => HoldingSheet(asset: asset, holding: holding),
  );

  @override
  ConsumerState<HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends ConsumerState<HoldingSheet> {
  late final _quantity = TextEditingController(
    text: widget.holding == null ? '' : _plain(widget.holding!.quantity),
  );
  late final _price = TextEditingController(
    text: widget.holding != null
        ? _plain(widget.holding!.averagePrice)
        : widget.asset.quote == null
        ? ''
        : _plain(widget.asset.quote!.price),
  );
  late final _note = TextEditingController(text: widget.holding?.note ?? '');
  late DateTime? _boughtOn = widget.holding?.boughtOn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', ''));

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final quantity = _number(_quantity);
    final price = _number(_price);
    if (quantity == null || quantity <= 0) {
      setState(() => _error = l10n.holdingErrorQuantity);
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = l10n.holdingErrorPrice);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(portfolioProvider.notifier);
    try {
      if (widget.holding == null) {
        await controller.add(
          assetId: widget.asset.id,
          quantity: quantity,
          averagePrice: price,
          boughtOn: _boughtOn,
          note: _note.text,
        );
      } else {
        await controller.edit(
          widget.holding!.id,
          quantity: quantity,
          averagePrice: price,
          boughtOn: _boughtOn,
          note: _note.text,
        );
      }
      navigator.pop();
      showSnack(messenger, l10n.holdingSaved);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = apiErrorMessage(e, l10n);
      });
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final symbol = widget.asset.symbol;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.holdingDeleteConfirm(symbol)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.holdingDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(portfolioProvider.notifier).remove(widget.holding!.id);
      navigator.pop();
      showSnack(messenger, l10n.holdingRemoved(symbol));
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asset = widget.asset;
    final currency =
        widget.holding?.currency ??
        asset.quote?.currency ??
        asset.currency ??
        'USD';
    final alreadyHeld =
        widget.holding == null &&
        ref.watch(portfolioProvider).value?.holdingOf(asset.id) != null;
    final number = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const decimal = TextInputType.numberWithOptions(decimal: true);

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
                widget.holding == null
                    ? l10n.holdingAddTitle(asset.symbol)
                    : l10n.holdingEditTitle(asset.symbol),
                style: theme.textTheme.titleLarge,
              ),
              if (alreadyHeld) ...[
                const SizedBox(height: 8),
                Text(l10n.holdingAddMore(asset.symbol)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _quantity,
                autofocus: widget.holding == null,
                keyboardType: decimal,
                inputFormatters: number,
                decoration: InputDecoration(
                  labelText: l10n.holdingQuantity,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: decimal,
                inputFormatters: number,
                decoration: InputDecoration(
                  labelText: l10n.holdingAveragePrice(currency),
                  helperText: l10n.holdingAveragePriceHelp,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  _boughtOn == null
                      ? l10n.holdingBoughtOn
                      : DateFormat.yMMMd().format(_boughtOn!),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _boughtOn ?? DateTime.now(),
                    firstDate: DateTime(1970),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _boughtOn = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.holdingNote,
                  border: const OutlineInputBorder(),
                ),
              ),
              ErrorText(_error),
              BusyButton(busy: _busy, onPressed: _save, label: l10n.save),
              if (widget.holding != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.holdingDelete),
                  onPressed: _busy ? null : _remove,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Search for the asset to add, then open [HoldingSheet] for it.
class AssetPickerSheet extends ConsumerStatefulWidget {
  const AssetPickerSheet({super.key});

  static Future<Asset?> pick(BuildContext context) =>
      showModalBottomSheet<Asset>(
        useRootNavigator: true, // above the tab bar
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const AssetPickerSheet(),
      );

  @override
  ConsumerState<AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends ConsumerState<AssetPickerSheet> {
  Timer? _debounce;
  List<Asset> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final query = text.trim();
    if (query.length < 2) return;
    setState(() => _searching = true);
    try {
      final found = await ref.read(marketApiProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = found.where((a) => a.assetType != 'index').toList();
        _searching = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = apiErrorMessage(e, AppLocalizations.of(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.pickAssetTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: l10n.pickAssetHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onChanged,
                ),
              ),
              if (_searching) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorText(_error),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final a in _results)
                      ListTile(
                        leading: AssetAvatar(asset: a),
                        title: Text(a.name),
                        subtitle: Text(assetSubtitle(l10n, a)),
                        onTap: () => Navigator.pop(context, a),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
