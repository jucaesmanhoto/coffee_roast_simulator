import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import 'roast_phases/roast_phases.dart';

enum RoastState { idle, preheating, roasting }
enum RoastPhase { drying, maillard, development }

class Coffee {
  final String variety;
  final String region;
  final int altitude;
  final double density; // g/mL, densidade inicial
  final double initialMoisture; // percentual, base úmida

  double currentMoisture; // Umidade atual, que muda durante a torra

  Coffee({
    this.variety = 'Catuaí Amarelo',
    this.region = 'Região Vulcânica',
    this.altitude = 1150,
    this.density = 0.7,
    this.initialMoisture = 11.5,
  }) : currentMoisture = initialMoisture;

  /// Calcula o Calor Específico (Cp) em kJ/kg·K com base na umidade atual.
  /// Fórmula baseada em dados de engenharia para café.
  /// M_wb é a umidade em base úmida (wet basis).
  double get specificHeat {
    // Cp = 0.0535 * M%wb + 1.6552
    return 0.0535 * currentMoisture + 1.6552;
  }
}

class RoasterSettings {
  final String model;
  final double batchSizeGrams;
  // final double chargeTemp;
  final double initialHeat;
  final double initialAirflow;
  final double initialDrumSpeed;
  final double timeScale; // Fator de aceleração do tempo

  // Constantes Físicas do Torrador (Kaleido M10)
  final double maxPowerWatts; // Potência máxima do aquecedor
  final double drumMassKg; // Massa térmica do tambor
  final double drumSpecificHeat; // Calor específico do material do tambor (Aço Inox 304)
  final double controlStep; // Incremento dos controles (e.g., 5% para o Kaleido M10)

  /// Fator de influência da massa de grãos na leitura da sonda (BT).
  /// 1.0 = sonda mede 100% a temp. do grão; 0.0 = sonda mede 100% a temp. do ar.
  final double probeBeanMassInfluence;

  RoasterSettings({
    this.model = 'Kaleido M10',
    this.batchSizeGrams = 600.0,
    // this.chargeTemp = 195.0,
    this.initialHeat = 70.0,
    this.initialAirflow = 20.0,
    this.initialDrumSpeed = 70.0,
    this.timeScale = 4.0, // 1.0 = tempo real, 10.0 = 10x mais rápido
    this.maxPowerWatts = 2600.0,
    this.drumMassKg = 2.0, // Estimativa para um torrador deste porte
    this.drumSpecificHeat = 0.5, // kJ/kg·K para Aço Inox 304
    this.controlStep = 5.0, // Kaleido M10 opera em steps de 5%
    this.probeBeanMassInfluence = 0.635, // Ponto de partida para um TP realista.
  });
}

class RoastSimulatorService {
  // --- Constantes das Fases da Torra ---
  static const double dryingToEndTemp = 150.0; // Temp. final da fase de secagem
  static const double maillardToEndTemp = 195.0; // Temp. final de Maillard (início do 1º crack)
  static const double combustionTemp = 240.0; // Temp. de combustão do café
  static const double dryingToMaillardTransitionWidth = 20.0;
  static const double maillardToDevelopmentTransitionWidth = 12.0;


  // Parâmetros de Simulação
  double beanTemp = 190.0; // Temperatura do grão (BT)
  double trueBeanCoreTemp = 20.0; // Temperatura interna REAL do grão
  double drumTemp = 190.0; // Temperatura do tambor (ou ambiente interno)
  double airTemp = 190.0; // Temperatura do ar dentro do torrador
  static const double ambientTemp = 20.0; // Temperatura ambiente fixa
  double heatInput = 0.0;
  double airFlow = 20.0;
  double ror = 0.0; // Rate of Rise
  int roastSeconds = 0; // Tempo de torra
  RoastState roastState = RoastState.idle;
  double currentBatchMassGrams; // Massa atual do lote, diminui com a evaporação
  RoastPhase roastPhase = RoastPhase.drying;
  bool hasCaughtFire = false;
  bool firstCrackHappened = false;
  double? firstCrackTemp;
  int? firstCrackTime;
  double? turningPointTemp;
  int? turningPointTime;
  int? dryingPhaseEndTime;
  bool turningPointDetected = false;
  bool hasRorDropped = false; // Nova flag para a lógica do TP
  double lowestBtSinceCharge = double.infinity; // Para detectar o TP real
  double? chargeTempSnapshot;

