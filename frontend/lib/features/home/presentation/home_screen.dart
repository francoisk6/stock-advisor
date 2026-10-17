import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/widgets/verify_email_banner.dart';
import '../../live/live_interest.dart';
import '../../market/data/market_api.dart';
import '../../notifications/data/notifications_api.dart';
import '../../watchlist/data/watchlist_api.dart';
import '../../market/presentation/labels.dart';
import '../../market/presentation/widgets/asset_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _type; // null = all of the user's interests

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final popular = ref.watch(popularAssetsProvider(_type));
    final watchlist = ref.watch(watchlistProvider);
    final unread = ref.watch(notificationsProvider).value?.unreadCount ?? 0;
    final shownIds = {
      ...?watchlist.value?.items.map((a) => a.id),
      ...?popular.value?.map((a) => a.id),
    };
    final filters = interestFilters(l10n, user?.profile.assetInterests ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.copilotTitle,
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.go('/copilot'),
          ),
          IconButton(
            tooltip: unread > 0
                ? '${l10n.notificationsTitle} (${l10n.unreadBadge(unread)})'
                : l10n.notificationsTitle,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            tooltip: l10n.profileTitle,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/copilot'),
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n.copilotAsk),
      ),
      body: LiveInterest(
        name: 'home',
        assetIds: shownIds,
        child: Column(
          children: [
            const VerifyEmailBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(popularAssetsProvider(_type));
                  await ref.read(popularAssetsProvider(_type).future);
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                container: true,
                                child: Text(
                                  user == null
                                      ? l10n.appTitle
                                      : l10n.homeGreeting(user.displayName),
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.homeSubtitle,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              SearchBar(
                                hintText: l10n.searchHint,
                                leading: const Icon(Icons.search),
                                elevation: const WidgetStatePropertyAll(0),
                                onTap: () => context.go('/search'),
                                // Opens the search screen; typing happens there.
                                keyboardType: TextInputType.none,
                              ),
                              const SizedBox(height: 24),
                              Semantics(
                                header: true,
                                container: true,
                                child: Text(
                                  l10n.watchlistTitle,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._watchlistSection(context, watchlist),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 24),
                              Semantics(
                                header: true,
                                container: true,
                                child: Text(
                                  l10n.popularTitle,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              Text(
                                l10n.popularSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (filters.length > 1)
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    ChoiceChip(
                                      label: Text(l10n.filterAll),
                                      selected: _type == null,
                                      onSelected: (_) =>
                                          setState(() => _type = null),
                                    ),
                                    for (final (type, label) in filters)
                                      ChoiceChip(
                                        label: Text(label),
                                        selected: _type == type,
                                        onSelected: (_) =>
                                            setState(() => _type = type),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...popular.when(
                          loading: () => const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ],
                          error: (e, _) => [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  ErrorText(apiErrorMessage(e, l10n)),
                                  OutlinedButton(
                                    onPressed: () => ref.invalidate(
                                      popularAssetsProvider(_type),
                                    ),
                                    child: Text(l10n.retry),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          data: (assets) => assets.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      l10n.popularEmpty,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ]
                              : [
                                  for (final asset in assets)
                                    AssetTile(
                                      asset: asset,
                                      onTap: () =>
                                          context.go('/assets/${asset.id}'),
                                    ),
                                ],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.disclaimer,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _watchlistSection(
    BuildContext context,
    AsyncValue<Watchlist> watchlist,
  ) {
    final l10n = AppLocalizations.of(context);
    return watchlist.when(
      loading: () => const [
        Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorText(apiErrorMessage(e, l10n)),
        ),
      ],
      data: (list) => list.items.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.star_border),
                    title: Text(l10n.watchlistEmpty),
                  ),
                ),
              ),
            ]
          : [
              for (final asset in list.items)
                AssetTile(
                  asset: asset,
                  onTap: () => context.go('/assets/${asset.id}'),
                ),
            ],
    );
  }
}
