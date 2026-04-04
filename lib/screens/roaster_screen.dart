import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/widgets.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  void _stopRoast() {
    _timer?.cancel();
    setState(() => isRoasting = false);
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

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KALEIDO M10 SIMULATOR', style: GoogleFonts.oswald(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton.icon(
              onPressed: isRoasting ? _stopRoast : _startRoast,
              icon: Icon(isRoasting ? Icons.stop_circle : Icons.play_arrow_rounded, color: isRoasting ? Colors.redAccent : Colors.greenAccent),
              label: Text(isRoasting ? "PARAR" : "INICIAR", style: TextStyle(color: isRoasting ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              RoastChart(btPoints: btPoints, rorPoints: rorPoints),
              const SizedBox(height: 20),
              Row(
                children: [
                  DataTile(label: "BT TEMP", value: "${beanTemp.toStringAsFixed(1)}°C", color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  DataTile(label: "RoR", value: ror.toStringAsFixed(1), color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  DataTile(label: "TEMPO", value: _formatTime(seconds), color: Colors.white),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: Column(
                  children: [
                    ControlSlider(label: "POTÊNCIA DE AQUECIMENTO", value: heatInput, color: Colors.redAccent, onChanged: isRoasting ? (v) => setState(() => heatInput = v) : null),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Divider(height: 1, color: Colors.white10)),
                    ControlSlider(label: "FLUXO DE AR (AIRFLOW)", value: airFlow, color: Colors.blueAccent, onChanged: isRoasting ? (v) => setState(() => airFlow = v) : null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
