import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons, RotatedBox;
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
  final RoastSimulatorService _simulator = RoastSimulatorService();
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
      _simulator.resetSimulation();
    });
  }

  void _preheat() {
    // Se o timer principal não estiver ativo, inicia-o.
    // Ele cuidará do resfriamento e da lógica da torra.
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
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
      _simulator.stopRoast();
      // Não cancelamos o timer aqui para permitir o resfriamento do tambor.
    });
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
  double get displayedTemp => _simulator.roastState == RoastState.roasting ? _simulator.beanTemp : _simulator.drumTemp;

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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        DataTile(label: "BT TEMP", value: "${displayedTemp.toStringAsFixed(1)}°C", color: Colors.orangeAccent),
                        const SizedBox(width: 12),
                        DataTile(label: "RoR", value: displayedRoR.toStringAsFixed(1), color: Colors.cyanAccent),
                        const SizedBox(width: 12),
                        DataTile(label: "TEMPO", value: _formatTime(_simulator.roastSeconds), color: Colors.white),
                        const SizedBox(width: 12),
                        DataTile(label: "MASSA", value: "${RoastSimulatorService.batchSizeGrams.toInt()}g", color: Colors.grey),
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
