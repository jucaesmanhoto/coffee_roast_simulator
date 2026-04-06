import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

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
  final double chargeTemp;
  final double initialHeat;
  final double initialAirflow;
  final double initialDrumSpeed;
  final double timeScale; // Fator de aceleração do tempo

  // Constantes Físicas do Torrador (Kaleido M10)
  final double maxPowerWatts; // Potência máxima do aquecedor
  final double drumMassKg; // Massa térmica do tambor
  final double drumSpecificHeat; // Calor específico do material do tambor (Aço Inox 304)

  RoasterSettings({
    this.model = 'Kaleido M10',
    this.batchSizeGrams = 600.0,
    this.chargeTemp = 208.0,
    this.initialHeat = 95.0,
    this.initialAirflow = 25.0,
    this.initialDrumSpeed = 70.0,
    this.timeScale = 10.0, // 1.0 = tempo real, 10.0 = 10x mais rápido
    this.maxPowerWatts = 2600.0,
    this.drumMassKg = 2.0, // Estimativa para um torrador deste porte
    this.drumSpecificHeat = 0.5, // kJ/kg·K para Aço Inox 304
  });
}

class RoastSimulatorService {
  // Parâmetros de Simulação
  double beanTemp = 20.0; // Temperatura do grão (BT)
  double trueBeanCoreTemp = 20.0; // Temperatura interna REAL do grão
  double drumTemp = 20.0; // Temperatura do tambor (ou ambiente interno)
  double airTemp = 20.0; // Temperatura do ar dentro do torrador
  static const double ambientTemp = 20.0; // Temperatura ambiente fixa
  double heatInput = 0.0;
  double airFlow = 20.0;
  double ror = 0.0; // Rate of Rise
  int roastSeconds = 0; // Tempo de torra
  RoastState roastState = RoastState.idle;
  double currentBatchMassGrams; // Massa atual do lote, diminui com a evaporação
  RoastPhase roastPhase = RoastPhase.drying;
  bool firstCrackHappened = false;

  // Dados do Gráfico
  final List<FlSpot> btPoints = [const FlSpot(0, 20)];
  final List<FlSpot> rorPoints = [const FlSpot(0, 0)];

  // Modelos de configuração
  Coffee coffee;
  RoasterSettings roasterSettings;

