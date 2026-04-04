import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const CoffeeRoastApp());
}

class CoffeeRoastApp extends StatelessWidget {
  const CoffeeRoastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Roast Simulator',
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const RoasterScreen(),
    );
  }
}

class RoasterScreen extends StatefulWidget {
  const RoasterScreen({super.key});

  @override
  State<RoasterScreen> createState() => _RoasterScreenState();
}

class _RoasterScreenState extends State<RoasterScreen> {
  // Parâmetros de Simulação
  double beanTemp = 20.0;
  double ambientTemp = 25.0;
  double heatInput = 0.0;
  double airFlow = 20.0;
  double ror = 0.0;
  int seconds = 0;
  bool isRoasting = false;
  Timer? _timer;

  // Dados do Gráfico
  final List<FlSpot> btPoints = [];
  final List<FlSpot> rorPoints = [];

  @override
  void initState() {
    super.initState();
    _resetSimulation();
  }

  void _resetSimulation() {
    setState(() {
      btPoints.clear();
      rorPoints.clear();
      btPoints.add(const FlSpot(0, 20));
      rorPoints.add(const FlSpot(0, 0));
      beanTemp = 20.0;
      ror = 0.0;
      seconds = 0;
      heatInput = 0.0;
      airFlow = 20.0;
    });
  }

  void _startRoast() {
    setState(() {
      _resetSimulation();
      isRoasting = true;
      // Simulação do Charge (Grãos entram no tambor quente)
      beanTemp = 185.0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePhysics();
    });
  }

  void _updatePhysics() {
    if (!mounted) return;

    setState(() {
      seconds++;

      // Lógica de Física do Kaleido M10
      // Fatores de aquecimento e arrefecimento calibrados
      double heatEffect = (heatInput / 100) * 14.5;
      double airCooling = (airFlow / 100) * 5.8;
      double environmentalLoss = (beanTemp - ambientTemp) * 0.018;

      double targetRoR = heatEffect - airCooling - environmentalLoss;

      // Inércia térmica (o tambor demora a responder às mudanças)
      ror = ror + (targetRoR - ror) * 0.12;

      // Atualização da temperatura (RoR é por minuto, dividimos por 60 para segundos)
      beanTemp += (ror / 60);

      double timeInMinutes = seconds / 60;
      btPoints.add(FlSpot(timeInMinutes, beanTemp));

      // RoR escalado para visibilidade no gráfico (fator de 5x)
      rorPoints.add(FlSpot(timeInMinutes, ror * 5));
    });
  }

  void _stopRoast() {
    _timer?.cancel();
    setState(() => isRoasting = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KALEIDO M10 SIMULATOR',
            style: GoogleFonts.oswald(
                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton.icon(
              onPressed: isRoasting ? _stopRoast : _startRoast,
              icon: Icon(
                  isRoasting ? Icons.stop_circle : Icons.play_arrow_rounded,
                  color: isRoasting ? Colors.redAccent : Colors.greenAccent),
              label: Text(isRoasting ? "PARAR" : "INICIAR",
                  style: TextStyle(
                      color: isRoasting ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Área do Gráfico
              Container(
                height: 350,
                padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)
                    ]),
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 260,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (v) => FlLine(
                          color: Colors.white.withValues(alpha: 0.03),
                          strokeWidth: 1),
                      getDrawingVerticalLine: (v) => FlLine(
                          color: Colors.white.withValues(alpha: 0.03),
                          strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, meta) => Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("${v.toInt()}m",
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (v, meta) => Text("${v.toInt()}°",
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
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
                        belowBarData: BarAreaData(
                            show: true,
                            color: Colors.orangeAccent.withValues(alpha: 0.05)),
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
              ),
              const SizedBox(height: 20),

              // Painel de Dados
              Row(
                children: [
                  _buildDataTile("BT TEMP", "${beanTemp.toStringAsFixed(1)}°C",
                      Colors.orangeAccent),
                  const SizedBox(width: 12),
                  _buildDataTile(
                      "RoR", ror.toStringAsFixed(1), Colors.cyanAccent),
                  const SizedBox(width: 12),
                  _buildDataTile("TEMPO", _formatTime(seconds), Colors.white),
                ],
              ),

              const SizedBox(height: 20),

              // Controles de Hardware
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildSlider("POTÊNCIA DE AQUECIMENTO", heatInput,
                        Colors.redAccent, (v) => setState(() => heatInput = v)),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Divider(height: 1, color: Colors.white10),
                    ),
                    _buildSlider("FLUXO DE AR (AIRFLOW)", airFlow,
                        Colors.blueAccent, (v) => setState(() => airFlow = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.orbitron(
                    fontSize: 18, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text("${value.toInt()}%",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            activeColor: color,
            inactiveColor: color.withValues(alpha: 0.1),
            onChanged: isRoasting ? onChanged : null,
          ),
        ),
      ],
    );
  }

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }
}
