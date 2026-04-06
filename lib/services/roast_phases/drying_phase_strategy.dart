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
    final currentBatchMassKg = simulator.currentBatchMassGrams / 1000.0;

    // Transferência de calor é alta devido ao vapor
    final qTransfer = (0.9 * (drumTemp - trueBeanCoreTemp)) +
        ((0.7 + airFlow / 100) * 1.5 * (airTemp - trueBeanCoreTemp));

    // Perda de umidade é máxima
    final moistureLossRate = max(0, (trueBeanCoreTemp - 80) / 80000);
    final moistureMassLossKg = currentBatchMassKg * moistureLossRate;
    final qEvaporativeCooling = moistureMassLossKg * 2260 * 1000; // 2260 kJ/kg -> J

    // Atualiza umidade e massa
    if (simulator.coffee.currentMoisture > 2.0) {
      simulator.coffee.currentMoisture -= moistureLossRate * 100;
      simulator.currentBatchMassGrams -= moistureMassLossKg * 1000;
    }

    return PhasePhysicsResult(
      qTransfer: qTransfer,
      qEvaporativeCooling: qEvaporativeCooling,
      qReaction: 0, // Reação puramente endotérmica
    );
  }
}
