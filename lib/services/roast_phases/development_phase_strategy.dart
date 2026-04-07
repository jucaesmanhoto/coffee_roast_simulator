import '../roast_simulator_service.dart';
import './roast_phase_strategy.dart';

class DevelopmentPhaseStrategy implements RoastPhaseStrategy {
  static const double _developmentReactionBase = 320.0;
  static const double _developmentReactionPeak = 520.0;
  static const double _developmentReactionRampSpan = 20.0;

  @override
  PhasePhysicsResult calculatePhysics(RoastSimulatorService simulator) {
    final trueBeanCoreTemp = simulator.trueBeanCoreTemp;
    final drumTemp = simulator.drumTemp;
    final airTemp = simulator.airTemp;
    final airFlow = simulator.airFlow;

    final qTransfer = (0.9 * (drumTemp - trueBeanCoreTemp)) +
        ((0.7 + airFlow / 100) * (airTemp - trueBeanCoreTemp));

    final reactionProgress = (((trueBeanCoreTemp -
                    RoastSimulatorService.maillardToEndTemp) /
                _developmentReactionRampSpan)
            .clamp(0.0, 1.0))
        .toDouble();
    final qReaction = _developmentReactionBase +
        ((_developmentReactionPeak - _developmentReactionBase) * reactionProgress);

    return PhasePhysicsResult(qTransfer: qTransfer, qReaction: qReaction);
  }
}
