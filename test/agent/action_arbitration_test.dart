import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/services/agent/action_arbitration.dart';
import 'package:rst/core/services/agent/intent_agent.dart';

void main() {
  group('ActionArbitration', () {
    const service = ActionArbitration();

    test('orders actions by computed priority score', () {
      final highPriority = _candidate(
        characterId: 'high',
        intent: '抢先攻击',
        timePressure: 0.95,
        feasibility: 0.9,
        underThreat: true,
        reactionPriority: 8,
      );

      final lowPriority = _candidate(
        characterId: 'low',
        intent: '继续观察',
        timePressure: 0.2,
        feasibility: 0.7,
        reactionPriority: 1,
      );

      final result = service.arbitrate(
        ActionArbitrationRequest(
          sceneTurnId: 'turn_1',
          candidates: [lowPriority, highPriority],
        ),
      );

      expect(result.executionOrder.length, equals(2));
      expect(result.executionOrder.first.characterId, equals('high'));
      expect(result.renderedActions.first.characterId, equals('high'));
    });

    test('suppresses lower-priority opposing intent', () {
      final attacker = _candidate(
        characterId: 'attacker',
        intent: '攻击目标',
        timePressure: 0.9,
        feasibility: 0.88,
        reactionPriority: 8,
      );

      final defender = _candidate(
        characterId: 'defender',
        intent: '保护目标',
        timePressure: 0.6,
        feasibility: 0.55,
        reactionPriority: 3,
      );

      final result = service.arbitrate(
        ActionArbitrationRequest(
          sceneTurnId: 'turn_2',
          candidates: [attacker, defender],
        ),
      );

      expect(result.renderedActions.length, equals(1));
      expect(result.renderedActions.first.characterId, equals('attacker'));
      expect(result.suppressedActions.length, equals(1));
      expect(result.suppressedActions.first.characterId, equals('defender'));
      expect(result.conflicts.length, equals(1));
      expect(
        result.conflicts.first.type,
        equals(ArbitrationConflictType.opposingIntent),
      );
    });

    test('keeps non-conflicting actions', () {
      final speaker = _candidate(
        characterId: 'speaker',
        intent: '说明情况',
        stepType: ActionStepType.verbal,
        feasibility: 0.8,
      );
      final mover = _candidate(
        characterId: 'mover',
        intent: '移动到门口',
        stepType: ActionStepType.physical,
        feasibility: 0.78,
      );

      final result = service.arbitrate(
        ActionArbitrationRequest(
          sceneTurnId: 'turn_3',
          candidates: [speaker, mover],
        ),
      );

      expect(result.renderedActions.length, equals(2));
      expect(result.suppressedActions, isEmpty);
      expect(result.conflicts, isEmpty);
    });
  });
}

ActionArbitrationCandidate _candidate({
  required String characterId,
  required String intent,
  double timePressure = 0.5,
  double feasibility = 0.8,
  int reactionPriority = 0,
  bool directlyAddressed = false,
  bool underThreat = false,
  ActionStepType stepType = ActionStepType.verbal,
  RevealLevel revealLevel = RevealLevel.direct,
}) {
  final intentPlan = IntentPlan(
    activeGoals: const CurrentGoals(shortTerm: ['survive']),
    decisionFrame: DecisionFrame(
      context: 'test',
      constraints: 'none',
      timePressure: timePressure,
    ),
    candidateIntents: const [
      CandidateIntent(intentId: 'i1', description: '执行动作', priority: 0.8),
    ],
    selectedIntent: SelectedIntent(intent: intent, reason: 'test reason'),
    expressionConstraints: ExpressionConstraints(
      revealLevel: revealLevel,
      tone: 'steady',
      behavioralNotes: const ['观察对方反应'],
    ),
  );

  final cognitiveOutput = CharacterCognitivePassOutput(
    characterId: characterId,
    sceneTurnId: 'turn_x',
    perceptionDelta: const PerceptionDelta(),
    beliefUpdate: const BeliefUpdate(
      emotionalShift: EmotionalShift(
        emotion: 'neutral',
        oldIntensity: 0.3,
        newIntensity: 0.3,
        trigger: 'none',
      ),
    ),
    intentPlan: intentPlan,
  );

  final intentExecution = IntentExecutionResult(
    characterId: characterId,
    selectedIntent: intentPlan.selectedIntent,
    expressionConstraints: intentPlan.expressionConstraints,
    actionPlan: ActionPlan(
      intentId: '$characterId-intent',
      description: intent,
      steps: [
        ActionStep(
          stepId: '$characterId-step',
          description: intent,
          type: stepType,
          feasibility: feasibility,
        ),
      ],
      estimatedOutcome: 'ok',
    ),
    feasibilityScore: feasibility,
    modifications: const [],
  );

  return ActionArbitrationCandidate(
    characterId: characterId,
    cognitiveOutput: cognitiveOutput,
    intentExecution: intentExecution,
    reactionPriority: reactionPriority,
    directlyAddressed: directlyAddressed,
    underThreat: underThreat,
  );
}