  // Dados do Gráfico
  final List<FlSpot> btPoints = [const FlSpot(0, 20)];
  final List<FlSpot> rorPoints = [const FlSpot(0, 0)];

  // Modelos de configuração
  Coffee coffee;
  RoasterSettings roasterSettings;

  // Estratégias de Fase
  final Map<RoastPhase, RoastPhaseStrategy> _phaseStrategies;

  RoastSimulatorService({Coffee? coffee, RoasterSettings? roasterSettings})
      : coffee = coffee ?? Coffee(),
        roasterSettings = roasterSettings ?? RoasterSettings(),
        currentBatchMassGrams = (roasterSettings ?? RoasterSettings()).batchSizeGrams,
        _phaseStrategies = {
          RoastPhase.drying: DryingPhaseStrategy(),
          RoastPhase.maillard: MaillardPhaseStrategy(),
          RoastPhase.development: DevelopmentPhaseStrategy(),
        };

  int get developmentTimeSeconds {
    if (firstCrackTime == null || roastSeconds < firstCrackTime!) {
      return 0;
    }
    return roastSeconds - firstCrackTime!;
  }

  double get developmentTimePercentage {
    if (firstCrackTime == null || roastSeconds <= 0) {
      return 0;
    }
    return (developmentTimeSeconds / roastSeconds) * 100;
  }

  /// Tempo na faixa de secagem (carga até ~150°C).
  int get dryingPhaseDurationSeconds {
    if (roastSeconds <= 0) {
      return 0;
    }
    if (dryingPhaseEndTime == null) {
      return roastSeconds;
    }
    return dryingPhaseEndTime!;
  }

  /// Tempo entre o fim da secagem (~150°C) e a marcação do 1º crack.
  int get maillardBandDurationSeconds {
    if (dryingPhaseEndTime == null) {
      return 0;
    }
    if (firstCrackTime == null) {
      return (roastSeconds - dryingPhaseEndTime!).clamp(0, roastSeconds);
    }
    final span = firstCrackTime! - dryingPhaseEndTime!;
    return span < 0 ? 0 : span;
  }

  /// Tempo após marcação do 1º crack até o instante atual.
  int get postFirstCrackDurationSeconds {
    final t = firstCrackTime;
    if (t == null || roastSeconds <= t) {
      return 0;
    }
    return roastSeconds - t;
  }

  double percentOfTotalRoast(int segmentSeconds) {
    if (roastSeconds <= 0) {
      return 0;
    }
    return (segmentSeconds / roastSeconds) * 100;
  }

  void markFirstCrack() {
    if (roastState != RoastState.roasting) {
      return;
    }

    firstCrackTime = roastSeconds;
    firstCrackTemp = beanTemp;
  }

  double _getDryingToMaillardBlendFactor() {
    final transitionStart = dryingToEndTemp - (dryingToMaillardTransitionWidth / 2);
    final normalizedFactor = (((trueBeanCoreTemp - transitionStart) /
          dryingToMaillardTransitionWidth)
        .clamp(0.0, 1.0))
      .toDouble();
    return normalizedFactor * normalizedFactor * (3.0 - (2.0 * normalizedFactor));
  }

  double _getMaillardToDevelopmentBlendFactor() {
    final transitionStart =
        maillardToEndTemp - (maillardToDevelopmentTransitionWidth / 2);
    final normalizedFactor = (((trueBeanCoreTemp - transitionStart) /
                maillardToDevelopmentTransitionWidth)
            .clamp(0.0, 1.0))
        .toDouble();
    return normalizedFactor * normalizedFactor * (3.0 - (2.0 * normalizedFactor));
  }

