import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, RotatedBox;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/widgets.dart'; // Barrel file for widgets

class RoasterScreen extends StatefulWidget {
  const RoasterScreen({super.key});

  @override
  State<RoasterScreen> createState() => _RoasterScreenState();
}

enum RoastState { idle, preheating, roasting }

class _RoasterScreenState extends State<RoasterScreen> {
  // Parâmetros de Simulação
  double beanTemp = 120.0; // Temperatura do grão (BT)
  double drumTemp = 120.0; // Temperatura do tambor (ou ambiente interno)
  static const double ambientTemp = 20.0; // Temperatura ambiente fixa
  static const double batchSizeGrams = 600.0; // Tamanho da batelada
  double heatInput = 0.0;
  double airFlow = 20.0;
  double ror = 0.0; // Rate of Rise
  int roastSeconds = 0; // Tempo de torra
  RoastState _roastState = RoastState.idle;
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
    _timer?.cancel();
    setState(() {
      btPoints.clear();
      rorPoints.clear();
      btPoints.add(const FlSpot(0, 20));
      rorPoints.add(const FlSpot(0, 0));
      beanTemp = ambientTemp;
      drumTemp = ambientTemp;
      ror = 0.0;
      roastSeconds = 0;
      heatInput = 0.0;
      airFlow = 20.0;
      _roastState = RoastState.idle;
    });
  }

  void _preheat() {
    setState(() {
      _roastState = RoastState.preheating;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      switch (_roastState) {
        case RoastState.preheating:
          _updateDrumPhysics();
          break;
        case RoastState.roasting:
          _updateRoastPhysics();
          break;
        case RoastState.idle:
          // Se o estado for ocioso, mas o tambor ainda estiver quente, simula o resfriamento.
          if (drumTemp > ambientTemp) {
            _updateDrumPhysics(coolingDown: true);
          } else {
            timer.cancel();
          }
          break;
      }
    });
  }

  void _chargeBeans() {
    setState(() {
      _roastState = RoastState.roasting;
      // Reseta o tempo e o gráfico para o início da torra
      roastSeconds = 0;
      btPoints.clear();
      rorPoints.clear();

      // Simulação do "Charge": a temperatura dos grãos se equaliza com a do tambor.
      // Modelo simplificado de transferência de calor por massa.
      const double drumMassKg = 2.0; // Massa térmica efetiva do tambor
      const double batchSizeKg = batchSizeGrams / 1000.0;
      final initialBeanTemp = (drumMassKg * drumTemp + batchSizeKg * ambientTemp) / (drumMassKg + batchSizeKg);

      // O RoR inicial é fortemente negativo devido ao choque térmico.
      // Este valor é empírico para criar a curva do "turning point".
      ror = -80.0;
      beanTemp = initialBeanTemp;

      btPoints.add(FlSpot(0, initialBeanTemp));
      rorPoints.add(const FlSpot(0, 0));
    });
  }

  void _stopRoast() {
    setState(() {
      _roastState = RoastState.idle;
      // Não cancelamos o timer aqui para permitir o resfriamento do tambor.
    });
  }

  void _updateRoastPhysics() {
    if (!mounted) return;

    setState(() {
      roastSeconds++;

      // Lógica de Física do Kaleido M10
      // Fatores de aquecimento e arrefecimento calibrados
      double heatEffect = (heatInput / 100) * 15.0;
      double airCooling = (airFlow / 100) * 6.0;
      // A perda para o ambiente é mais significativa em temperaturas mais altas
      double environmentalLoss = (beanTemp - ambientTemp) * 0.022;

      double targetRoR = heatEffect - airCooling - environmentalLoss;

      // Inércia térmica: o RoR se aproxima do RoR alvo gradualmente.
      ror = ror + (targetRoR - ror) * 0.12;

      // Atualização da temperatura (RoR é por minuto, dividimos por 60 para segundos)
      beanTemp += (ror / 60);

      // Atualiza a temperatura do tambor junto com a dos grãos
      drumTemp = beanTemp * 1.05; // O tambor sempre um pouco mais quente que os grãos

      double timeInMinutes = roastSeconds / 60;
      btPoints.add(FlSpot(timeInMinutes, beanTemp));

      // Adiciona o RoR real. A escala será feita no próprio gráfico.
      rorPoints.add(FlSpot(timeInMinutes, ror));
    });
  }

  void _updateDrumPhysics({bool coolingDown = false}) {
    if (!mounted) return;
    setState(() {
      double heatEffect = coolingDown ? 0 : (heatInput / 100) * 18.0; // Aquecimento mais rápido sem grãos
      double airCooling = (airFlow / 100) * 6.5;
      double environmentalLoss = (drumTemp - ambientTemp) * 0.02;

      double delta = heatEffect - airCooling - environmentalLoss;

      drumTemp += (delta / 60); // Aplica a mudança
      if (drumTemp < ambientTemp) drumTemp = ambientTemp;
    });
  }

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  List<Widget> _buildAppBarActions() {
    switch (_roastState) {
      case RoastState.idle:
        return [
          TextButton.icon(
            onPressed: _preheat,
            icon: const Icon(Icons.power_settings_new, color: Colors.greenAccent),
            label: const Text("PRÉ-AQUECER", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          )
        ];
      case RoastState.preheating:
        return [
          TextButton.icon(
            onPressed: _chargeBeans,
            icon: const Icon(CupertinoIcons.arrow_down_to_line_alt, color: Colors.orangeAccent),
            label: const Text("SOLTAR CAFÉ", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: _resetSimulation,
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
          )
        ];
      case RoastState.roasting:
        return [
          TextButton.icon(
            onPressed: _stopRoast,
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            label: const Text("PARAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ];
    }
  }

  double get displayedRoR => ror < 0 ? 0 : ror;
  double get displayedTemp => _roastState == RoastState.roasting ? beanTemp : drumTemp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KALEIDO M10 SIMULATOR', style: GoogleFonts.oswald(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(children: _buildAppBarActions()),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna de Controles (Vertical)
              SizedBox(
                width: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const SizedBox(height: 60),
                    RotatedBox(
                      quarterTurns: 3, // Gira o slider para a vertical
                      child: ControlSlider(label: "POTÊNCIA", value: heatInput, color: Colors.redAccent, onChanged: _roastState != RoastState.idle ? (v) => setState(() => heatInput = v) : null),
                    ),
                    const SizedBox(height: 40),
                    RotatedBox(
                      quarterTurns: 3,
                      child: ControlSlider(label: "FLUXO DE AR", value: airFlow, color: Colors.blueAccent, onChanged: _roastState != RoastState.idle ? (v) => setState(() => airFlow = v) : null),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Coluna Principal (Gráfico e Dados)
              Expanded(
                child: Column(
                  children: [
                    RoastChart(btPoints: btPoints, rorPoints: rorPoints),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        DataTile(label: "BT TEMP", value: "${displayedTemp.toStringAsFixed(1)}°C", color: Colors.orangeAccent),
                        const SizedBox(width: 12),
                        DataTile(label: "RoR", value: displayedRoR.toStringAsFixed(1), color: Colors.cyanAccent),
                        const SizedBox(width: 12),
                        DataTile(label: "TEMPO", value: _formatTime(roastSeconds), color: Colors.white),
                        const SizedBox(width: 12),
                        DataTile(label: "MASSA", value: "${batchSizeGrams.toInt()}g", color: Colors.grey),
                      ],
                    ),
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
