import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/baseline_body_profile.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/models/agent/dirty_flags.dart';
import 'package:rst/core/models/agent/scene_model.dart';
import 'package:rst/core/models/agent/temporary_body_state.dart';
import 'package:rst/core/models/common.dart';
import 'package:rst/core/services/agent/action_arbitration.dart';
import 'package:rst/core/services/agent/agent_runtime.dart';
import 'package:rst/core/services/agent/character_input_assembly.dart';
import 'package:rst/core/services/agent/cognitive_pass_executor.dart';
import 'package:rst/core/services/agent/embodiment_resolver.dart';
import 'package:rst/core/services/agent/memory_access_protocol.dart';
import 'package:rst/core/services/agent/scene_filtering_protocol.dart';
import 'package:rst/core/services/agent/scene_state_extractor.dart';
import 'package:rst/core/services/agent/surface_realizer.dart';
import 'package:rst/core/services/api_service.dart';

void main() {
  group('AgentRuntime', () {
    const runtime = AgentRuntime(
      sceneExtractor: SceneStateExtractor(),
      inputAssembly: CharacterInputAssembly(
        SceneStateExtractor(),
        EmbodimentResolver(),
        SceneFilteringProtocol(),
        MemoryAccessProtocol(),
      ),
      cognitivePassExecutor: CognitivePassExecutor(),
      actionArbitration: ActionArbitration(),
      surfaceRealizer: SurfaceRealizer(),
    );

    test('processes only dirty characters', () async {
      final characterStates = <String, CharacterRuntimeState>{
        'char_a': _buildCharacterState('char_a'),
        'char_b': _buildCharacterState('char_b'),
      };

      final result = await runtime.processTurn(
        AgentTurnRequest(
          sceneId: 'scene_1',
          sceneTurnId: 'turn_1',
          characterStates: characterStates,
          previousScene: _scene,
          apiConfig: _apiConfig,
          model: 'test-model',
          dirtyFlagsByCharacter: const {
            'char_a': DirtyFlags(sceneChanged: true, directlyAddressed: true),
            'char_b': DirtyFlags(),
          },
          visibleSceneChanges: const ['门缝透进冷风。'],
        ),
        modelCall: (input) async {
          if (input.characterId != 'char_a') {
            throw StateError('Unexpected model call for ${input.characterId}');
          }
          return _buildCognitiveOutput(
            characterId: input.characterId,
            sceneTurnId: input.sceneTurnId,
            intent: '攻击目标',
            timePressure: 0.9,
            candidatePriority: 0.9,
          );
        },
      );

      expect(result.processedCharacters, equals({'char_a'}));
      expect(result.skippedCharacters, contains('char_b'));
      expect(result.executionResults.length, equals(1));
      expect(result.executionResults.containsKey('char_a'), isTrue);
      expect(
        result.updatedCharacterStates['char_a']!.currentEmbodimentState,
        isNotNull,
      );
      expect(
        result.updatedCharacterStates['char_b']!.currentEmbodimentState,
        isNull,
      );
      expect(result.arbitrationResult.renderedActions.length, equals(1));
      expect(
        result.arbitrationResult.renderedActions.first.characterId,
        equals('char_a'),
      );
      expect(result.renderedOutput.visibleActionDescriptions.length, equals(1));
      expect(result.renderedOutput.renderedText, contains('门缝透进冷风。'));
    });

    test('processes all active characters and resolves conflict', () async {
      final characterStates = <String, CharacterRuntimeState>{
        'char_a': _buildCharacterState('char_a'),
        'char_b': _buildCharacterState('char_b'),
      };

      final result = await runtime.processTurn(
        AgentTurnRequest(
          sceneId: 'scene_2',
          sceneTurnId: 'turn_2',
          characterStates: characterStates,
          previousScene: _scene,
          apiConfig: _apiConfig,
          model: 'test-model',
          processOnlyDirty: false,
          activeCharacterIds: const {'char_a', 'char_b'},
          visibleSceneChanges: const ['双方同时起势。'],
        ),
        modelCall: (input) async {
          if (input.characterId == 'char_a') {
            return _buildCognitiveOutput(
              characterId: input.characterId,
              sceneTurnId: input.sceneTurnId,
              intent: '攻击目标',
              timePressure: 0.95,
              candidatePriority: 0.95,
            );
          }
          return _buildCognitiveOutput(
            characterId: input.characterId,
            sceneTurnId: input.sceneTurnId,
            intent: '保护目标',
            timePressure: 0.2,
            candidatePriority: 0.2,
          );
        },
      );

      expect(result.processedCharacters.length, equals(2));
      expect(result.executionResults.length, equals(2));
      expect(result.arbitrationResult.conflicts, isNotEmpty);
      expect(result.arbitrationResult.renderedActions.length, equals(1));
      expect(
        result.arbitrationResult.renderedActions.first.characterId,
        equals('char_a'),
      );
      expect(
        result.renderedOutput.visibleActionDescriptions.first,
        startsWith('char_a:'),
      );
    });
  });
}

