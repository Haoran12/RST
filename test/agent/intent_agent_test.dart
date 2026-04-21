import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/models/agent/embodiment_state.dart';
import 'package:rst/core/services/agent/intent_agent.dart';

void main() {
  group('IntentAgent', () {
    const agent = IntentAgent();

    group('execute', () {
      test('executes high-feasibility intent', () {
        final request = _createRequest(
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Normal situation',
              constraints: 'None',
              timePressure: 0.3,
            ),
            selectedIntent: const SelectedIntent(
              intent: '问候对方',
              reason: '礼貌性问候',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.selectedIntent.intent, equals('问候对方'));
        expect(result.feasibilityScore, greaterThan(0.5));
        expect(result.actionPlan.steps.isNotEmpty, isTrue);
      });

      test('simplifies low-feasibility intent', () {
        final request = _createRequest(
          embodimentState: _lowMobilityEmbodiment,
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Combat situation',
              constraints: 'Limited mobility',
              timePressure: 0.8,
            ),
            selectedIntent: const SelectedIntent(
              intent: '快速移动到敌人身后攻击',
              reason: '战术需要',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.feasibilityScore, lessThan(0.5));
        expect(result.modifications.any((m) => m.type == IntentModificationType.actionSimplified), isTrue);
      });

      test('adjusts expression for high-intensity emotion', () {
        final request = _createRequest(
          emotionState: const EmotionState(
            emotions: {'anger': 0.8},
          ),
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Provocation',
              constraints: 'Need to stay calm',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '回应对方',
              reason: '不能示弱',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.masked,
              tone: 'neutral',
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.expressionConstraints.revealLevel, equals(RevealLevel.guarded));
        expect(result.modifications.any((m) => m.type == IntentModificationType.revealLevelDowngraded), isTrue);
      });

      test('adjusts expression for low cognitive clarity', () {
        final request = _createRequest(
          embodimentState: _lowClarityEmbodiment,
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Confusing situation',
              constraints: 'Mental fog',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '分析局势',
              reason: '需要理解当前状况',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.masked,
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.modifications.any((m) => m.type == IntentModificationType.revealLevelDowngraded), isTrue);
      });

      test('generates action plan with correct steps', () {
        final request = _createRequest(
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Investigation',
              constraints: 'Need information',
              timePressure: 0.2,
            ),
            selectedIntent: const SelectedIntent(
              intent: '询问路人',
              reason: '获取方向信息',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.guarded,
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.actionPlan.steps.isNotEmpty, isTrue);
        expect(result.actionPlan.steps.first.type, equals(ActionStepType.verbal));
        // Low time pressure should add observation step
        expect(result.actionPlan.steps.length, greaterThan(1));
      });

      test('identifies risks based on embodiment state', () {
        final request = _createRequest(
          embodimentState: _painfulEmbodiment,
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: 'Action needed',
              constraints: 'In pain',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '战斗',
              reason: '自卫',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        );

        final result = agent.execute(request);

        expect(result.actionPlan.risks.isNotEmpty, isTrue);
      });
    });

    group('resolveConflicts', () {
      test('resolves single intent without conflict', () {
        final result1 = agent.execute(_createRequest(
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: '',
              constraints: '',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '等待',
              reason: 'No action needed',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        ));

        final resolution = agent.resolveConflicts([result1]);

        expect(resolution.resolved, isTrue);
        expect(resolution.finalOrder.length, equals(1));
        expect(resolution.adjustments.isEmpty, isTrue);
      });

      test('orders multiple intents by feasibility', () {
        final result1 = agent.execute(_createRequest(
          characterId: 'char_a',
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: '',
              constraints: '',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '攻击',
              reason: 'Combat',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        ));

        final result2 = agent.execute(_createRequest(
          characterId: 'char_b',
          embodimentState: _lowMobilityEmbodiment,
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: '',
              constraints: '',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '移动攻击',
              reason: 'Combat',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        ));

        final resolution = agent.resolveConflicts([result1, result2]);

        expect(resolution.finalOrder.first, equals('char_a'));
      });

      test('detects opposing intents', () {
        final result1 = agent.execute(_createRequest(
          characterId: 'attacker',
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: '',
              constraints: '',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '攻击目标',
              reason: 'Aggression',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        ));

        final result2 = agent.execute(_createRequest(
          characterId: 'defender',
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(
              context: '',
              constraints: '',
              timePressure: 0.5,
            ),
            selectedIntent: const SelectedIntent(
              intent: '保护目标',
              reason: 'Protection',
            ),
            expressionConstraints: const ExpressionConstraints(
              revealLevel: RevealLevel.direct,
            ),
          ),
        ));

        final resolution = agent.resolveConflicts([result1, result2]);

        expect(resolution.adjustments.isNotEmpty, isTrue);
        expect(resolution.adjustments.first.conflictType, equals(ConflictType.opposingIntent));
      });
    });
  });
}

