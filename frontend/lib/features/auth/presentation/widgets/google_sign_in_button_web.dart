import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

import '../../data/google_sign_in_service.dart';

/// Google's own "Continue with Google" button (required on web). Sign-ins arrive as events.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onIdToken,
    required this.onError,
  });

  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  late final Future<void> _ready;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;

  @override
  void initState() {
    super.initState();
    final service = ref.read(googleSignInServiceProvider);
    _ready = service.ensureInitialized().then((_) {
      _events = service.events.listen(_onEvent, onError: widget.onError);
    });
  }

  void _onEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final token = event.user.authentication.idToken;
      if (token != null) widget.onIdToken(token).catchError(widget.onError);
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 44);
        }
        return Center(
          child: gsi.renderButton(
            configuration: gsi.GSIButtonConfiguration(
              text: gsi.GSIButtonText.continueWith,
              shape: gsi.GSIButtonShape.pill,
              size: gsi.GSIButtonSize.large,
              minimumWidth: 320,
              locale: Localizations.localeOf(context).languageCode,
            ),
          ),
        );
      },
    );
  }
}