const _apiConfig = RuntimeApiConfig(
  apiId: 'api_test',
  name: 'test',
  providerType: ProviderType.openaiCompatible,
  baseUrl: 'https://example.com/v1',
  requestPath: '/chat/completions',
  apiKey: 'test-key',
  defaultModel: 'test-model',
);

const _scene = SceneModel(
  sceneId: 'scene_seed',
  sceneTurnId: 'turn_seed',
  timeContext: TimeContext(
    timeOfDay: 'night',
    weather: 'clear',
    visibilityCondition: 'good',
  ),
  spatialLayout: SpatialLayout(
    sceneType: SceneType.room,
    dimensionsEstimate: 'small room',
  ),
  lighting: LightingState(overallLevel: LightingLevel.normal),
  acoustics: AcousticsState(
    ambientNoiseLevel: 0.2,
    reflectiveQuality: ReflectiveQuality.muffled,
  ),
  olfactoryField: OlfactoryField(
    overallDensity: 0.1,
    airflow: Airflow(strength: AirflowStrength.still, direction: ''),
  ),
);

CharacterRuntimeState _buildCharacterState(String characterId) {
  return CharacterRuntimeState(
    characterId: characterId,
    profile: const CharacterProfile(
      traits: ['calm'],
      values: ['survival'],
      cognitiveStyle: 'analytical',
      socialStyle: 'guarded',
    ),
    mindModelCard: const MindModelCard(
      selfImage: 'test',
      worldview: ['world'],
      socialLogic: ['logic'],
      fearTriggers: ['loss'],
      defensePatterns: ['observe'],
      desirePatterns: ['live'],
    ),
    beliefState: const BeliefState(),
    emotionState: const EmotionState(),
    baselineBodyProfile: const BaselineBodyProfile(
      species: 'human',
      sensoryBaseline: SensoryBaseline(
        vision: 1.0,
        hearing: 1.0,
        smell: 1.0,
        touch: 1.0,
        proprioception: 1.0,
      ),
      motorBaseline: MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
      cognitionBaseline: CognitionBaseline(
        stressTolerance: 1.0,
        sensoryOverloadTolerance: 1.0,
      ),
      manaSensoryBaseline: ManaSensoryBaseline(),
    ),
    temporaryBodyState: const TemporaryBodyState(
      sensoryBlocks: SensoryBlocks(),
    ),
    currentGoals: const CurrentGoals(shortTerm: ['survive']),
  );
}

CharacterCognitivePassOutput _buildCognitiveOutput({
  required String characterId,
  required String sceneTurnId,
  required String intent,
  required double timePressure,
  required double candidatePriority,
}) {
  return CharacterCognitivePassOutput(
    characterId: characterId,
    sceneTurnId: sceneTurnId,
    perceptionDelta: const PerceptionDelta(
      noticedFacts: [
        NoticedFact(
          factId: 'f1',
          content: '保持警惕',
          sourceType: 'internal',
          confidence: 0.9,
        ),
      ],
    ),
    beliefUpdate: const BeliefUpdate(
      stableBeliefsReinforced: [
        BeliefReinforced(
          beliefId: 'self_preserve',
          evidence: '危险临近',
          newConfidence: 0.8,
        ),
      ],
      emotionalShift: EmotionalShift(
        emotion: 'focus',
        oldIntensity: 0.3,
        newIntensity: 0.6,
        trigger: 'threat',
      ),
    ),
    intentPlan: IntentPlan(
      activeGoals: const CurrentGoals(shortTerm: ['survive']),
      decisionFrame: DecisionFrame(
        context: 'combat',
        constraints: 'limited',
        timePressure: timePressure,
      ),
      candidateIntents: [
        CandidateIntent(
          intentId: 'i1',
          description: intent,
          priority: candidatePriority,
          feasibility: 1.0,
        ),
      ],
      selectedIntent: SelectedIntent(intent: intent, reason: 'test'),
      expressionConstraints: const ExpressionConstraints(
        revealLevel: RevealLevel.direct,
        tone: 'steady',
      ),
    ),
  );
}
