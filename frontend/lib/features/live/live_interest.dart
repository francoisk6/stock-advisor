import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_controller.dart';

/// Declares that [child] shows these assets, so their prices update live while visible.
class LiveInterest extends ConsumerStatefulWidget {
  const LiveInterest({
    super.key,
    required this.name,
    required this.assetIds,
    required this.child,
  });

  final String name;
  final Iterable<int> assetIds;
  final Widget child;

  @override
  ConsumerState<LiveInterest> createState() => _LiveInterestState();
}

class _LiveInterestState extends ConsumerState<LiveInterest> {
  late final LiveController _live = ref.read(liveControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // After the frame: providers must not be modified while widgets build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mounted ? _live.setInterest(widget.name, widget.assetIds) : null,
    );
  }

  @override
  void didUpdateWidget(LiveInterest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIds(oldWidget.assetIds, widget.assetIds)) {
      _live.setInterest(widget.name, widget.assetIds);
    }
  }

  @override
  void dispose() {
    _live.clearInterest(widget.name);
    super.dispose();
  }

  bool _sameIds(Iterable<int> a, Iterable<int> b) =>
      a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

  @override
  Widget build(BuildContext context) => widget.child;
}
