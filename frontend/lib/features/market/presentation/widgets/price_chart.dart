import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/numbers.dart';
import '../../domain/market.dart';
import 'price_change.dart';

enum ChartMode { line, candles }

/// Price chart for one range. Candles are evenly spaced (no gaps for nights/weekends).
class PriceChart extends StatelessWidget {
  const PriceChart({
    super.key,
    required this.history,
    required this.mode,
    this.forex = false,
  });

  final PriceHistory history;
  final ChartMode mode;
  final bool forex;

  String _timeLabel(DateTime utc) {
    final t = utc.toLocal();
    return switch (history.range) {
      '1D' => DateFormat.Hm().format(t),
      '1W' => DateFormat.MMMd().add_Hm().format(t),
      '1M' || '6M' => DateFormat.MMMd().format(t),
      _ => DateFormat.yMMM().format(t),
    };
  }

  @override
  Widget build(BuildContext context) {
    final candles = history.candles;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trend = changeColor(context, history.changePercent);

    var minY = candles.map((c) => c.low).reduce(math.min);
    var maxY = candles.map((c) => c.high).reduce(math.max);
    final pad = (maxY - minY) * 0.08;
    minY -= pad == 0 ? minY.abs() * 0.01 + 1e-9 : pad;
    maxY += pad == 0 ? maxY.abs() * 0.01 + 1e-9 : pad;
    final maxX = (candles.length - 1).toDouble();
    final labelStep = math.max(1, (maxX / 3).floor());

    String price(double v) => formatPrice(v, history.currency, forex: forex);

    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      leftTitles: const AxisTitles(),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 64,
          interval: (maxY - minY) / 3,
          getTitlesWidget: (value, meta) {
            if (value == meta.min || value == meta.max) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(
                formatCompactPrice(value),
                style: textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: labelStep.toDouble(),
          getTitlesWidget: (value, meta) {
            final i = value.round();
            // fl_chart also asks for a label at the very end; skipping it avoids two
            // labels drawn on top of each other.
            if (i < 0 ||
                i >= candles.length ||
                value != i.toDouble() ||
                i % labelStep != 0) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(
                _timeLabel(candles[i].time),
                style: textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
    final grid = FlGridData(
      drawVerticalLine: false,
      horizontalInterval: (maxY - minY) / 3,
      getDrawingHorizontalLine: (_) => FlLine(
        color: colors.outlineVariant.withValues(alpha: 0.5),
        strokeWidth: 1,
      ),
    );
    final tooltipColor = colors.inverseSurface;
    final tooltipStyle = TextStyle(
      color: colors.onInverseSurface,
      fontSize: 12,
    );

    if (mode == ChartMode.candles) {
      final up = changeColor(context, 1);
      final down = changeColor(context, -1);
      return CandlestickChart(
        CandlestickChartData(
          minX: -0.5,
          maxX: maxX + 0.5,
          minY: minY,
          maxY: maxY,
          titlesData: titles,
          gridData: grid,
          borderData: FlBorderData(show: false),
          candlestickSpots: [
            for (var i = 0; i < candles.length; i++)
              CandlestickSpot(
                x: i.toDouble(),
                open: candles[i].open,
                high: candles[i].high,
                low: candles[i].low,
                close: candles[i].close,
              ),
          ],
          candlestickPainter: DefaultCandlestickPainter(
            candlestickStyleProvider: (spot, index) {
              final color = spot.close >= spot.open ? up : down;
              return CandlestickStyle(
                lineColor: color,
                lineWidth: 1,
                bodyStrokeColor: color,
                bodyStrokeWidth: 1,
                bodyFillColor: color,
                bodyWidth: math.max(2, math.min(10, 280 / candles.length)),
                bodyRadius: 1,
              );
            },
          ),
          candlestickTouchData: CandlestickTouchData(
            touchTooltipData: CandlestickTouchTooltipData(
              getTooltipColor: (_) => tooltipColor,
              getTooltipItems: (painter, spot, index) => CandlestickTooltipItem(
                '${_timeLabel(candles[index].time)}\n'
                'O ${price(spot.open)}  H ${price(spot.high)}\n'
                'L ${price(spot.low)}  C ${price(spot.close)}',
                textStyle: tooltipStyle,
              ),
            ),
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        titlesData: titles,
        gridData: grid,
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tooltipColor,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${price(s.y)}\n${_timeLabel(candles[s.x.round()].time)}',
                  tooltipStyle,
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < candles.length; i++)
                FlSpot(i.toDouble(), candles[i].close),
            ],
            color: trend,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  trend.withValues(alpha: 0.25),
                  trend.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short axis labels: 83338 -> "83.3K", 25.78 -> "25.78".
String formatCompactPrice(double value) =>
    value.abs() >= 10000 ? formatCompact(value) : formatNumber(value);
