import 'dart:math';

import '../roast_simulator_service.dart';
import './roast_phase_strategy.dart';

class DryingPhaseStrategy implements RoastPhaseStrategy {
  @override
  PhasePhysicsResult calculatePhysics(RoastSimulatorService simulator) {
    final trueBeanCoreTemp = simulator.trueBeanCoreTemp;
    final drumTemp = simulator.drumTemp;
    final airTemp = simulator.airTemp;
    final airFlow = simulator.airFlow;

    // Transferência de calor é alta devido ao vapor
    final qTransfer = (0.9 * (drumTemp - trueBeanCoreTemp)) +
        ((0.7 + airFlow / 100) * 1.5 * (airTemp - trueBeanCoreTemp));

    // Perda de umidade é máxima
    final double moistureLossRate =
      max(0.0, (trueBeanCoreTemp - 80.0) / 80000.0);
    final qEvaporativeCooling =
        (simulator.currentBatchMassGrams / 1000.0) * moistureLossRate * 2260 * 1000;

    return PhasePhysicsResult(
      qTransfer: qTransfer,
      qEvaporativeCooling: qEvaporativeCooling,
      qReaction: 0, // Reação puramente endotérmica
      moistureLossRate: moistureLossRate,
    );
  }
}
