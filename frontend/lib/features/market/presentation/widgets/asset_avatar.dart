import 'package:flutter/material.dart';

import '../../domain/market.dart';

/// Coin logo when we have one, otherwise the symbol's first letters.
class AssetAvatar extends StatelessWidget {
  const AssetAvatar({super.key, required this.asset, this.radius = 20});

  final Asset asset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final letters = _letters(asset);
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colors.secondaryContainer,
      child: Text(
        letters,
        style: TextStyle(
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w600,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
    final logo = asset.logoUrl;
    // Decorative: the name next to it is what screen readers should announce.
    if (logo == null) return ExcludeSemantics(child: fallback);
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.network(
          logo,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}

/// "BTC" for Bitcoin; numeric tickers like 2222.SR use the name's initials ("SA").
String _letters(Asset asset) {
  final symbol = asset.symbol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (symbol.isNotEmpty && !RegExp(r'^\d').hasMatch(symbol)) {
    return symbol.substring(0, symbol.length.clamp(0, 3));
  }
  final words = asset.name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(w))
      .toList();
  if (words.isEmpty) return symbol.substring(0, symbol.length.clamp(0, 3));
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
