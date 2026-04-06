import '../roast_simulator_service.dart';
import './roast_phase_strategy.dart';

class DevelopmentPhaseStrategy implements RoastPhaseStrategy {
  @override
  PhasePhysicsResult calculatePhysics(RoastSimulatorService simulator) {
    final trueBeanCoreTemp = simulator.trueBeanCoreTemp;
    final drumTemp = simulator.drumTemp;
    final airTemp = simulator.airTemp;
    final airFlow = simulator.airFlow;
    final currentBatchMassKg = simulator.currentBatchMassGrams / 1000.0;

    final qTransfer = (0.9 * (drumTemp - trueBeanCoreTemp)) +
        ((0.7 + airFlow / 100) * (airTemp - trueBeanCoreTemp));

    double qReaction;
    // Lógica do 1º Crack (pós 192°C)
    if (trueBeanCoreTemp >= RoastSimulatorService.maillardToEndTemp && !simulator.firstCrackHappened) {
      qReaction = 232000 * currentBatchMassKg; // Pulso de energia de 232 kJ/kg
      simulator.firstCrackHappened = true;
    } else {
      // Reações de pirólise contínuas
      qReaction = 3000; // J/s
    }

    return PhasePhysicsResult(qTransfer: qTransfer, qReaction: qReaction);
  }
}