IntentExecutionRequest _createRequest({
  String characterId = 'test_char',
  EmbodimentState? embodimentState,
  EmotionState? emotionState,
  IntentPlan? intentPlan,
}) {
  return IntentExecutionRequest(
    characterId: characterId,
    intentPlan: intentPlan ?? IntentPlan(
      activeGoals: const CurrentGoals(),
      decisionFrame: const DecisionFrame(
        context: '',
        constraints: '',
        timePressure: 0.5,
      ),
      selectedIntent: const SelectedIntent(
        intent: '等待',
        reason: 'No action',
      ),
      expressionConstraints: const ExpressionConstraints(
        revealLevel: RevealLevel.direct,
      ),
    ),
    embodimentState: embodimentState ?? _normalEmbodiment,
    emotionState: emotionState ?? const EmotionState(),
    beliefState: const BeliefState(),
  );
}

const _normalEmbodiment = EmbodimentState(
  characterId: 'test_char',
  sceneTurnId: 'turn_1',
  sensoryCapabilities: SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability(availability: 1.0, acuity: 1.0),
  ),
  bodyConstraints: BodyConstraints(
    mobility: 1.0,
    balance: 1.0,
    painLoad: 0.0,
    fatigue: 0.0,
    cognitiveClarity: 1.0,
  ),
  salienceModifiers: SalienceModifiers(),
  reasoningModifiers: ReasoningModifiers(
    cognitiveClarity: 1.0,
    painBias: 0.0,
    threatBias: 0.0,
    overloadBias: 0.0,
  ),
  actionFeasibility: ActionFeasibility(
    physicalExecutionCapacity: 1.0,
    socialPatience: 1.0,
    fineControl: 1.0,
    sustainedAttention: 1.0,
  ),
);

const _lowMobilityEmbodiment = EmbodimentState(
  characterId: 'test_char',
  sceneTurnId: 'turn_1',
  sensoryCapabilities: SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability(availability: 1.0, acuity: 1.0),
  ),
  bodyConstraints: BodyConstraints(
    mobility: 0.2,
    balance: 0.5,
    painLoad: 0.3,
    fatigue: 0.4,
    cognitiveClarity: 0.8,
  ),
  salienceModifiers: SalienceModifiers(),
  reasoningModifiers: ReasoningModifiers(
    cognitiveClarity: 0.8,
    painBias: 0.3,
    threatBias: 0.2,
    overloadBias: 0.1,
  ),
  actionFeasibility: ActionFeasibility(
    physicalExecutionCapacity: 0.3,
    socialPatience: 0.8,
    fineControl: 0.5,
    sustainedAttention: 0.7,
  ),
);

const _lowClarityEmbodiment = EmbodimentState(
  characterId: 'test_char',
  sceneTurnId: 'turn_1',
  sensoryCapabilities: SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability(availability: 1.0, acuity: 1.0),
  ),
  bodyConstraints: BodyConstraints(
    mobility: 1.0,
    balance: 1.0,
    painLoad: 0.0,
    fatigue: 0.5,
    cognitiveClarity: 0.2,
  ),
  salienceModifiers: SalienceModifiers(),
  reasoningModifiers: ReasoningModifiers(
    cognitiveClarity: 0.2,
    painBias: 0.0,
    threatBias: 0.0,
    overloadBias: 0.8,
  ),
  actionFeasibility: ActionFeasibility(
    physicalExecutionCapacity: 1.0,
    socialPatience: 0.5,
    fineControl: 0.3,
    sustainedAttention: 0.4,
  ),
);

const _painfulEmbodiment = EmbodimentState(
  characterId: 'test_char',
  sceneTurnId: 'turn_1',
  sensoryCapabilities: SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability(availability: 1.0, acuity: 1.0),
  ),
  bodyConstraints: BodyConstraints(
    mobility: 0.7,
    balance: 0.8,
    painLoad: 0.6,
    fatigue: 0.4,
    cognitiveClarity: 0.7,
  ),
  salienceModifiers: SalienceModifiers(),
  reasoningModifiers: ReasoningModifiers(
    cognitiveClarity: 0.7,
    painBias: 0.5,
    threatBias: 0.3,
    overloadBias: 0.2,
  ),
  actionFeasibility: ActionFeasibility(
    physicalExecutionCapacity: 0.6,
    socialPatience: 0.7,
    fineControl: 0.5,
    sustainedAttention: 0.6,
  ),
);