  PhasePhysicsResult _blendPhysicsResults(
    PhasePhysicsResult first,
    PhasePhysicsResult second,
    double factor,
  ) {
    final inverseFactor = 1.0 - factor;
    return PhasePhysicsResult(
      qTransfer: first.qTransfer * inverseFactor + second.qTransfer * factor,
      qEvaporativeCooling:
          first.qEvaporativeCooling * inverseFactor + second.qEvaporativeCooling * factor,
      qReaction: first.qReaction * inverseFactor + second.qReaction * factor,
      moistureLossRate:
          first.moistureLossRate * inverseFactor + second.moistureLossRate * factor,
    );
  }

  PhasePhysicsResult _calculatePhasePhysics() {
    final dryingPhysics = _phaseStrategies[RoastPhase.drying]!.calculatePhysics(this);
    final maillardPhysics = _phaseStrategies[RoastPhase.maillard]!.calculatePhysics(this);
    final developmentPhysics =
        _phaseStrategies[RoastPhase.development]!.calculatePhysics(this);

    final maillardToDevelopmentBlendFactor =
        _getMaillardToDevelopmentBlendFactor();
    if (maillardToDevelopmentBlendFactor > 0.0) {
      if (maillardToDevelopmentBlendFactor >= 1.0) {
        return developmentPhysics;
      }

      return _blendPhysicsResults(
        maillardPhysics,
        developmentPhysics,
        maillardToDevelopmentBlendFactor,
      );
    }

    final blendFactor = _getDryingToMaillardBlendFactor();

    if (blendFactor <= 0.0) {
      return dryingPhysics;
    }

    if (blendFactor >= 1.0) {
      return maillardPhysics;
    }

    return _blendPhysicsResults(dryingPhysics, maillardPhysics, blendFactor);
  }

  void _applyMoistureLoss(double currentBatchMassKg, double moistureLossRate) {
    if (coffee.currentMoisture <= 2.0 || moistureLossRate <= 0) {
      return;
    }

    final maxAllowedLossRate = (coffee.currentMoisture - 2.0) / 100.0;
    final appliedLossRate = min(moistureLossRate, maxAllowedLossRate);
    final moistureMassLossKg = currentBatchMassKg * appliedLossRate;

    coffee.currentMoisture -= appliedLossRate * 100;
    currentBatchMassGrams -= moistureMassLossKg * 1000;
  }


  void resetSimulation() {
    btPoints.clear();
    rorPoints.clear();
    btPoints.add(const FlSpot(0, 20));
    rorPoints.add(const FlSpot(0, 0));
    beanTemp = ambientTemp;
    drumTemp = ambientTemp;
    trueBeanCoreTemp = ambientTemp;
    airTemp = ambientTemp;
    ror = 0.0;
    roastSeconds = 0;
    heatInput = 0.0;
    airFlow = 20.0;
    roastState = RoastState.idle;
    coffee = Coffee(); // Reseta o café para o estado inicial
    hasCaughtFire = false;
    roastPhase = RoastPhase.drying;
    firstCrackHappened = false;
    firstCrackTemp = null;
    firstCrackTime = null;
    currentBatchMassGrams = roasterSettings.batchSizeGrams;
    turningPointTemp = null;
    turningPointTime = null;
    dryingPhaseEndTime = null;
    firstCrackTemp = null;
    firstCrackTime = null;
    turningPointDetected = false;
    hasRorDropped = false;
    lowestBtSinceCharge = double.infinity;
    chargeTempSnapshot = null;
  }

  void preheat() {
    // Limpa os dados do gráfico de uma torra anterior
    hasCaughtFire = false;
    chargeTempSnapshot = null;
    btPoints.clear();
    rorPoints.clear();
    rorPoints.add(const FlSpot(0, 0));

    roastState = RoastState.preheating;
    // Apenas define o estado e os controles. A temperatura subirá gradualmente no updatePhysics.
    // drumTemp e beanTemp começam em ambientTemp e sobem a partir daí.
    heatInput = roasterSettings.initialHeat;
    airFlow = roasterSettings.initialAirflow;
  }

