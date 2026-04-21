import '../../models/agent/baseline_body_profile.dart';
import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';
import '../../models/agent/embodiment_state.dart';
import '../../models/agent/filtered_scene_view.dart';
import '../../models/agent/memory_entry.dart';
import '../../models/agent/scene_model.dart';
import '../../models/agent/temporary_body_state.dart';
import 'embodiment_resolver.dart';
import 'memory_access_protocol.dart';
import 'scene_filtering_protocol.dart';
import 'scene_state_extractor.dart';

/// Request for character input assembly.
class CharacterInputAssemblyRequest {
  const CharacterInputAssemblyRequest({
    required this.characterId,
    required this.sceneTurnId,
    required this.baselineProfile,
    required this.temporaryBodyState,
    required this.beliefState,
    required this.emotionState,
    required this.currentGoals,
    required this.scene,
    this.allMemories = const [],
    this.characterLocation,
    this.narrativeInput,
    this.worldStateJson,
    this.recentEvents = const [],
    this.relationModels = const {},
    this.maxMemories = 10,
  });

  final String characterId;
  final String sceneTurnId;
  final BaselineBodyProfile baselineProfile;
  final TemporaryBodyState temporaryBodyState;
  final BeliefState beliefState;
  final EmotionState emotionState;
  final CurrentGoals currentGoals;
  final SceneModel scene;
  final List<MemoryEntry> allMemories;
  final String? characterLocation;
  final String? narrativeInput;
  final Map<String, dynamic>? worldStateJson;
  final List<SceneEvent> recentEvents;
  final Map<String, dynamic> relationModels;
  final int maxMemories;
}

/// Result of character input assembly.
class CharacterInputAssemblyResult {
  const CharacterInputAssemblyResult({
    required this.input,
    this.extractionResult,
    required this.embodimentState,
    required this.filteredView,
    required this.memoryResult,
  });

  final CharacterCognitivePassInput input;
  final SceneExtractionResult? extractionResult;
  final EmbodimentState embodimentState;
  final FilteredSceneView filteredView;
  final MemoryAccessResult memoryResult;
}

/// Orchestrates the full cognitive pass input assembly pipeline.
///
/// Pipeline flow:
/// 1. SceneStateExtractor.extract() if scene needs parsing
/// 2. EmbodimentResolver.resolve() with baseline + temporary + scene
/// 3. SceneFilteringProtocol.filter() with scene + embodiment
/// 4. MemoryAccessProtocol.retrieve() with filtered view + goals
/// 5. CharacterCognitivePassInput construction
class CharacterInputAssembly {
  const CharacterInputAssembly(
    this._sceneExtractor,
    this._embodimentResolver,
    this._sceneFilter,
    this._memoryAccess,
  );

  final SceneStateExtractor _sceneExtractor;
  final EmbodimentResolver _embodimentResolver;
  final SceneFilteringProtocol _sceneFilter;
  final MemoryAccessProtocol _memoryAccess;

  /// Assemble complete cognitive pass input for a character.
  Future<CharacterInputAssemblyResult> assemble(
    CharacterInputAssemblyRequest request,
  ) async {
    // Step 1: Extract/parse scene if needed
    SceneModel scene = request.scene;
    SceneExtractionResult? extractionResult;

    if (request.narrativeInput != null || request.worldStateJson != null) {
      extractionResult = await _sceneExtractor.extract(SceneExtractionRequest(
        sceneId: request.scene.sceneId,
        sceneTurnId: request.sceneTurnId,
        narrativeInput: request.narrativeInput,
        worldStateJson: request.worldStateJson,
        previousScene: request.scene,
      ));
      scene = extractionResult.scene;
    }

    // Step 2: Resolve embodiment state
    final embodimentState = _embodimentResolver.resolve(EmbodimentResolveRequest(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      baselineProfile: request.baselineProfile,
      temporaryState: request.temporaryBodyState,
      scene: scene,
      characterLocation: request.characterLocation,
    ));

    // Step 3: Filter scene view
    final filteredView = _sceneFilter.filter(SceneFilterRequest(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      scene: scene,
      embodiment: embodimentState,
      characterLocation: request.characterLocation,
    ));

    // Step 4: Retrieve memories
    final memoryResult = _memoryAccess.retrieve(MemoryAccessRequest(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      allMemories: request.allMemories,
      currentContext: MemoryAccessContext(
        filteredSceneView: filteredView,
        activeEntities: filteredView.visibleEntities.map((e) => e.entityId).toList(),
        currentGoals: [
          ...request.currentGoals.shortTerm,
          ...request.currentGoals.mediumTerm,
        ],
        currentEmotions: request.emotionState.emotions,
      ),
      maxMemories: request.maxMemories,
    ));

    // Step 5: Construct cognitive pass input
    final input = CharacterCognitivePassInput(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      filteredSceneView: filteredView,
      embodimentState: embodimentState,
      bodyState: request.temporaryBodyState,
      accessibleMemories: memoryResult.memories,
      priorBeliefState: request.beliefState,
      relationModels: request.relationModels,
      emotionState: request.emotionState,
      currentGoals: request.currentGoals,
      recentEventDelta: request.recentEvents,
    );

    return CharacterInputAssemblyResult(
      input: input,
      extractionResult: extractionResult,
      embodimentState: embodimentState,
      filteredView: filteredView,
      memoryResult: memoryResult,
    );
  }

  /// Quick assembly for cases where scene is already resolved.
  CharacterCognitivePassInput quickAssemble({
    required String characterId,
    required String sceneTurnId,
    required BaselineBodyProfile baselineProfile,
    required TemporaryBodyState temporaryBodyState,
    required BeliefState beliefState,
    required EmotionState emotionState,
    required CurrentGoals currentGoals,
    required SceneModel scene,
    required EmbodimentState embodiment,
    required FilteredSceneView filteredView,
    required List<MemoryEntry> memories,
    List<SceneEvent> recentEvents = const [],
    Map<String, dynamic> relationModels = const {},
  }) {
    return CharacterCognitivePassInput(
      characterId: characterId,
      sceneTurnId: sceneTurnId,
      filteredSceneView: filteredView,
      embodimentState: embodiment,
      bodyState: temporaryBodyState,
      accessibleMemories: memories,
      priorBeliefState: beliefState,
      relationModels: relationModels,
      emotionState: emotionState,
      currentGoals: currentGoals,
      recentEventDelta: recentEvents,
    );
  }
}