  RoastSimulatorService({Coffee? coffee, RoasterSettings? roasterSettings})
      : coffee = coffee ?? Coffee(),
        roasterSettings = roasterSettings ?? RoasterSettings(),
        currentBatchMassGrams = (roasterSettings ?? RoasterSettings()).batchSizeGrams;

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
    roastPhase = RoastPhase.drying;
    firstCrackHappened = false;
    currentBatchMassGrams = roasterSettings.batchSizeGrams;
  }

  void preheat() {
    // Limpa os dados do gráfico de uma torra anterior
    btPoints.clear();
    rorPoints.clear();
    btPoints.add(FlSpot(0, roasterSettings.chargeTemp)); // Começa o gráfico na temp de pre-aquecimento
    rorPoints.add(const FlSpot(0, 0));

    roastState = RoastState.preheating;
    drumTemp = roasterSettings.chargeTemp;
    heatInput = roasterSettings.initialHeat;
    airFlow = roasterSettings.initialAirflow;
  }

  void chargeBeans() {
    roastState = RoastState.roasting;
    roastSeconds = 0;
    btPoints.clear();
    rorPoints.clear();

    // A sonda (beanTemp) estava lendo a temperatura do tambor. Agora ela será resfriada pelos grãos.
    // A temperatura interna real dos grãos (trueBeanCoreTemp) começa na temperatura ambiente.
    trueBeanCoreTemp = ambientTemp;
    // A primeira leitura do gráfico é a temperatura da sonda no momento da carga.
    btPoints.add(FlSpot(0, beanTemp));
    // O RoR inicial é drasticamente negativo.
    rorPoints.add(const FlSpot(0, 0));
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
        // A física do tambor e do ar já foi calculada acima.
        // O ROR aqui é o do tambor.
        ror = drumTempDelta * 60;
        break;

      case RoastState.roasting:
        roastSeconds++;
        double currentBatchMassKg = currentBatchMassGrams / 1000.0;

        // --- BALANÇO DE ENERGIA NO GRÃO ---
        // A física de transferência de calor usa a temperatura interna REAL do grão (trueBeanCoreTemp)

        // 1. Determinar a Fase da Torra
        if (trueBeanCoreTemp < 150) {
          roastPhase = RoastPhase.drying;
        } else if (trueBeanCoreTemp < 190) {
          roastPhase = RoastPhase.maillard;
        } else {
          roastPhase = RoastPhase.development;
        }

        // 2. Termo de Transferência de Calor (Condução + Convecção)
        // O vapor expelido aumenta a turbulência e o coeficiente de convecção (h)
        double vaporEffect = (roastPhase == RoastPhase.drying || firstCrackHappened) ? 1.5 : 1.0;
        double hConvection = (0.7 + airFlow / 100) * vaporEffect; // Coeficiente de convecção
        double hConduction = 0.9; // Coeficiente de condução
        double qTransfer = hConduction * (drumTemp - trueBeanCoreTemp) + hConvection * (airTemp - trueBeanCoreTemp);

        // 3. Termo de Perda de Massa e Resfriamento Evaporativo (ρ*V*λ*(dX/dt))
        const double latentHeatVaporization = 2260; // kJ/kg
        double moistureLossRate = 0;
        if (coffee.currentMoisture > 2.0) {
          // A evaporação é mais intensa na fase de secagem
          moistureLossRate = (roastPhase == RoastPhase.drying)
              ? (trueBeanCoreTemp - 80) / 80000
              : (trueBeanCoreTemp - 120) / 150000;
          moistureLossRate = max(0, moistureLossRate);
        }
        double moistureMassLossKg = currentBatchMassKg * moistureLossRate;
        double qEvaporativeCooling = moistureMassLossKg * latentHeatVaporization * 1000; // Convertendo para Joules

        // Atualiza umidade e massa do café
        coffee.currentMoisture -= moistureLossRate * 100;
        currentBatchMassGrams -= moistureMassLossKg * 1000;

        // 4. Termo de Geração de Calor Interno (ρ*V*Qr)
        double qReaction = 0;
        switch (roastPhase) {
          case RoastPhase.drying:
            qReaction = 0; // Reação puramente endotérmica
            break;
          case RoastPhase.maillard:
            qReaction = 1000; // Geração de calor leve e constante (J/s)
            break;
          case RoastPhase.development:
            // Simula o 1º Crack como um pulso de energia
            if (trueBeanCoreTemp > 196 && !firstCrackHappened) {
              qReaction = 232000 * currentBatchMassKg; // Pulso exotérmico de 232 kJ/kg
              firstCrackHappened = true;
            } else {
              // Reações de pirólise contínuas após o crack
              qReaction = 3000; // (J/s)
            }
            break;
        }

        // 5. Calcular a Variação da Temperatura do Grão (dT/dt)
        double beanSpecificHeat = coffee.specificHeat;
        // dT/dt = (q_transfer - q_evaporativeCooling + q_reaction) / (massa * Cp)
        double netEnergyRate = qTransfer - qEvaporativeCooling + qReaction;
        double coreTempDelta = netEnergyRate / (currentBatchMassKg * beanSpecificHeat * 1000); // Cp está em kJ, convertendo
        trueBeanCoreTemp += coreTempDelta * timeStep;

        // 6. Simular a leitura da sonda (beanTemp)
        // A sonda se move em direção à temperatura interna real do grão.
        beanTemp += (trueBeanCoreTemp - beanTemp) * 0.15; // O fator 0.15 controla a "inércia" da sonda.

        // 7. Atualizar ROR e Gráficos (baseado na leitura da sonda)
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
          if (drumTemp < ambientTemp) drumTemp = ambientTemp;
          if (beanTemp > ambientTemp) {
            beanTemp -= (beanTemp - ambientTemp) * 0.01; // Resfriamento simples do grão
          }
        }
        break;
    }
  }
}