  void chargeBeans() {
    roastState = RoastState.roasting;
    roastSeconds = 0;
    btPoints.clear();
    rorPoints.clear();

    // Sincroniza a sonda com a temperatura do tambor no momento da carga.
    chargeTempSnapshot = beanTemp; // Captura a temperatura da sonda no momento da carga

    // A sonda (beanTemp), que estava na temperatura de carga, agora será resfriada pelos grãos.
    // A temperatura interna real dos grãos (trueBeanCoreTemp) começa na temperatura ambiente.
    trueBeanCoreTemp = ambientTemp;

    // Adiciona o ponto inicial no gráfico: no tempo 0, a sonda ainda lê a temperatura de carga.
    btPoints.add(FlSpot(0, beanTemp));

    // O RoR inicial é drasticamente negativo.
    rorPoints.add(const FlSpot(0, 0));
    turningPointTemp = null;
    turningPointTime = null;
    dryingPhaseEndTime = null;
    turningPointDetected = false;
    hasRorDropped = false;
    lowestBtSinceCharge = beanTemp; // Inicia a busca pelo TP a partir da temperatura de carga
  }

  void stopRoast() {
    // Transiciona para o estado de resfriamento, mas mantém o timer para simular a queda de temperatura.
    roastState = RoastState.idle;
  }

