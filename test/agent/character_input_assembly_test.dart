import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/baseline_body_profile.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/models/agent/embodiment_state.dart';
import 'package:rst/core/models/agent/filtered_scene_view.dart';
import 'package:rst/core/models/agent/mana_field.dart';
import 'package:rst/core/models/agent/memory_entry.dart';
import 'package:rst/core/models/agent/scene_model.dart';
import 'package:rst/core/models/agent/temporary_body_state.dart';
import 'package:rst/core/services/agent/character_input_assembly.dart';
import 'package:rst/core/services/agent/embodiment_resolver.dart';
import 'package:rst/core/services/agent/memory_access_protocol.dart';
import 'package:rst/core/services/agent/scene_filtering_protocol.dart';
import 'package:rst/core/services/agent/scene_state_extractor.dart';

void main() {
  group('CharacterInputAssembly', () {
    late CharacterInputAssembly assembly;

    setUp(() {
      assembly = const CharacterInputAssembly(
        SceneStateExtractor(),
        EmbodimentResolver(),
        SceneFilteringProtocol(),
        MemoryAccessProtocol(),
      );
    });

    group('full assembly', () {
      test('assembles complete cognitive pass input', () async {
        final request = _createAssemblyRequest();

        final result = await assembly.assemble(request);

        expect(result.input.characterId, equals('test_character'));
        expect(result.input.sceneTurnId, equals('turn_001'));
        expect(result.input.filteredSceneView, isNotNull);
        expect(result.input.embodimentState, isNotNull);
        expect(result.input.bodyState, isNotNull);
        expect(result.input.priorBeliefState, isNotNull);
        expect(result.input.emotionState, isNotNull);
        expect(result.input.currentGoals, isNotNull);
      });

      test('embodiment state is correctly resolved', () async {
        final request = _createAssemblyRequest(
          baselineProfile: _cultivatorBaseline,
        );

        final result = await assembly.assemble(request);

        expect(result.embodimentState.characterId, equals('test_character'));
        expect(result.embodimentState.sensoryCapabilities.mana.acuity, greaterThan(0.5));
      });

      test('filtered view is correctly generated', () async {
        final request = _createAssemblyRequest(
          scene: _sceneWithEntities,
        );

        final result = await assembly.assemble(request);

        expect(result.filteredView.characterId, equals('test_character'));
        expect(result.filteredView.visibleEntities, isNotEmpty);
      });

      test('memories are correctly filtered and ranked', () async {
        final memories = [
          MemoryEntry(
            memoryId: 'private_other',
            content: 'Other person secret',
            ownerCharacterId: 'other',
            knownBy: const ['other'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'shared_with_character',
            content: 'Shared memory about John',
            ownerCharacterId: 'other',
            knownBy: const ['other', 'test_character'],
            visibility: MemoryVisibility.shared,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'public_memory',
            content: 'Public fact',
            ownerCharacterId: 'other',
            knownBy: const ['other'],
            visibility: MemoryVisibility.public,
            createdAt: DateTime.now(),
          ),
        ];

        final request = _createAssemblyRequest(
          allMemories: memories,
          scene: _sceneWithJohnEntity,
        );

        final result = await assembly.assemble(request);

        // Should only have shared and public memories
        expect(result.memoryResult.totalAccessible, equals(2));
        expect(result.memoryResult.filteredByPermission, equals(1));
        expect(result.input.accessibleMemories.length, lessThanOrEqualTo(10));
      });

      test('handles empty memories gracefully', () async {
        final request = _createAssemblyRequest(allMemories: []);

        final result = await assembly.assemble(request);

        expect(result.input.accessibleMemories, isEmpty);
        expect(result.memoryResult.totalAccessible, equals(0));
      });
    });

    group('scene extraction', () {
      test('extracts scene from narrative input', () async {
        final request = _createAssemblyRequest(
          narrativeInput: 'They entered a dark cave at night.',
        );

        final result = await assembly.assemble(request);

        expect(result.extractionResult, isNotNull);
        expect(result.extractionResult!.extractionSource, equals('narrative'));
      });

      test('extracts scene from world state JSON', () async {
        final request = _createAssemblyRequest(
          worldStateJson: {
            'timeContext': {'timeOfDay': 'night', 'weather': 'storm', 'visibilityCondition': 'poor'},
          },
        );

        final result = await assembly.assemble(request);

        expect(result.extractionResult, isNotNull);
        expect(result.extractionResult!.extractionSource, equals('world_state'));
        expect(result.input.filteredSceneView.sceneTurnId, equals('turn_001'));
      });

      test('uses provided scene when no extraction needed', () async {
        final scene = SceneModel(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          timeContext: const TimeContext(timeOfDay: 'dusk', weather: 'rain', visibilityCondition: 'poor'),
          spatialLayout: const SpatialLayout(sceneType: SceneType.forest, dimensionsEstimate: 'large'),
          lighting: const LightingState(overallLevel: LightingLevel.dim),
          acoustics: const AcousticsState(ambientNoiseLevel: 0.5, reflectiveQuality: ReflectiveQuality.open),
          olfactoryField: OlfactoryField(
            overallDensity: 0.4,
            airflow: const Airflow(strength: AirflowStrength.flowing, direction: 'south'),
          ),
        );

        final request = _createAssemblyRequest(scene: scene);

        final result = await assembly.assemble(request);

        expect(result.extractionResult, isNull);
      });
    });

    group('quick assembly', () {
      test('quickly assembles from pre-computed components', () {
        final filteredView = FilteredSceneView(
          characterId: 'test_character',
          sceneTurnId: 'turn_001',
          spatialContext: const SpatialContext(),
        );

        final embodiment = EmbodimentState(
          characterId: 'test_character',
          sceneTurnId: 'turn_001',
          sensoryCapabilities: const SensoryCapabilities(
            vision: SensoryCapability(availability: 1.0, acuity: 1.0),
            hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
            smell: SensoryCapability(availability: 1.0, acuity: 1.0),
            touch: SensoryCapability(availability: 1.0, acuity: 1.0),
            proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
            mana: ManaSensoryCapability.cultivator,
          ),
          bodyConstraints: const BodyConstraints(mobility: 1.0, balance: 1.0, painLoad: 0.0, fatigue: 0.0, cognitiveClarity: 1.0),
          salienceModifiers: const SalienceModifiers(),
          reasoningModifiers: const ReasoningModifiers(cognitiveClarity: 1.0, painBias: 0.0, threatBias: 0.0, overloadBias: 0.0),
          actionFeasibility: const ActionFeasibility(physicalExecutionCapacity: 1.0, socialPatience: 1.0, fineControl: 1.0, sustainedAttention: 1.0),
        );

        final input = assembly.quickAssemble(
          characterId: 'test_character',
          sceneTurnId: 'turn_001',
          baselineProfile: _humanBaseline,
          temporaryBodyState: const TemporaryBodyState(sensoryBlocks: SensoryBlocks()),
          beliefState: const BeliefState(beliefConfidences: {}, activeHypotheses: []),
          emotionState: const EmotionState(emotions: {}),
          currentGoals: const CurrentGoals(shortTerm: [], mediumTerm: [], hidden: []),
          scene: _normalScene,
          embodiment: embodiment,
          filteredView: filteredView,
          memories: [],
        );

        expect(input.characterId, equals('test_character'));
        expect(input.filteredSceneView, equals(filteredView));
        expect(input.embodimentState, equals(embodiment));
      });
    });
  });
}

// === Test fixtures ===

CharacterInputAssemblyRequest _createAssemblyRequest({
  BaselineBodyProfile? baselineProfile,
  TemporaryBodyState? temporaryBodyState,
  BeliefState? beliefState,
  EmotionState? emotionState,
  CurrentGoals? currentGoals,
  SceneModel? scene,
  List<MemoryEntry>? allMemories,
  String? narrativeInput,
  Map<String, dynamic>? worldStateJson,
}) {
  return CharacterInputAssemblyRequest(
    characterId: 'test_character',
    sceneTurnId: 'turn_001',
    baselineProfile: baselineProfile ?? _humanBaseline,
    temporaryBodyState: temporaryBodyState ?? const TemporaryBodyState(sensoryBlocks: SensoryBlocks()),
    beliefState: beliefState ?? const BeliefState(beliefConfidences: {}, activeHypotheses: []),
    emotionState: emotionState ?? const EmotionState(emotions: {}),
    currentGoals: currentGoals ?? const CurrentGoals(shortTerm: [], mediumTerm: [], hidden: []),
    scene: scene ?? _normalScene,
    allMemories: allMemories ?? const [],
    narrativeInput: narrativeInput,
    worldStateJson: worldStateJson,
  );
}

final _humanBaseline = BaselineBodyProfile(
  species: 'human',
  sensoryBaseline: const SensoryBaseline(
    vision: 1.0,
    hearing: 1.0,
    smell: 1.0,
    touch: 1.0,
    proprioception: 1.0,
  ),
  motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
  cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
  manaSensoryBaseline: const ManaSensoryBaseline(baseAcuity: 0.3),
);

final _cultivatorBaseline = BaselineBodyProfile(
  species: 'cultivator',
  sensoryBaseline: const SensoryBaseline(
    vision: 1.0,
    hearing: 1.0,
    smell: 1.0,
    touch: 1.0,
    proprioception: 1.0,
  ),
  motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
  cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
  manaSensoryBaseline: const ManaSensoryBaseline(
    baseAcuity: 1.0,
    realmModifier: 1.5,
    traits: [ManaSenseTrait.soulPerception],
  ),
);

final _normalScene = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'noon', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
);

final _sceneWithEntities = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'noon', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  entities: const [
    SceneEntity(entityId: 'entity_001', type: 'person', location: '5,5', state: 'standing'),
    SceneEntity(entityId: 'entity_002', type: 'person', location: '8,8', state: 'sitting'),
  ],
);

final _sceneWithJohnEntity = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'noon', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  entities: const [
    SceneEntity(entityId: 'John', type: 'person', location: '5,5', state: 'standing'),
  ],
);
