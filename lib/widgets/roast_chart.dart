import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RoastChart extends StatefulWidget {
  final List<FlSpot> btPoints;
  final List<FlSpot> rorPoints;
  final int? turningPointTime; // Tempo em segundos do TP
  final String stripDryingLine;
  final String stripMaillardLine;
  final String stripPostCrackLine;

  const RoastChart({
    super.key,
    required this.btPoints,
    required this.rorPoints,
    this.turningPointTime,
    required this.stripDryingLine,
    required this.stripMaillardLine,
    required this.stripPostCrackLine,
  });

  @override
  State<RoastChart> createState() => _RoastChartState();
}

class _RoastChartState extends State<RoastChart> {
  Offset? _tooltipOffset;
  List<LineBarSpot> _touchedSpots = const [];

  Widget _buildPhaseStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTooltip(FlTouchEvent event, LineTouchResponse? response) {
    final spots = response?.lineBarSpots ?? const <LineBarSpot>[];
    final localPosition = event.localPosition;

    if (spots.isEmpty || localPosition == null) {
      if (_touchedSpots.isNotEmpty || _tooltipOffset != null) {
        setState(() {
          _touchedSpots = const [];
          _tooltipOffset = null;
        });
      }
      return;
    }

    setState(() {
      _touchedSpots = spots;
      _tooltipOffset = localPosition;
    });
  }

  String _formatTime(double timeInMinutes) {
    final minutes = timeInMinutes.truncate();
    final seconds = ((timeInMinutes - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTooltip(double maxWidth, double maxHeight) {
    if (_tooltipOffset == null || _touchedSpots.isEmpty) {
      return const SizedBox.shrink();
    }

    double? btValue;
    double? rorValue;
    for (final spot in _touchedSpots) {
      if (spot.barIndex == 0) {
        btValue = spot.y;
      } else if (spot.barIndex == 1) {
        rorValue = spot.y / (250 / 25);
      }
    }

    const tooltipWidth = 132.0;
    const tooltipHeight = 74.0;
    final left = (_tooltipOffset!.dx + 14).clamp(8.0, maxWidth - tooltipWidth - 8);
    final top = (_tooltipOffset!.dy - tooltipHeight - 14).clamp(8.0, maxHeight - tooltipHeight - 8);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(_touchedSpots.first.x),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'BT: ${btValue?.toStringAsFixed(1) ?? '--'}°',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'RoR: ${rorValue?.toStringAsFixed(1) ?? '--'}',
                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<VerticalLine> buildExtraLines() {
      if (widget.turningPointTime == null) {
        return [];
      }
      final double timeInMinutes = widget.turningPointTime! / 60.0;
      return [
        VerticalLine(
          x: timeInMinutes,
          color: Colors.purpleAccent.withValues(alpha: 0.5),
          strokeWidth: 2,
          dashArray: [4, 4], // Padrão tracejado: 4 pixels desenhados, 4 pixels vazios
          label: VerticalLineLabel(
            show: true,
            labelResolver: (line) => 'TP',
            alignment: Alignment.topRight,
            style: TextStyle(
              color: Colors.purpleAccent.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 350,
          padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          // We render a custom tooltip overlay, so disable built-in tooltip logic.
                          handleBuiltInTouches: false,
                          touchCallback: _updateTooltip,
                          touchSpotThreshold: 24,
                          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                            final Color indicatorColor =
                                barData.gradient?.colors.first ?? barData.color ?? Colors.white;

                            return spotIndexes.map((spotIndex) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: indicatorColor.withValues(alpha: 0.35),
                                  strokeWidth: 2,
                                ),
                                FlDotData(
                                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                    radius: 5,
                                    color: indicatorColor,
                                    strokeWidth: 2,
                                    strokeColor: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          touchTooltipData: LineTouchTooltipData(
                            tooltipPadding: EdgeInsets.zero,
                            tooltipMargin: 0,
                            getTooltipColor: (_) => Colors.transparent,
                            // Not used when handleBuiltInTouches is false.
                            getTooltipItems: (touchedSpots) => touchedSpots
                                .map((_) => const LineTooltipItem('', TextStyle(fontSize: 0)))
                                .toList(),
                          ),
                        ),
                        extraLinesData: ExtraLinesData(
                          verticalLines: buildExtraLines(),
                        ),
                        minX: 0,
                        maxX: 13,
                        minY: 0,
                        maxY: 250,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.15), strokeWidth: 1),
                          getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.15), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (v, meta) => Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('${v.toInt()}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (v, meta) => Text('${v.toInt()}°', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                final rorValue = value * (25 / 250);
                                if (rorValue.round() % 5 != 0) return const SizedBox();
                                return Text(
                                  rorValue.toInt().toString(),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  textAlign: TextAlign.left,
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: widget.btPoints,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              // fl_chart expects at least one spot when drawing below-bar area.
                              show: widget.btPoints.isNotEmpty,
                              color: Colors.orange.withValues(alpha: 0.1),
                            ),
                          ),
                          LineChartBarData(
                            spots: widget.rorPoints.map((spot) => FlSpot(spot.x, spot.y * (250 / 25))).toList(),
                            isCurved: true,
                            color: Colors.cyanAccent.withValues(alpha: 0.8),
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                    _buildTooltip(constraints.maxWidth - 30, 320),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPhaseStat('SECAGEM', widget.stripDryingLine, Colors.yellowAccent),
                  const SizedBox(width: 8),
                  _buildPhaseStat('MAILLARD', widget.stripMaillardLine, Colors.amberAccent),
                  const SizedBox(width: 8),
                  _buildPhaseStat('PÓS-CRACK', widget.stripPostCrackLine, Colors.deepOrangeAccent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
