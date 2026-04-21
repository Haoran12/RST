import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';
import '../../models/agent/dirty_flags.dart';
import '../../models/agent/memory_entry.dart';
import '../../models/agent/scene_model.dart';
import '../api_service.dart';
import 'action_arbitration.dart';
import 'character_input_assembly.dart';
import 'cognitive_pass_executor.dart';
import 'scene_state_extractor.dart';
import 'surface_realizer.dart';

/// Request for processing one agent runtime turn.
class AgentTurnRequest {
  const AgentTurnRequest({
    required this.sceneId,
    required this.sceneTurnId,
    required this.characterStates,
    required this.apiConfig,
    required this.model,
    this.previousScene,
    this.narrativeInput,
    this.worldStateJson,
    this.activeCharacterIds,
    this.dirtyFlagsByCharacter = const {},
    this.memoriesByCharacter = const {},
    this.characterLocations = const {},
    this.recentEvents = const [],
    this.processOnlyDirty = true,
    this.cognitiveConfig = const CognitivePassConfig(),
    this.visibleSceneChanges = const [],
    this.speakerOrder = const [],
    this.toneProfile = const {},
    this.styleConstraints = const {},
  });

  final String sceneId;
  final String sceneTurnId;
  final Map<String, CharacterRuntimeState> characterStates;
  final RuntimeApiConfig apiConfig;
  final String model;
  final SceneModel? previousScene;
  final String? narrativeInput;
  final Map<String, dynamic>? worldStateJson;
  final Set<String>? activeCharacterIds;
  final Map<String, DirtyFlags> dirtyFlagsByCharacter;
  final Map<String, List<MemoryEntry>> memoriesByCharacter;
  final Map<String, String> characterLocations;
  final List<SceneEvent> recentEvents;
  final bool processOnlyDirty;
  final CognitivePassConfig cognitiveConfig;
  final List<String> visibleSceneChanges;
  final List<String> speakerOrder;
  final Map<String, dynamic> toneProfile;
  final Map<String, dynamic> styleConstraints;
}

/// Result of processing one runtime turn.
class AgentTurnResult {
  const AgentTurnResult({
    required this.sceneModel,
    required this.sceneExtraction,
    required this.executionResults,
    required this.cognitiveOutputs,
    required this.updatedCharacterStates,
    required this.arbitrationResult,
    required this.renderedOutput,
    required this.processedCharacters,
    required this.skippedCharacters,
  });

  final SceneModel sceneModel;
  final SceneExtractionResult sceneExtraction;
  final Map<String, CognitivePassExecutionResult> executionResults;
  final Map<String, CharacterCognitivePassOutput> cognitiveOutputs;
  final Map<String, CharacterRuntimeState> updatedCharacterStates;
  final ActionArbitrationResult arbitrationResult;
  final SurfaceRealizerOutput renderedOutput;
  final Set<String> processedCharacters;
  final Set<String> skippedCharacters;
}

/// Orchestrates the agent runtime main loop for one turn.
///
/// Pipeline:
/// 1. Extract scene state.
/// 2. Select active and dirty characters.
/// 3. Assemble per-character cognitive input.
/// 4. Execute cognitive pass and state updates.
/// 5. Arbitrate multi-character actions.
/// 6. Render visible turn output.
class AgentRuntime {
  const AgentRuntime({
    required SceneStateExtractor sceneExtractor,
    required CharacterInputAssembly inputAssembly,
    required CognitivePassExecutor cognitivePassExecutor,
    required ActionArbitration actionArbitration,
    required SurfaceRealizer surfaceRealizer,
  }) : _sceneExtractor = sceneExtractor,
       _inputAssembly = inputAssembly,
       _cognitivePassExecutor = cognitivePassExecutor,
       _actionArbitration = actionArbitration,
       _surfaceRealizer = surfaceRealizer;

  final SceneStateExtractor _sceneExtractor;
  final CharacterInputAssembly _inputAssembly;
  final CognitivePassExecutor _cognitivePassExecutor;
  final ActionArbitration _actionArbitration;
  final SurfaceRealizer _surfaceRealizer;

