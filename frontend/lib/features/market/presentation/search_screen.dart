import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/market_api.dart';
import '../domain/market.dart';
import 'widgets/asset_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _timer;
  String _query = '';
  List<Asset>? _results;
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(marketApiProvider).search(query);
      if (!mounted || id != _requestId) return; // a newer search started
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = apiErrorMessage(e, AppLocalizations.of(context)));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = _results;

    Widget body;
    if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorText(_error),
      );
    } else if (results == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.searchPrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (results.isEmpty && !_loading) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.searchEmpty(_query), textAlign: TextAlign.center),
      );
    } else {
      body = ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => AssetTile(
          asset: results[i],
          onTap: () => context.go('/assets/${results[i].id}'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            _timer?.cancel();
            if (v.trim().isNotEmpty) _search(v.trim());
          },
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: body,
        ),
      ),
    );
  }
}
