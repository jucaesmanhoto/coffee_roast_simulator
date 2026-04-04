import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

enum RoastState { idle, preheating, roasting }

class RoastSimulatorService {
  // Parâmetros de Simulação
  double beanTemp = 20.0; // Temperatura do grão (BT)
  double drumTemp = 20.0; // Temperatura do tambor (ou ambiente interno)
  static const double ambientTemp = 20.0; // Temperatura ambiente fixa
  static const double batchSizeGrams = 600.0; // Tamanho da batelada
  double heatInput = 0.0;
  double airFlow = 20.0;
  double ror = 0.0; // Rate of Rise
  int roastSeconds = 0; // Tempo de torra
  RoastState roastState = RoastState.idle;

  // Dados do Gráfico
  final List<FlSpot> btPoints = [const FlSpot(0, 20)];
  final List<FlSpot> rorPoints = [const FlSpot(0, 0)];

  void resetSimulation() {
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
    roastState = RoastState.idle;
  }

  void preheat() {
    // Limpa os dados do gráfico de uma torra anterior
    btPoints.clear();
    rorPoints.clear();
    btPoints.add(const FlSpot(0, 208)); // Começa o gráfico na temp de pre-aquecimento
    rorPoints.add(const FlSpot(0, 0));

    roastState = RoastState.preheating;
    drumTemp = 208.0;
    heatInput = 75.0;
    airFlow = 25.0;
  }

  void chargeBeans() {
    roastState = RoastState.roasting;
    roastSeconds = 0;
    btPoints.clear();
    rorPoints.clear();

    const double drumMassKg = 2.0;
    const double batchSizeKg = batchSizeGrams / 1000.0;
    final initialBeanTemp = (drumMassKg * drumTemp + batchSizeKg * ambientTemp) / (drumMassKg + batchSizeKg);

    ror = -90.0;
    beanTemp = initialBeanTemp;

    btPoints.add(FlSpot(0, initialBeanTemp));
    rorPoints.add(const FlSpot(0, 0));
  }

  void stopRoast() {
    roastState = RoastState.idle;
  }

  void updateRoastPhysics() {
    roastSeconds++;

    double heatEffect = (heatInput / 100) * 15.0;
    double airCooling = (airFlow / 100) * 6.0;
    double environmentalLoss = (beanTemp - ambientTemp) * 0.022;

    double targetRoR = heatEffect - airCooling - environmentalLoss;

    ror = ror + (targetRoR - ror) * 0.04;
    beanTemp += (ror / 60);
    drumTemp = beanTemp * 1.05;

    double timeInMinutes = roastSeconds / 60;
    btPoints.add(FlSpot(timeInMinutes, beanTemp));
    rorPoints.add(FlSpot(timeInMinutes, ror < 0 ? 0 : ror));
  }

  void updateDrumPhysics({bool coolingDown = false}) {
    double heatEffect = coolingDown ? 0 : (heatInput / 100) * 18.0;
    double airCooling = (airFlow / 100) * 6.5;
    double environmentalLoss = (drumTemp - ambientTemp) * 0.02;

    double delta = heatEffect - airCooling - environmentalLoss;

    ror = delta;
    drumTemp += (delta / 60);
    if (drumTemp < ambientTemp) drumTemp = ambientTemp;
  }

  void updatePhysics() {
    switch (roastState) {
      case RoastState.preheating:
        updateDrumPhysics();
        break;
      case RoastState.roasting:
        updateRoastPhysics();
        break;
      case RoastState.idle:
        if (drumTemp > ambientTemp) {
          updateDrumPhysics(coolingDown: true);
        }
        break;
    }
  }
}