  Future<AgentTurnResult> processTurn(
    AgentTurnRequest request, {
    required Future<CharacterCognitivePassOutput> Function(
      CharacterCognitivePassInput input,
    )
    modelCall,
  }) async {
    final extraction = await _sceneExtractor.extract(
      SceneExtractionRequest(
        sceneId: request.sceneId,
        sceneTurnId: request.sceneTurnId,
        narrativeInput: request.narrativeInput,
        worldStateJson: request.worldStateJson,
        previousScene: request.previousScene,
      ),
    );
    final scene = extraction.scene;

    final activeIds = _resolveActiveCharacterIds(request);
    final executionResults = <String, CognitivePassExecutionResult>{};
    final cognitiveOutputs = <String, CharacterCognitivePassOutput>{};
    final updatedStates = <String, CharacterRuntimeState>{
      ...request.characterStates,
    };
    final arbitrationCandidates = <ActionArbitrationCandidate>[];
    final processedCharacters = <String>{};
    final skippedCharacters = <String>{};

    for (final characterId in activeIds) {
      final characterState = request.characterStates[characterId];
      if (characterState == null) {
        skippedCharacters.add(characterId);
        continue;
      }

      final dirtyFlags = request.dirtyFlagsByCharacter[characterId];
      final shouldProcess = _shouldProcessCharacter(
        dirtyFlags: dirtyFlags,
        processOnlyDirty: request.processOnlyDirty,
      );
      if (!shouldProcess) {
        skippedCharacters.add(characterId);
        continue;
      }

      final assembly = await _inputAssembly.assemble(
        CharacterInputAssemblyRequest(
          characterId: characterId,
          sceneTurnId: request.sceneTurnId,
          baselineProfile: characterState.baselineBodyProfile,
          temporaryBodyState: characterState.temporaryBodyState,
          beliefState: characterState.beliefState,
          emotionState: characterState.emotionState,
          currentGoals: characterState.currentGoals,
          scene: scene,
          allMemories:
              request.memoriesByCharacter[characterId] ?? const <MemoryEntry>[],
          characterLocation: request.characterLocations[characterId],
          recentEvents: request.recentEvents,
          relationModels: _relationModelsToJson(
            characterState.relationshipModels,
          ),
        ),
      );

      final execution = await _cognitivePassExecutor.execute(
        CognitivePassExecutionRequest(
          characterState: characterState,
          filteredSceneView: assembly.filteredView,
          embodimentState: assembly.embodimentState,
          recentEvents: request.recentEvents,
          apiConfig: request.apiConfig,
          model: request.model,
          config: request.cognitiveConfig,
        ),
        modelCall: modelCall,
      );

      executionResults[characterId] = execution;
      cognitiveOutputs[characterId] = execution.cognitiveOutput;
      updatedStates[characterId] = execution.updatedCharacterState;
      processedCharacters.add(characterId);

      arbitrationCandidates.add(
        ActionArbitrationCandidate(
          characterId: characterId,
          cognitiveOutput: execution.cognitiveOutput,
          intentExecution: execution.intentExecutionResult,
          reactionPriority: _reactionPriorityFromDirtyFlags(dirtyFlags),
          directlyAddressed: dirtyFlags?.directlyAddressed ?? false,
          underThreat: dirtyFlags?.underThreat ?? false,
        ),
      );
    }

    final arbitrationResult = _actionArbitration.arbitrate(
      ActionArbitrationRequest(
        sceneTurnId: request.sceneTurnId,
        candidates: arbitrationCandidates,
      ),
    );

    final renderedOutput = _surfaceRealizer.render(
      SurfaceRealizerInput(
        sceneTurnId: request.sceneTurnId,
        arbitrationResult: arbitrationResult,
        visibleSceneChanges: request.visibleSceneChanges,
        speakerOrder: request.speakerOrder,
        toneProfile: request.toneProfile,
        styleConstraints: request.styleConstraints,
      ),
    );

    return AgentTurnResult(
      sceneModel: scene,
      sceneExtraction: extraction,
      executionResults: executionResults,
      cognitiveOutputs: cognitiveOutputs,
      updatedCharacterStates: updatedStates,
      arbitrationResult: arbitrationResult,
      renderedOutput: renderedOutput,
      processedCharacters: processedCharacters,
      skippedCharacters: skippedCharacters,
    );
  }

  Set<String> _resolveActiveCharacterIds(AgentTurnRequest request) {
    if (request.activeCharacterIds == null) {
      return request.characterStates.keys.toSet();
    }
    return request.activeCharacterIds!
        .where(request.characterStates.containsKey)
        .toSet();
  }

  bool _shouldProcessCharacter({
    required DirtyFlags? dirtyFlags,
    required bool processOnlyDirty,
  }) {
    if (!processOnlyDirty) {
      return true;
    }
    if (dirtyFlags == null) {
      return true;
    }
    return dirtyFlags.isDirty;
  }

  int _reactionPriorityFromDirtyFlags(DirtyFlags? flags) {
    if (flags == null) {
      return 0;
    }

    var priority = 0;
    if (flags.directlyAddressed) {
      priority += 3;
    }
    if (flags.underThreat) {
      priority += 4;
    }
    if (flags.reactionWindowOpen) {
      priority += 2;
    }
    if (flags.receivedNewSalientSignal) {
      priority += 1;
    }
    return priority;
  }

  Map<String, dynamic> _relationModelsToJson(
    Map<String, RelationModel> relationModels,
  ) {
    return relationModels.map((key, value) => MapEntry(key, value.toJson()));
  }
}
