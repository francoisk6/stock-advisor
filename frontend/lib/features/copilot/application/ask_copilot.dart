import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'copilot_controller.dart';

/// Starts a fresh chat with [question] (and the asset as context) and opens the copilot.
void askCopilot(BuildContext context, String question, {int? assetId}) {
  ProviderScope.containerOf(
      context,
      listen: false,
    ).read(copilotControllerProvider.notifier)
    ..newConversation()
    ..send(question, assetId: assetId);
  context.go(assetId == null ? '/copilot' : '/copilot?asset=$assetId');
}
