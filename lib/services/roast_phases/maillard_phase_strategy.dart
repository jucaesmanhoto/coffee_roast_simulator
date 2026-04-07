import 'dart:math';

import '../roast_simulator_service.dart';
import './roast_phase_strategy.dart';

class MaillardPhaseStrategy implements RoastPhaseStrategy {
  static const double _dryingEndMoistureLossRate =
      (RoastSimulatorService.dryingToEndTemp - 80.0) / 80000.0;
  static const double _maillardMoistureDecaySpan = 55.0;

  @override
  PhasePhysicsResult calculatePhysics(RoastSimulatorService simulator) {
    final trueBeanCoreTemp = simulator.trueBeanCoreTemp;
    final drumTemp = simulator.drumTemp;
    final airTemp = simulator.airTemp;
    final airFlow = simulator.airFlow;

    final qTransfer = (0.9 * (drumTemp - trueBeanCoreTemp)) +
        ((0.7 + airFlow / 100) * (airTemp - trueBeanCoreTemp));

    // A perda evaporativa continua relevante no início de Maillard e cai aos poucos.
    final double maillardProgress = (((trueBeanCoreTemp -
            RoastSimulatorService.dryingToEndTemp) /
          _maillardMoistureDecaySpan)
        .clamp(0.0, 1.0))
      .toDouble();
    final double moistureLossRate =
      _dryingEndMoistureLossRate * pow(1.0 - maillardProgress, 1.35).toDouble();
    final qEvaporativeCooling =
        (simulator.currentBatchMassGrams / 1000.0) * moistureLossRate * 2260 * 1000;

    final transitionStart = RoastSimulatorService.dryingToEndTemp -
        (RoastSimulatorService.dryingToMaillardTransitionWidth / 2);
    final double transitionFactor = (((trueBeanCoreTemp - transitionStart) /
          RoastSimulatorService.dryingToMaillardTransitionWidth)
        .clamp(0.0, 1.0))
      .toDouble();

    return PhasePhysicsResult(
      qTransfer: qTransfer,
      qEvaporativeCooling: qEvaporativeCooling,
      qReaction: 250 * pow(transitionFactor, 1.8).toDouble(),
      moistureLossRate: moistureLossRate,
    );
  }
}
