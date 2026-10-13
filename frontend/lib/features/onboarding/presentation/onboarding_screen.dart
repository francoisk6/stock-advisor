import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/data/user_api.dart';
import 'profile_options.dart';

/// 5-step quiz that personalizes the copilot. Also used to edit answers later ([editing]).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 5;

  int _step = 0;
  String? _experience;
  String? _risk;
  String? _horizon;
  final Set<String> _assets = {};
  final Set<String> _regions = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider).user?.profile;
    if (profile != null) {
      _experience = profile.experienceLevel;
      _risk = profile.riskProfile;
      _horizon = profile.investmentHorizon;
      _assets.addAll(profile.assetInterests);
      _regions.addAll(profile.regionInterests);
    }
  }

  bool get _canContinue => switch (_step) {
    0 => _experience != null,
    1 => _risk != null,
    2 => _horizon != null,
    3 => _assets.isNotEmpty,
    _ => _regions.isNotEmpty,
  };

  Future<void> _next() async {
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = ref.read(authControllerProvider).user?.profile;
      final user = await ref
          .read(userApiProvider)
          .updateProfile(
            ProfileAnswers(
              experienceLevel: _experience!,
              riskProfile: _risk!,
              investmentHorizon: _horizon!,
              assetInterests: _assets.toList(),
              regionInterests: _regions.toList(),
              preferredLanguage: current?.preferredLanguage ?? 'en',
              preferredCurrency: current?.preferredCurrency ?? 'USD',
            ),
          );
      ref.read(authControllerProvider.notifier).setUser(user);
      if (mounted) context.go(widget.editing ? '/profile' : '/');
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

    final (question, options, multi) = switch (_step) {
      0 => (l10n.onboardingExperienceQuestion, experienceOptions(l10n), false),
      1 => (l10n.onboardingRiskQuestion, riskOptions(l10n), false),
      2 => (l10n.onboardingHorizonQuestion, horizonOptions(l10n), false),
      3 => (l10n.onboardingAssetsQuestion, assetOptions(l10n), true),
      _ => (l10n.onboardingRegionsQuestion, regionOptions(l10n), true),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing ? l10n.onboardingEditTitle : l10n.onboardingTitle,
        ),
        automaticallyImplyLeading: false,
        leading: widget.editing
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/profile'),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: (_step + 1) / _steps),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        l10n.onboardingStepOf(_step + 1, _steps),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(question, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        multi ? l10n.onboardingMultiHint : l10n.onboardingWhy,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final option in options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OptionTile(
                            option: option,
                            multi: multi,
                            selected: _isSelected(option.code),
                            onTap: () => _toggle(option.code),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ErrorText(_error),
                      Row(
                        children: [
                          if (_step > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 12,
                              ),
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _step--),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                child: Text(l10n.onboardingBack),
                              ),
                            ),
                          Expanded(
                            child: BusyButton(
                              label: _step == _steps - 1
                                  ? l10n.onboardingFinish
                                  : l10n.onboardingNext,
                              busy: _busy,
                              onPressed: _canContinue ? _next : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSelected(String code) => switch (_step) {
    0 => _experience == code,
    1 => _risk == code,
    2 => _horizon == code,
    3 => _assets.contains(code),
    _ => _regions.contains(code),
  };

  void _toggle(String code) {
    setState(() {
      switch (_step) {
        case 0:
          _experience = code;
        case 1:
          _risk = code;
        case 2:
          _horizon = code;
        case 3:
          _assets.contains(code) ? _assets.remove(code) : _assets.add(code);
        default:
          _regions.contains(code) ? _regions.remove(code) : _regions.add(code);
      }
    });
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.multi,
    required this.selected,
    required this.onTap,
  });

  final ProfileOption option;
  final bool multi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(option.icon, color: selected ? colors.primary : null),
        title: Text(option.title),
        subtitle: option.description.isEmpty ? null : Text(option.description),
        // Decorative: the tile itself announces "selected" to screen readers.
        trailing: ExcludeSemantics(
          child: Icon(
            multi
                ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                : (selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
            color: selected ? colors.primary : null,
          ),
        ),
        selected: selected,
      ),
    );
  }
}
