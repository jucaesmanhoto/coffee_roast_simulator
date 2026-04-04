import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RoastChart extends StatelessWidget {
  final List<FlSpot> btPoints;
  final List<FlSpot> rorPoints;

  const RoastChart({
    super.key,
    required this.btPoints,
    required this.rorPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)]),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 260,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.03), strokeWidth: 1),
            getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.03), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("${v.toInt()}m", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (v, meta) => Text("${v.toInt()}°", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Linha de Temperatura (BT)
            LineChartBarData(
              spots: btPoints,
              isCurved: true,
              color: Colors.orangeAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.orangeAccent.withValues(alpha: 0.05)),
            ),
            // Linha de RoR
            LineChartBarData(
              spots: rorPoints,
              isCurved: true,
              color: Colors.cyanAccent.withValues(alpha: 0.6),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
