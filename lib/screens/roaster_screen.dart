import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons, RotatedBox;
import 'package:coffee_roast_simulator/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/services.dart';
import '../widgets/widgets.dart'; // Barrel file for widgets

class RoasterScreen extends StatefulWidget {
  const RoasterScreen({super.key});

  @override
  State<RoasterScreen> createState() => _RoasterScreenState();
}

class _RoasterScreenState extends State<RoasterScreen> {
  late RoastSimulatorService _simulator;
  Timer? _timer;

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
      _simulator = RoastSimulatorService();
    });
  }

  void _preheat() {
     // Cancela o timer antigo (se houver) e inicia um novo com a velocidade correta.
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (1000 / _simulator.roasterSettings.timeScale).round()), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _simulator.updatePhysics();
      });
    });

    setState(() {
      _simulator.preheat();
    });
  }

  void _chargeBeans() {
    setState(() {
      _simulator.chargeBeans();
    });
  }

  void _stopRoast() {
    setState(() {
      _timer?.cancel(); // Para a simulação para "congelar" o estado.
      _simulator.stopRoast();
    });
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          initialCoffee: _simulator.coffee,
          initialRoasterSettings: _simulator.roasterSettings,
        ),
      ),
    );

    if (result != null && result is Map) {
      _timer?.cancel();
      setState(() {
        _simulator = RoastSimulatorService(
          coffee: result['coffee'],
          roasterSettings: result['roasterSettings'],
        );
      });
    }
  }

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  List<Widget> _buildAppBarActions() {
    switch (_simulator.roastState) {
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

  double get displayedRoR => _simulator.ror < 0 ? 0 : _simulator.ror;
  // O display deve sempre mostrar a temperatura da sonda (BT), que é a referência do mestre de torras.
  double get displayedTemp => _simulator.beanTemp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KALEIDO M10 SIMULATOR', style: GoogleFonts.oswald(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
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
                      child: ControlSlider(label: "POTÊNCIA", value: _simulator.heatInput, color: Colors.redAccent, onChanged: _simulator.roastState != RoastState.idle ? (v) => setState(() => _simulator.heatInput = v) : null),
                    ),
                    const SizedBox(height: 40),
                    RotatedBox(
                      quarterTurns: 3,
                      child: ControlSlider(label: "FLUXO DE AR", value: _simulator.airFlow, color: Colors.blueAccent, onChanged: _simulator.roastState != RoastState.idle ? (v) => setState(() => _simulator.airFlow = v) : null),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Coluna Principal (Gráfico e Dados)
              Expanded(
                child: Column(
                  children: [
                    RoastChart(btPoints: _simulator.btPoints, rorPoints: _simulator.rorPoints),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: DataTile(label: "BT TEMP", value: "${displayedTemp.toStringAsFixed(1)}°C", color: Colors.orangeAccent)),
                            const SizedBox(width: 12),
                            Expanded(child: DataTile(label: "RoR", value: displayedRoR.toStringAsFixed(1), color: Colors.cyanAccent)),
                            const SizedBox(width: 12),
                            Expanded(child: DataTile(label: "TEMPO", value: _formatTime(_simulator.roastSeconds), color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(child: DataTile(label: "MASSA", value: "${_simulator.currentBatchMassGrams.toInt()}g", color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DataTile(
                                label: "CARGA",
                                value: _simulator.chargeTempSnapshot != null
                                    ? "${_simulator.chargeTempSnapshot!.toStringAsFixed(1)}°"
                                    : "--.-°",
                                color: Colors.lightBlueAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DataTile(
                                label: "TP",
                                value: _simulator.turningPointTemp != null
                                    ? "${_simulator.turningPointTemp!.toStringAsFixed(1)}° / ${_formatTime(_simulator.turningPointTime!)}"
                                    : "--.-° / --:--",
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ],
                        ),
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
