import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';
import '../../models/agent/embodiment_state.dart';
import '../../models/agent/filtered_scene_view.dart';
import '../../models/agent/memory_entry.dart';
import '../../models/agent/temporary_body_state.dart';
import '../../models/common.dart';
import '../api_service.dart';
import 'belief_updater.dart';
import 'emotion_updater.dart';
import 'intent_agent.dart';

/// Configuration for cognitive pass execution.
class CognitivePassConfig {
  const CognitivePassConfig({
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.enableValidation = true,
    this.retryCount = 2,
    this.timeoutMs = 30000,
  });

  final double temperature;
  final int maxTokens;
  final bool enableValidation;
  final int retryCount;
  final int timeoutMs;
}

/// Request for full cognitive pass execution.
class CognitivePassExecutionRequest {
  const CognitivePassExecutionRequest({
    required this.characterState,
    required this.filteredSceneView,
    required this.embodimentState,
    required this.recentEvents,
    required this.apiConfig,
    required this.model,
    this.config = const CognitivePassConfig(),
  });

  final CharacterRuntimeState characterState;
  final FilteredSceneView filteredSceneView;
  final EmbodimentState embodimentState;
  final List<dynamic> recentEvents;
  final RuntimeApiConfig apiConfig;
  final String model;
  final CognitivePassConfig config;
}

/// Result of full cognitive pass execution.
class CognitivePassExecutionResult {
  const CognitivePassExecutionResult({
    required this.characterId,
    required this.sceneTurnId,
    required this.cognitiveOutput,
    required this.beliefUpdateResult,
    required this.emotionUpdateResult,
    required this.intentExecutionResult,
    required this.updatedCharacterState,
    required this.executionMetrics,
  });

  final String characterId;
  final String sceneTurnId;
  final CharacterCognitivePassOutput cognitiveOutput;
  final BeliefUpdateResult beliefUpdateResult;
  final EmotionUpdateResult emotionUpdateResult;
  final IntentExecutionResult intentExecutionResult;
  final CharacterRuntimeState updatedCharacterState;
  final CognitivePassMetrics executionMetrics;
}

/// Metrics for cognitive pass execution.
class CognitivePassMetrics {
  const CognitivePassMetrics({
    required this.promptTokens,
    required this.completionTokens,
    required this.executionTimeMs,
    required this.retryAttempts,
    this.validationPassed = true,
    this.validationErrors = const [],
  });

  final int? promptTokens;
  final int? completionTokens;
  final int executionTimeMs;
  final int retryAttempts;
  final bool validationPassed;
  final List<String> validationErrors;
}

/// Orchestrates the full cognitive pass execution pipeline.
///
/// This service coordinates:
/// 1. Input assembly and prompt building
/// 2. Model API call
/// 3. Output parsing and validation
/// 4. Belief state update
/// 5. Emotion state update
/// 6. Intent execution planning
/// 7. Character state commit
class CognitivePassExecutor {
  const CognitivePassExecutor({
    this.beliefUpdater = const BeliefUpdater(),
    this.emotionUpdater = const EmotionUpdater(),
    this.intentAgent = const IntentAgent(),
  });

  final BeliefUpdater beliefUpdater;
  final EmotionUpdater emotionUpdater;
  final IntentAgent intentAgent;

  /// Execute full cognitive pass for a character.
  Future<CognitivePassExecutionResult> execute(
    CognitivePassExecutionRequest request, {
    required Future<CharacterCognitivePassOutput> Function(CharacterCognitivePassInput) modelCall,
  }) async {
    final stopwatch = Stopwatch()..start();
    int retryAttempts = 0;
    List<String> validationErrors = [];

    // 1. Build cognitive pass input
    final input = CharacterCognitivePassInput(
      characterId: request.characterState.characterId,
      sceneTurnId: request.filteredSceneView.sceneTurnId,
      filteredSceneView: request.filteredSceneView,
      embodimentState: request.embodimentState,
      bodyState: request.characterState.temporaryBodyState,
      accessibleMemories: [], // Would be populated from memory access
      priorBeliefState: request.characterState.beliefState,
      relationModels: _convertRelationModels(request.characterState.relationshipModels),
      emotionState: request.characterState.emotionState,
      currentGoals: request.characterState.currentGoals,
      recentEventDelta: [],
    );

    // 2. Execute model call with retry
    CharacterCognitivePassOutput? output;
    int? promptTokens;
    int? completionTokens;

    for (var attempt = 0; attempt <= request.config.retryCount; attempt++) {
      try {
        output = await modelCall(input);
        retryAttempts = attempt;
        break;
      } catch (e) {
        if (attempt == request.config.retryCount) {
          output = _createFallbackOutput(input, e.toString());
        }
        retryAttempts = attempt + 1;
      }
    }

    // 3. Validate output
    if (request.config.enableValidation && output != null) {
      final validationResult = _validateOutput(output, input);
      validationErrors = validationResult.errors;
    }

    // 4. Update belief state
    final beliefUpdateResult = beliefUpdater.update(BeliefUpdateRequest(
      characterId: request.characterState.characterId,
      currentBeliefState: request.characterState.beliefState,
      beliefUpdate: output!.beliefUpdate,
      currentRelationModels: _convertRelationModels(request.characterState.relationshipModels),
    ));

    // 5. Update emotion state
    final emotionUpdateResult = emotionUpdater.update(EmotionUpdateRequest(
      characterId: request.characterState.characterId,
      currentEmotionState: request.characterState.emotionState,
      emotionalShift: output.beliefUpdate.emotionalShift,
      affectiveColoring: output.perceptionDelta.affectiveColoring,
      currentGoals: output.intentPlan.activeGoals,
    ));

    // 6. Execute intent planning
    final intentExecutionResult = intentAgent.execute(IntentExecutionRequest(
      characterId: request.characterState.characterId,
      intentPlan: output.intentPlan,
      embodimentState: request.embodimentState,
      emotionState: emotionUpdateResult.newEmotionState,
      beliefState: beliefUpdateResult.newBeliefState,
    ));

    // 7. Build updated character state
    final updatedState = request.characterState.copyWith(
      beliefState: beliefUpdateResult.newBeliefState,
      emotionState: emotionUpdateResult.newEmotionState,
      currentGoals: output.intentPlan.activeGoals,
      currentEmbodimentState: request.embodimentState,
    );

    stopwatch.stop();

    final metrics = CognitivePassMetrics(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      executionTimeMs: stopwatch.elapsedMilliseconds,
      retryAttempts: retryAttempts,
      validationPassed: validationErrors.isEmpty,
      validationErrors: validationErrors,
    );

    return CognitivePassExecutionResult(
      characterId: request.characterState.characterId,
      sceneTurnId: request.filteredSceneView.sceneTurnId,
      cognitiveOutput: output,
      beliefUpdateResult: beliefUpdateResult,
      emotionUpdateResult: emotionUpdateResult,
      intentExecutionResult: intentExecutionResult,
      updatedCharacterState: updatedState,
      executionMetrics: metrics,
    );
  }

