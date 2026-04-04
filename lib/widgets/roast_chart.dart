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
      child: LineChart(LineChartData(
          // Configuração dos limites dos eixos
          minX: 0,
          maxX: 16, // Limite de 16 minutos
          minY: 0,
          maxY: 230, // Limite de 230°C para o eixo esquerdo (BT)

          // Linhas de grade
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
            getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
          ),

          // Títulos dos eixos
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            // Eixo X (Inferior - Tempo)
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
            // Eixo Y Esquerdo (BT)
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (v, meta) => Text("${v.toInt()}°", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            // Eixo Y Direito (RoR)
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  // Converte o valor da escala do eixo esquerdo para a escala do eixo direito
                  final rorValue = value * (25 / 230);
                  if (rorValue % 5 != 0) return const SizedBox(); // Mostra apenas múltiplos de 5
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
            // Linha de Temperatura (BT)
            LineChartBarData(
              spots: btPoints,
              isCurved: true,
              color: Colors.orange,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.orange.withValues(alpha: 0.1)),
            ),
            // Linha de RoR
            LineChartBarData(
              // Mapeia os valores do RoR para a escala do eixo Y principal (0-230)
              spots: rorPoints.map((spot) => FlSpot(spot.x, spot.y * (230 / 25))).toList(),
              isCurved: true,
              color: Colors.cyanAccent.withValues(alpha: 0.8),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        )),
    );
  }
}
