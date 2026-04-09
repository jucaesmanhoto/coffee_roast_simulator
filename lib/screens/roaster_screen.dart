import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
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
  static const List<String> _firstCrackSounds = [
    '101494__earthsounds__twig-snap-3.wav',
    '25419__andrewweathers__popcorn-shove.wav',
    '445816__thoryn__snapping-branch.wav',
    '89402__zimbot__woodsnap9.wav',
  ];

  late RoastSimulatorService _simulator;
  Timer? _timer;
  final Random _soundRandom = Random();
  final Set<AudioPlayer> _activePopPlayers = <AudioPlayer>{};

  @override
  void initState() {
    super.initState();
    _resetSimulation();
  }


  @override
  void dispose() {
    _timer?.cancel();
    for (final player in _activePopPlayers) {
      unawaited(player.dispose());
    }
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
        // Verifica se o café pegou fogo após a atualização da física
        if (_simulator.hasCaughtFire) {
          _timer?.cancel();
          _simulator.stopRoast(); // Garante que o estado seja 'idle'
          _showFireAlert();
        }
      });

      final pendingPops = _simulator.consumePendingFirstCrackPops();
      if (pendingPops > 0) {
        _playFirstCrackBurst(pendingPops);
      }
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

  void _markFirstCrack() {
    setState(() {
      _simulator.markFirstCrack();
    });
  }

  void _playFirstCrackBurst(int popCount) {
    if (popCount <= 0) {
      return;
    }

    final tickMillis = (1000 / _simulator.roasterSettings.timeScale).round().clamp(80, 1400);
    final maxPops = popCount.clamp(1, 18);

    for (var i = 0; i < maxPops; i++) {
      final delayMs = maxPops == 1 ? 0 : _soundRandom.nextInt(tickMillis);
      final assetName = _firstCrackSounds[_soundRandom.nextInt(_firstCrackSounds.length)];
      unawaited(Future.delayed(Duration(milliseconds: delayMs), () async {
        if (!mounted || _simulator.roastState != RoastState.roasting) {
          return;
        }

        await _playFirstCrackAsset(assetName);
      }));
    }
  }

  Future<void> _playFirstCrackAsset(String assetName) async {
    final player = AudioPlayer();
    _activePopPlayers.add(player);

    void cleanup() {
      if (_activePopPlayers.remove(player)) {
        unawaited(player.dispose());
      }
    }

    late final StreamSubscription<void> completeSubscription;
    late final StreamSubscription<void> stopSubscription;
    completeSubscription = player.onPlayerComplete.listen((_) {
      unawaited(completeSubscription.cancel());
      unawaited(stopSubscription.cancel());
      cleanup();
    });
    stopSubscription = player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.disposed) {
        unawaited(completeSubscription.cancel());
        unawaited(stopSubscription.cancel());
        cleanup();
      }
    });

    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(assetName), volume: 1.0);
    } catch (_) {
      unawaited(completeSubscription.cancel());
      unawaited(stopSubscription.cancel());
      cleanup();
    }
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

  void _showFireAlert() {
    // Garante que o alerta seja mostrado após o build atual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("COMBUSTÃO!", style: TextStyle(color: Colors.redAccent)),
          content: const Text("O seu café pegou fogo! A temperatura excedeu 240°C e a torra foi interrompida."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    });
  }

  String _formatTime(int sec) {
    return "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  String get _firstCrackValue {
    if (_simulator.firstCrackTime == null || _simulator.firstCrackTemp == null) {
      return 'MARCAR';
    }

    return '${_simulator.firstCrackTemp!.toStringAsFixed(1)}° / ${_formatTime(_simulator.firstCrackTime!)}';
  }

  bool get _hasRoastSession => _simulator.chargeTempSnapshot != null;

  String get _stripDryingLine {
    if (!_hasRoastSession) {
      return '--:-- · --%';
    }
    if (_simulator.roastSeconds <= 0) {
      return '00:00 · 0.0%';
    }
    final sec = _simulator.dryingPhaseDurationSeconds;
    final pct = _simulator.percentOfTotalRoast(sec);
    return '${_formatTime(sec)} · ${pct.toStringAsFixed(1)}%';
  }

  String get _stripMaillardLine {
    if (!_hasRoastSession) {
      return '--:-- · --%';
    }
    if (_simulator.roastSeconds <= 0) {
      return '00:00 · 0.0%';
    }
    final sec = _simulator.maillardBandDurationSeconds;
    final pct = _simulator.percentOfTotalRoast(sec);
    return '${_formatTime(sec)} · ${pct.toStringAsFixed(1)}%';
  }

  String get _stripPostCrackLine {
    if (!_hasRoastSession) {
      return '--:-- · --%';
    }
    if (_simulator.firstCrackTime == null) {
      return '--:-- · --%';
    }
    if (_simulator.roastSeconds <= 0) {
      return '00:00 · 0.0%';
    }
    final sec = _simulator.postFirstCrackDurationSeconds;
    final pct = _simulator.percentOfTotalRoast(sec);
    return '${_formatTime(sec)} · ${pct.toStringAsFixed(1)}%';
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
                      child: ControlSlider(
                        label: "POTÊNCIA",
                        value: _simulator.heatInput,
                        color: Colors.redAccent,
                        step: _simulator.roasterSettings.controlStep,
                        onChanged: _simulator.roastState != RoastState.idle ? (v) => setState(() => _simulator.heatInput = v) : null,
                      ),
                    ),
                    const SizedBox(height: 40),
                    RotatedBox(
                      quarterTurns: 3,
                      child: ControlSlider(
                        label: "FLUXO DE AR",
                        value: _simulator.airFlow,
                        color: Colors.blueAccent,
                        step: _simulator.roasterSettings.controlStep,
                        onChanged: _simulator.roastState != RoastState.idle ? (v) => setState(() => _simulator.airFlow = v) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Coluna Principal (Gráfico e Dados)
              Expanded(
                child: Column(
                  children: [
                    RoastChart(
                      btPoints: _simulator.btPoints,
                      rorPoints: _simulator.rorPoints,
                      turningPointTime: _simulator.turningPointTime,
                      stripDryingLine: _stripDryingLine,
                      stripMaillardLine: _stripMaillardLine,
                      stripPostCrackLine: _stripPostCrackLine,
                    ),
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
                            Expanded(child: DataTile(label: "MASSA", value: "${_simulator.roasterSettings.batchSizeGrams.toInt()}g", color: Colors.grey)),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: DataTile(
                                label: "SECAGEM",
                                value: _simulator.dryingPhaseEndTime != null
                                    ? "${RoastSimulatorService.dryingToEndTemp.toStringAsFixed(0)}° / ${_formatTime(_simulator.dryingPhaseEndTime!)}"
                                    : "--° / --:--",
                                color: Colors.yellowAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DataTile(
                                label: '1º CRACK',
                                value: _firstCrackValue,
                                color: Colors.deepOrangeAccent,
                                onTap: _simulator.roastState == RoastState.roasting ? _markFirstCrack : null,
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
