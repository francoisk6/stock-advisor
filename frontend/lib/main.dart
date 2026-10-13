import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  // Clean web URLs (/verify-email?token=...) so links in emails work. No-op on mobile.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: StockAdviserApp()));
}