  void updatePhysics() {
    const double timeStep = 1.0; // Simulação ocorre a cada 1 segundo

    // 1. Calcular a energia total fornecida pelo aquecedor em Joules/s (Watts)
    double totalPowerInput = (heatInput / 100.0) * roasterSettings.maxPowerWatts;

    // 2. Simular a temperatura do ar e do tambor
    // Perda de calor para o ambiente
    double drumHeatLoss = (drumTemp - ambientTemp) * 0.8; // Coeficiente de perda
    double airHeatLoss = (airTemp - ambientTemp) * (0.5 + airFlow / 100);

    // Energia absorvida pelo ar (influenciado pelo fluxo de ar)
    double powerToAir = totalPowerInput * (airFlow / 100.0) * 0.7;
    // Energia para o tambor
    double powerToDrum = totalPowerInput * 0.3;

    // Variação da temperatura do tambor
    double drumTempDelta = (powerToDrum - drumHeatLoss) / (roasterSettings.drumMassKg * roasterSettings.drumSpecificHeat * 1000) * timeStep;
    drumTemp += drumTempDelta;

    // Variação da temperatura do ar
    airTemp += (powerToAir - airHeatLoss) / 500 * timeStep; // 500 é uma "massa térmica" arbitrária para o ar
    airTemp = max(ambientTemp, min(airTemp, drumTemp * 1.2)); // Ar não pode ficar mais quente que o tambor

    switch (roastState) {
      case RoastState.preheating:
        // No pré-aquecimento, a sonda (BT) mede a temperatura do ar.
        // A sonda tem sua própria inércia, então ela se aproxima da temp do ar gradualmente.
        beanTemp += (airTemp - beanTemp) * 0.2; // Fator de inércia da sonda
        break;

      case RoastState.roasting:
        // Após a carga, a sonda é resfriada pela massa de grãos, mas aquecida pelo ar.
        // A sonda (BT) mede uma mistura da temperatura real do grão e do ar ao redor.
        // A proporção é controlada por `probeBeanMassInfluence` para permitir ajuste fino.
        double probeInfluence = roasterSettings.probeBeanMassInfluence;
        double targetProbeTemp = (trueBeanCoreTemp * probeInfluence) + (airTemp * (1.0 - probeInfluence));
        double inertiaFactor = 0.08; // Aumenta a reatividade da sonda
        beanTemp += (targetProbeTemp - beanTemp) * inertiaFactor;

        roastSeconds++;
        double currentBatchMassKg = currentBatchMassGrams / 1000.0;

        RoastPhase previousPhase = roastPhase;

        // 1. ATUALIZAR FASE DA TORRA E OBTER ESTRATÉGIA
        // TODA a lógica de fase e eventos deve ser baseada na temperatura da sonda (BT), que é o que o usuário vê.
        if (beanTemp < dryingToEndTemp) {
          roastPhase = RoastPhase.drying;
        } else if (beanTemp < maillardToEndTemp) {
          roastPhase = RoastPhase.maillard;
        } else {
          roastPhase = RoastPhase.development;
        }

        // Captura o momento em que a secagem termina.
        // Exige que o TP já tenha sido detectado para evitar um falso disparo logo após a carga,
        // quando a sonda (BT) ainda está quente do pré-aquecimento mas os grãos ainda estão frios.
        if (previousPhase == RoastPhase.drying && roastPhase == RoastPhase.maillard && dryingPhaseEndTime == null && beanTemp >= dryingToEndTemp && turningPointDetected) {
          dryingPhaseEndTime = roastSeconds;
        }

        if (!firstCrackHappened && beanTemp >= maillardToEndTemp) {
          firstCrackHappened = true;
        }

        // 2. CALCULAR A FÍSICA COM TRANSIÇÃO SUAVE ENTRE SECAGEM E MAILLARD
        final physicsResult = _calculatePhasePhysics();
        _applyMoistureLoss(currentBatchMassKg, physicsResult.moistureLossRate);

        // Detecção do Turning Point (TP) - O ponto mais baixo que a BT atinge.
        if (!turningPointDetected) {
          if (beanTemp < lowestBtSinceCharge) {
            // A temperatura ainda está caindo, continue atualizando o mínimo.
            lowestBtSinceCharge = beanTemp;
          } else {
            // A temperatura parou de cair e começou a subir. O TP foi o último ponto mínimo.
            turningPointDetected = true;
            turningPointTemp = lowestBtSinceCharge;
            turningPointTime = roastSeconds > 0 ? roastSeconds - 1 : 0; // O TP ocorreu no segundo anterior.
          }
        }

        // 3. CALCULAR VARIAÇÃO DA TEMPERATURA COM BASE NOS RESULTADOS DA ESTRATÉGIA
        double beanSpecificHeat = coffee.specificHeat;
        double netEnergyRate = physicsResult.qTransfer - physicsResult.qEvaporativeCooling + physicsResult.qReaction;
        double coreTempDelta = netEnergyRate / (currentBatchMassKg * beanSpecificHeat * 1000); // Cp está em kJ, convertendo
        trueBeanCoreTemp += coreTempDelta * timeStep;

        // 4. GARANTIR LIMITE MÁXIMO DE TEMPERATURA
        if (beanTemp >= combustionTemp) {
          beanTemp = combustionTemp; // Trava a temperatura do display
          hasCaughtFire = true;
          // A simulação será interrompida na UI
        }

        // 6. ATUALIZAR ROR E GRÁFICOS (baseado na leitura da sonda)
        double newRor = (btPoints.isNotEmpty) ? (beanTemp - btPoints.last.y) * 60 / timeStep : 0;
        ror = ror * 0.95 + newRor * 0.05;
        double timeInMinutes = roastSeconds / 60.0;
        btPoints.add(FlSpot(timeInMinutes, beanTemp));
        rorPoints.add(FlSpot(timeInMinutes, ror < 0 ? 0 : ror));
        break;

      case RoastState.idle:
        if (drumTemp > ambientTemp) {
          double coolingDrumDelta = (-drumHeatLoss) / (roasterSettings.drumMassKg * roasterSettings.drumSpecificHeat * 1000) * timeStep;
          drumTemp += coolingDrumDelta;
          airTemp = ambientTemp + (drumTemp - ambientTemp) * 0.5; // Ar acompanha o resfriamento do tambor
          // A sonda também resfria em direção à temperatura do ar
          beanTemp += (airTemp - beanTemp) * 0.1;
          drumTemp = max(drumTemp, ambientTemp);
        }
        break;
    }
  }
}
