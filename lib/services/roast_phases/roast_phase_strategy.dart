import '../roast_simulator_service.dart';

/// Representa o resultado dos cálculos de física para uma fase da torra.
class PhasePhysicsResult {
  final double qTransfer;
  final double qEvaporativeCooling;
  final double qReaction;
  final double moistureLossRate;

  PhasePhysicsResult({
    this.qTransfer = 0,
    this.qEvaporativeCooling = 0,
    this.qReaction = 0,
    this.moistureLossRate = 0,
  });
}

/// Classe base abstrata para a estratégia de cálculo de física de uma fase da torra.
/// Utiliza o padrão Strategy para separar a lógica de cada fase.
abstract class RoastPhaseStrategy {
  PhasePhysicsResult calculatePhysics(RoastSimulatorService simulator);
}
