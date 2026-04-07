import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RoastChart extends StatelessWidget {
  final List<FlSpot> btPoints;
  final List<FlSpot> rorPoints;
  final int? turningPointTime; // Tempo em segundos do TP

  const RoastChart({
    super.key,
    required this.btPoints,
    required this.rorPoints,
    this.turningPointTime,
  });

  @override
  Widget build(BuildContext context) {
    List<VerticalLine> buildExtraLines() {
      if (turningPointTime == null) {
        return [];
      }
      final double timeInMinutes = turningPointTime! / 60.0;
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

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)]),
      child: LineChart(LineChartData(
          // Linhas verticais para eventos
          extraLinesData: ExtraLinesData(
            verticalLines: buildExtraLines(),
          ),

          // Configuração dos limites dos eixos
          minX: 0,
          maxX: 16, // Limite de 16 minutos
          minY: 0,
          maxY: 250, // Limite de 250°C para o eixo esquerdo (BT)

          // Linhas de grade
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.15), strokeWidth: 1),
            getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.15), strokeWidth: 1),
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
                  // Converte o valor do eixo Y (0-250) para a escala do RoR (0-25)
                  final rorValue = value * (25 / 250);
                  // Mostra rótulos que correspondam a múltiplos de 5 na escala do RoR
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
              // Mapeia os valores do RoR para a escala do eixo Y principal (0-250)
              spots: rorPoints.map((spot) => FlSpot(spot.x, spot.y * (250 / 25))).toList(),
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
