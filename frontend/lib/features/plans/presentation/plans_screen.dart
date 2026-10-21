import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../data/plans_api.dart';
import '../domain/plans.dart';

String usageLabel(AppLocalizations l, String key) => switch (key) {
  'ai_messages_per_day' => l.usageAi,
  'watchlist_assets' => l.usageWatchlist,
  'alerts' => l.usageAlerts,
  'portfolio_holdings' => l.usageHoldings,
  _ => key,
};

String limitText(AppLocalizations l, String key, int? limit) => limit == null
    ? l.limitUnlimited
    : key == 'ai_messages_per_day'
    ? l.limitPerDay(limit)
    : l.limitUpTo(limit);

/// Your plan and usage, Free vs Pro, and "tell me when Pro is ready".
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(usageProvider);
    final plans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plansTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...usage.when(
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                data: (u) => [_Usage(usage: u)],
              ),
              const SizedBox(height: 24),
              ...plans.when(
                loading: () => [const SizedBox.shrink()],
                error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                data: (p) => [
                  _Compare(plans: p),
                  const SizedBox(height: 16),
                  _ProSoon(
                    pro: p.where((x) => x.code == 'pro').firstOrNull,
                    interested: usage.value?.proInterest ?? false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      container: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _Usage extends StatelessWidget {
  const _Usage({required this.usage});

  final PlanUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.plansCurrent(usage.planName),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _Header(l10n.plansUsageTitle),
        for (final item in usage.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(usageLabel(l10n, item.key))),
                    Text(
                      item.limit == null
                          ? l10n.usageNoLimit(item.used)
                          : l10n.usageOf(item.used, item.limit!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (item.limit != null) ...[
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: item.limit == 0
                          ? 1
                          : (item.used / item.limit!).clamp(0, 1).toDouble(),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One row per limit: Free value vs Pro value (text, so screen readers read it as a list).
class _Compare extends StatelessWidget {
  const _Compare({required this.plans});

  final List<PlanInfo> plans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final keys = plans.isEmpty ? const <String>[] : plans.first.limits.keys;
    final bold = theme.textTheme.titleSmall;
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(l10n.plansCompare),
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox.shrink()),
                for (final p in plans)
                  Expanded(flex: 2, child: Text(p.name, style: bold)),
              ],
            ),
            const Divider(),
            for (final key in keys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(usageLabel(l10n, key))),
                    for (final p in plans)
                      Expanded(
                        flex: 2,
                        child: Text(limitText(l10n, key, p.limits[key])),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox.shrink()),
                for (final p in plans)
                  Expanded(
                    flex: 2,
                    child: Text(
                      (p.priceMonthlyUsd ?? 0) == 0
                          ? l10n.plansFreePrice
                          : '${formatMoney(p.priceMonthlyUsd!, 'USD')}\n'
                                '${formatMoney(p.priceYearlyUsd!, 'USD')}',
                      style: bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProSoon extends ConsumerStatefulWidget {
  const _ProSoon({required this.pro, required this.interested});

  final PlanInfo? pro;
  final bool interested;

  @override
  ConsumerState<_ProSoon> createState() => _ProSoonState();
}

class _ProSoonState extends ConsumerState<_ProSoon> {
  bool _busy = false;

  Future<void> _notify() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(plansApiProvider).proInterest();
      ref.invalidate(usageProvider);
      showSnack(messenger, l10n.plansNotified);
    } catch (e) {
      showSnack(messenger, apiErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pro = widget.pro;
    if (pro == null ||
        pro.priceMonthlyUsd == null ||
        pro.priceYearlyUsd == null) {
      return const SizedBox.shrink();
    }
    final monthly = pro.priceMonthlyUsd!;
    final yearly = pro.priceYearlyUsd!;
    final saving = monthly > 0 ? (1 - yearly / (monthly * 12)) * 100 : 0.0;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(pro.name),
            Text(
              l10n.plansPrice(
                formatMoney(monthly, 'USD'),
                formatMoney(yearly, 'USD'),
              ),
              style: theme.textTheme.titleMedium,
            ),
            if (saving >= 1)
              Text(
                l10n.plansSave(
                  formatPercent(
                    saving.roundToDouble(),
                    signed: false,
                  ).replaceAll('.00', ''),
                ),
              ),
            const SizedBox(height: 8),
            if (!pro.forSale) Text(l10n.plansProSoon),
            const SizedBox(height: 12),
            if (widget.interested)
              Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.plansNotified)),
                ],
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(l10n.plansNotify),
                onPressed: _busy ? null : _notify,
              ),
          ],
        ),
      ),
    );
  }
}