  /// Execute cognitive pass for multiple characters in parallel.
  Future<List<CognitivePassExecutionResult>> executeBatch(
    List<CognitivePassExecutionRequest> requests, {
    required Future<CharacterCognitivePassOutput> Function(CharacterCognitivePassInput) modelCall,
  }) async {
    final results = await Future.wait(
      requests.map((request) => execute(request, modelCall: modelCall)),
    );
    return results;
  }

  /// Validate cognitive pass output against input constraints.
  ValidationResult _validateOutput(
    CharacterCognitivePassOutput output,
    CharacterCognitivePassInput input,
  ) {
    final errors = <String>[];

    // Check for omniscience leakage
    for (final fact in output.perceptionDelta.noticedFacts) {
      // Verify fact source is accessible
      if (!_isSourceAccessible(fact.sourceType, input.filteredSceneView)) {
        errors.add('Omniscience leakage: noticed fact from inaccessible source: ${fact.sourceType}');
      }
    }

    // Check for memory leakage
    for (final activation in output.perceptionDelta.memoryActivations) {
      final isAccessible = input.accessibleMemories
          .any((m) => m.memoryId == activation.memoryId);
      if (!isAccessible) {
        errors.add('Memory leakage: referenced inaccessible memory: ${activation.memoryId}');
      }
    }

    // Check for embodiment consistency
    final vision = input.embodimentState.sensoryCapabilities.vision;
    if (vision.availability < 0.1) {
      final hasVisualNoticed = output.perceptionDelta.noticedFacts
          .any((f) => f.sourceType == 'visual');
      if (hasVisualNoticed) {
        errors.add('Embodiment ignored: visual facts noticed despite vision unavailable');
      }
    }

    return ValidationResult(errors: errors);
  }

  /// Check if a source type is accessible in the filtered view.
  bool _isSourceAccessible(String sourceType, FilteredSceneView view) {
    return switch (sourceType) {
      'visual' => view.visibleEntities.isNotEmpty,
      'auditory' => view.audibleSignals.isNotEmpty,
      'olfactory' => view.olfactorySignals.isNotEmpty,
      'tactile' => view.tactileSignals.isNotEmpty,
      'mana' => view.manaSignals.isNotEmpty,
      'internal' => true, // Internal thoughts are always accessible
      _ => true, // Default to accessible for unknown types
    };
  }

  /// Convert relation models to map format.
  Map<String, dynamic> _convertRelationModels(Map<String, RelationModel> models) {
    return models.map((key, value) => MapEntry(key, {
      'trust': value.trust,
      'perceivedIntent': value.perceivedIntent,
      'pastInteractions': value.pastInteractions,
      ...value.additionalAttributes,
    }));
  }

  /// Create fallback output when model call fails.
  CharacterCognitivePassOutput _createFallbackOutput(
    CharacterCognitivePassInput input,
    String error,
  ) {
    return CharacterCognitivePassOutput(
      characterId: input.characterId,
      sceneTurnId: input.sceneTurnId,
      perceptionDelta: PerceptionDelta(
        noticedFacts: [
          NoticedFact(
            factId: 'fallback_fact',
            content: '认知传递失败，等待进一步信息',
            sourceType: 'internal',
          ),
        ],
        immediateConcerns: ['等待进一步信息'],
      ),
      beliefUpdate: BeliefUpdate(
        emotionalShift: EmotionalShift(
          emotion: 'confusion',
          oldIntensity: input.emotionState.emotions['confusion'] ?? 0.0,
          newIntensity: 0.3,
          trigger: '认知传递失败',
        ),
      ),
      intentPlan: IntentPlan(
        activeGoals: input.currentGoals,
        decisionFrame: DecisionFrame(
          context: '认知传递失败: $error',
          constraints: '降级模式',
          timePressure: 0.0,
        ),
        selectedIntent: SelectedIntent(
          intent: '等待进一步信息',
          reason: '认知传递失败，使用降级输出',
        ),
        expressionConstraints: const ExpressionConstraints(
          revealLevel: RevealLevel.guarded,
        ),
      ),
    );
  }
}

/// Result of output validation.
class ValidationResult {
  const ValidationResult({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}
