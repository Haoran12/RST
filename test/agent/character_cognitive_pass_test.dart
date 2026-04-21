import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/baseline_body_profile.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/models/agent/embodiment_state.dart';
import 'package:rst/core/models/agent/filtered_scene_view.dart';
import 'package:rst/core/models/agent/mana_field.dart';
import 'package:rst/core/models/agent/memory_entry.dart';
import 'package:rst/core/models/agent/temporary_body_state.dart';
import 'package:rst/core/services/agent/character_cognitive_pass.dart';

void main() {
  group('CharacterCognitivePass', () {
    const cognitivePass = CharacterCognitivePass();

    group('buildPrompt', () {
      test('builds complete prompt with all sections', () {
        final input = _createTestInput();

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('# 角色认知传递'));
        expect(prompt, contains('## 角色信息'));
        expect(prompt, contains('## 具身状态'));
        expect(prompt, contains('## 感知输入'));
        expect(prompt, contains('## 身体状态'));
        expect(prompt, contains('## 当前信念状态'));
        expect(prompt, contains('## 情感状态'));
        expect(prompt, contains('## 当前目标'));
        expect(prompt, contains('## 输出要求'));
      });

      test('includes visible entities in prompt', () {
        final input = _createTestInput(
          filteredSceneView: FilteredSceneView(
            characterId: 'test_char',
            sceneTurnId: 'turn_1',
            visibleEntities: [
              const VisibleEntity(
                entityId: 'entity_1',
                visibilityScore: 0.9,
                clarity: 0.8,
                notes: 'standing nearby',
              ),
            ],
            spatialContext: const SpatialContext(),
          ),
        );

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('entity_1'));
        expect(prompt, contains('standing nearby'));
      });

      test('includes mana signals when present', () {
        final input = _createTestInput(
          filteredSceneView: FilteredSceneView(
            characterId: 'test_char',
            sceneTurnId: 'turn_1',
            manaSignals: [
              ManaSignal(
                signalId: 'mana_1',
                content: '修士气息',
                sourceType: ManaSourceType.cultivatorAura,
                perceivedIntensity: 0.7,
                attribute: ManaAttribute.fire,
                clarity: 0.6,
                direction: 'north',
              ),
            ],
            spatialContext: const SpatialContext(),
          ),
        );

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('灵觉信号'));
        expect(prompt, contains('修士气息'));
        expect(prompt, contains('cultivatorAura'));
      });

      test('includes accessible memories', () {
        final input = _createTestInput(
          accessibleMemories: [
            MemoryEntry(
              memoryId: 'mem_1',
              content: '上次见到的陌生人',
              ownerCharacterId: 'test_char',
              knownBy: ['test_char'],
              visibility: MemoryVisibility.private,
              createdAt: DateTime.now(),
            ),
          ],
        );

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('## 可访问记忆'));
        expect(prompt, contains('上次见到的陌生人'));
      });

      test('includes current goals', () {
        final input = _createTestInput(
          currentGoals: CurrentGoals(
            shortTerm: ['调查陌生人身份'],
            mediumTerm: ['找到失踪的弟子'],
            hidden: ['隐藏自己的修为'],
          ),
        );

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('调查陌生人身份'));
        expect(prompt, contains('找到失踪的弟子'));
        expect(prompt, contains('隐藏自己的修为'));
      });

      test('includes sensory blocks', () {
        final input = _createTestInput(
          bodyState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(
              visionBlocked: true,
              manaBlocked: true,
            ),
          ),
        );

        final prompt = cognitivePass.buildPrompt(input);

        expect(prompt, contains('视觉被阻断'));
        expect(prompt, contains('灵觉被阻断'));
      });
    });

    group('parseOutput', () {
      test('parses valid JSON output', () {
        const rawResponse = '''
```json
{
  "perceptionDelta": {
    "noticedFacts": [
      {"factId": "fact_1", "content": "看到一个人影", "sourceType": "visual", "confidence": 0.9}
    ],
    "immediateConcerns": ["陌生人可能危险"]
  },
  "beliefUpdate": {
    "emotionalShift": {
      "emotion": "suspicion",
      "oldIntensity": 0.3,
      "newIntensity": 0.6,
      "trigger": "看到陌生人"
    }
  },
  "intentPlan": {
    "activeGoals": {"shortTerm": ["调查"], "mediumTerm": [], "hidden": []},
    "decisionFrame": {"context": "陌生人出现", "constraints": "需要谨慎", "timePressure": 0.3},
    "selectedIntent": {
      "intent": "观察对方行为",
      "reason": "需要更多信息判断对方意图"
    },
    "expressionConstraints": {
      "revealLevel": "guarded",
      "tone": "neutral"
    }
  }
}
```
''';

        final output = cognitivePass.parseOutput(rawResponse, 'test_char', 'turn_1');

        expect(output.characterId, equals('test_char'));
        expect(output.sceneTurnId, equals('turn_1'));
        expect(output.perceptionDelta.noticedFacts.length, equals(1));
        expect(output.perceptionDelta.noticedFacts.first.content, equals('看到一个人影'));
        expect(output.intentPlan.selectedIntent.intent, equals('观察对方行为'));
        expect(output.intentPlan.expressionConstraints.revealLevel, equals(RevealLevel.guarded));
      });

      test('handles JSON without code blocks', () {
        const rawResponse = '''
{
  "perceptionDelta": {"noticedFacts": [], "immediateConcerns": []},
  "beliefUpdate": {
    "emotionalShift": {"emotion": "neutral", "oldIntensity": 0.5, "newIntensity": 0.5, "trigger": "none"}
  },
  "intentPlan": {
    "activeGoals": {"shortTerm": [], "mediumTerm": [], "hidden": []},
    "decisionFrame": {"context": "", "constraints": "", "timePressure": 0.0},
    "selectedIntent": {"intent": "等待", "reason": "无明确目标"},
    "expressionConstraints": {"revealLevel": "direct"}
  }
}
''';

        final output = cognitivePass.parseOutput(rawResponse, 'test_char', 'turn_1');

        expect(output.characterId, equals('test_char'));
        expect(output.intentPlan.selectedIntent.intent, equals('等待'));
      });

      test('creates fallback output for invalid JSON', () {
        const rawResponse = 'This is not valid JSON at all.';

        final output = cognitivePass.parseOutput(rawResponse, 'test_char', 'turn_1');

        expect(output.characterId, equals('test_char'));
        expect(output.perceptionDelta.noticedFacts.length, equals(1));
        expect(output.perceptionDelta.noticedFacts.first.sourceType, equals('fallback'));
        expect(output.intentPlan.selectedIntent.intent, equals('等待进一步信息'));
      });

      test('creates fallback output for malformed JSON', () {
        const rawResponse = '''
```json
{
  "perceptionDelta": {invalid json here}
}
```
''';

        final output = cognitivePass.parseOutput(rawResponse, 'test_char', 'turn_1');

        expect(output.perceptionDelta.noticedFacts.first.sourceType, equals('fallback'));
      });

      test('parses mana signal insights', () {
        const rawResponse = '''
{
  "perceptionDelta": {
    "noticedFacts": [
      {"factId": "mana_fact", "content": "感知到火属性灵力", "sourceType": "mana", "confidence": 0.8}
    ],
    "immediateConcerns": []
  },
  "beliefUpdate": {
    "emotionalShift": {"emotion": "alert", "oldIntensity": 0.2, "newIntensity": 0.5, "trigger": "灵力波动"}
  },
  "intentPlan": {
    "activeGoals": {"shortTerm": [], "mediumTerm": [], "hidden": []},
    "decisionFrame": {"context": "", "constraints": "", "timePressure": 0.0},
    "selectedIntent": {"intent": "警惕", "reason": "感知到修士气息"},
    "expressionConstraints": {"revealLevel": "masked"}
  }
}
''';

        final output = cognitivePass.parseOutput(rawResponse, 'test_char', 'turn_1');

        expect(output.perceptionDelta.noticedFacts.first.sourceType, equals('mana'));
        expect(output.intentPlan.expressionConstraints.revealLevel, equals(RevealLevel.masked));
      });
    });

    group('validateOutput', () {
      test('returns no errors for valid output', () {
        final input = _createTestInput();
        final output = CharacterCognitivePassOutput(
          characterId: 'test_char',
          sceneTurnId: 'turn_1',
          perceptionDelta: const PerceptionDelta(),
          beliefUpdate: BeliefUpdate(
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(context: '', constraints: '', timePressure: 0.0),
            selectedIntent: const SelectedIntent(intent: '等待', reason: '无明确意图'),
            expressionConstraints: const ExpressionConstraints(revealLevel: RevealLevel.guarded),
          ),
        );

        final issues = cognitivePass.validateOutput(output, input);

        expect(issues.where((i) => i.severity == ValidationSeverity.error), isEmpty);
      });

      test('detects embodiment ignored for visual facts when vision unavailable', () {
        final input = _createTestInput(
          filteredSceneView: const FilteredSceneView(
            characterId: 'test_char',
            sceneTurnId: 'turn_1',
            spatialContext: SpatialContext(),
          ),
        ).copyWith(
          embodimentState: const EmbodimentState(
            characterId: 'test_char',
            sceneTurnId: 'turn_1',
            sensoryCapabilities: SensoryCapabilities(
              vision: SensoryCapability(availability: 0.0, acuity: 0.0),
              hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
              smell: SensoryCapability(availability: 1.0, acuity: 1.0),
              touch: SensoryCapability(availability: 1.0, acuity: 1.0),
              proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
              mana: ManaSensoryCapability(availability: 1.0, acuity: 1.0),
            ),
            bodyConstraints: BodyConstraints(mobility: 1.0, balance: 1.0, painLoad: 0.0, fatigue: 0.0, cognitiveClarity: 1.0),
            salienceModifiers: SalienceModifiers(),
            reasoningModifiers: ReasoningModifiers(cognitiveClarity: 1.0, painBias: 0.0, threatBias: 0.0, overloadBias: 0.0),
            actionFeasibility: ActionFeasibility(physicalExecutionCapacity: 1.0, socialPatience: 1.0, fineControl: 1.0, sustainedAttention: 1.0),
          ),
        );

        final output = CharacterCognitivePassOutput(
          characterId: 'test_char',
          sceneTurnId: 'turn_1',
          perceptionDelta: PerceptionDelta(
            noticedFacts: const [
              NoticedFact(factId: 'fact_1', content: '看到东西', sourceType: 'visual'),
            ],
          ),
          beliefUpdate: BeliefUpdate(
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(context: '', constraints: '', timePressure: 0.0),
            selectedIntent: const SelectedIntent(intent: '等待', reason: '无明确意图'),
            expressionConstraints: const ExpressionConstraints(revealLevel: RevealLevel.guarded),
          ),
        );

        final issues = cognitivePass.validateOutput(output, input);

        expect(
          issues.any((i) => i.type == ValidationIssueType.embodimentIgnored),
          isTrue,
        );
      });

      test('detects memory leakage for inaccessible memories', () {
        final input = _createTestInput(
          accessibleMemories: [
            MemoryEntry(
              memoryId: 'memory_1',
              content: '可访问的记忆',
              ownerCharacterId: 'test_char',
              knownBy: ['test_char'],
              visibility: MemoryVisibility.private,
              createdAt: DateTime.now(),
            ),
          ],
        );

        final output = CharacterCognitivePassOutput(
          characterId: 'test_char',
          sceneTurnId: 'turn_1',
          perceptionDelta: PerceptionDelta(
            memoryActivations: const [
              MemoryActivation(
                memoryId: 'inaccessible_memory',
                activationReason: 'triggered',
                relevanceScore: 0.8,
              ),
            ],
          ),
          beliefUpdate: BeliefUpdate(
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(context: '', constraints: '', timePressure: 0.0),
            selectedIntent: const SelectedIntent(intent: '等待', reason: '无明确意图'),
            expressionConstraints: const ExpressionConstraints(revealLevel: RevealLevel.guarded),
          ),
        );

        final issues = cognitivePass.validateOutput(output, input);

        expect(
          issues.any((i) => i.type == ValidationIssueType.memoryLeakage),
          isTrue,
        );
      });

      test('detects high severity belief contradictions', () {
        final input = _createTestInput();

        final output = CharacterCognitivePassOutput(
          characterId: 'test_char',
          sceneTurnId: 'turn_1',
          perceptionDelta: const PerceptionDelta(),
          beliefUpdate: BeliefUpdate(
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
            contradictionsAndTension: const [
              ContradictionAndTension(
                description: '信念冲突',
                involvedBeliefs: ['belief_1', 'belief_2'],
                severity: 0.8,
              ),
            ],
          ),
          intentPlan: IntentPlan(
            activeGoals: const CurrentGoals(),
            decisionFrame: const DecisionFrame(context: '', constraints: '', timePressure: 0.0),
            selectedIntent: const SelectedIntent(intent: '等待', reason: '无明确意图'),
            expressionConstraints: const ExpressionConstraints(revealLevel: RevealLevel.guarded),
          ),
        );

        final issues = cognitivePass.validateOutput(output, input);

        expect(
          issues.any((i) => i.type == ValidationIssueType.beliefContradiction),
          isTrue,
        );
      });
    });
  });
}

CharacterCognitivePassInput _createTestInput({
  FilteredSceneView? filteredSceneView,
  TemporaryBodyState? bodyState,
  List<MemoryEntry>? accessibleMemories,
  CurrentGoals? currentGoals,
}) {
  return CharacterCognitivePassInput(
    characterId: 'test_char',
    sceneTurnId: 'turn_1',
    filteredSceneView: filteredSceneView ?? const FilteredSceneView(
      characterId: 'test_char',
      sceneTurnId: 'turn_1',
      spatialContext: SpatialContext(),
    ),
    embodimentState: const EmbodimentState(
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
    ),
    bodyState: bodyState ?? const TemporaryBodyState(sensoryBlocks: SensoryBlocks()),
    accessibleMemories: accessibleMemories ?? [],
    priorBeliefState: const BeliefState(),
    relationModels: {},
    emotionState: const EmotionState(),
    currentGoals: currentGoals ?? const CurrentGoals(),
  );
}
