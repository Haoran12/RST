import 'dart:convert';

import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';
import '../../models/agent/embodiment_state.dart';
import '../../models/agent/filtered_scene_view.dart';
import '../../models/agent/temporary_body_state.dart';
import '../api_service.dart';

/// Request for cognitive pass execution.
class CognitivePassRequest {
  const CognitivePassRequest({
    required this.input,
    required this.apiConfig,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens = 4096,
  });

  final CharacterCognitivePassInput input;
  final RuntimeApiConfig apiConfig;
  final String model;
  final double temperature;
  final int maxTokens;
}

/// Result of cognitive pass execution.
class CognitivePassResult {
  const CognitivePassResult({
    required this.output,
    required this.rawResponse,
    required this.promptTokens,
    required this.completionTokens,
  });

  final CharacterCognitivePassOutput output;
  final String rawResponse;
  final int? promptTokens;
  final int? completionTokens;
}

/// Executes a single cognitive pass for a character.
///
/// This service orchestrates the Perception -> Belief -> Intent pipeline
/// in a single model call, producing structured output that can be validated
/// and committed to character state.
class CharacterCognitivePass {
  const CharacterCognitivePass();

  /// Build the structured prompt for cognitive pass.
  String buildPrompt(CharacterCognitivePassInput input) {
    final buffer = StringBuffer();

    buffer.writeln('# 角色认知传递');
    buffer.writeln();
    buffer.writeln('## 角色信息');
    buffer.writeln('- 角色ID: ${input.characterId}');
    buffer.writeln('- 场景回合: ${input.sceneTurnId}');
    buffer.writeln();

    // Embodiment state
    buffer.writeln('## 具身状态');
    _writeEmbodimentSection(buffer, input.embodimentState);
    buffer.writeln();

    // Filtered scene view
    buffer.writeln('## 感知输入');
    _writeFilteredSceneView(buffer, input.filteredSceneView);
    buffer.writeln();

    // Body state
    buffer.writeln('## 身体状态');
    _writeBodyState(buffer, input.bodyState);
    buffer.writeln();

    // Accessible memories
    if (input.accessibleMemories.isNotEmpty) {
      buffer.writeln('## 可访问记忆');
      for (final memory in input.accessibleMemories) {
        buffer.writeln('- [${memory.memoryId}] ${memory.content}');
        if (memory.emotionalWeight > 0) {
          buffer.writeln('  情感权重: ${memory.emotionalWeight.toStringAsFixed(2)}');
        }
      }
      buffer.writeln();
    }

    // Prior belief state
    buffer.writeln('## 当前信念状态');
    _writeBeliefState(buffer, input.priorBeliefState);
    buffer.writeln();

    // Relation models
    if (input.relationModels.isNotEmpty) {
      buffer.writeln('## 人际关系模型');
      _writeRelationModels(buffer, input.relationModels);
      buffer.writeln();
    }

    // Emotion state
    buffer.writeln('## 情感状态');
    _writeEmotionState(buffer, input.emotionState);
    buffer.writeln();

    // Current goals
    buffer.writeln('## 当前目标');
    _writeCurrentGoals(buffer, input.currentGoals);
    buffer.writeln();

    // Recent events
    if (input.recentEventDelta.isNotEmpty) {
      buffer.writeln('## 近期事件');
      for (final event in input.recentEventDelta) {
        buffer.writeln('- ${event.description}');
      }
      buffer.writeln();
    }

    // Output format specification
    buffer.writeln('## 输出要求');
    buffer.writeln('请以JSON格式输出以下结构：');
    buffer.writeln('```json');
    buffer.writeln(_outputSchema);
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('注意：');
    buffer.writeln('1. 只能引用感知输入中可见的实体和信号');
    buffer.writeln('2. 只能引用可访问记忆中的内容');
    buffer.writeln('3. 意图必须与当前目标一致');
    buffer.writeln('4. 表达约束需考虑当前情感状态');

    return buffer.toString();
  }

  void _writeEmbodimentSection(StringBuffer buffer, EmbodimentState state) {
    final sensory = state.sensoryCapabilities;
    buffer.writeln('### 感知能力');
    buffer.writeln('- 视觉: 可用性 ${sensory.vision.availability.toStringAsFixed(2)}, 敏锐度 ${sensory.vision.acuity.toStringAsFixed(2)}');
    buffer.writeln('- 听觉: 可用性 ${sensory.hearing.availability.toStringAsFixed(2)}, 敏锐度 ${sensory.hearing.acuity.toStringAsFixed(2)}');
    buffer.writeln('- 嗅觉: 可用性 ${sensory.smell.availability.toStringAsFixed(2)}, 敏锐度 ${sensory.smell.acuity.toStringAsFixed(2)}');
    buffer.writeln('- 触觉: 可用性 ${sensory.touch.availability.toStringAsFixed(2)}, 敏锐度 ${sensory.touch.acuity.toStringAsFixed(2)}');
    buffer.writeln('- 本体感觉: 可用性 ${sensory.proprioception.availability.toStringAsFixed(2)}');
    buffer.writeln('- 灵觉: 可用性 ${sensory.mana.availability.toStringAsFixed(2)}, 敏锐度 ${sensory.mana.acuity.toStringAsFixed(2)}');

    final constraints = state.bodyConstraints;
    buffer.writeln('### 身体约束');
    buffer.writeln('- 行动力: ${constraints.mobility.toStringAsFixed(2)}');
    buffer.writeln('- 平衡: ${constraints.balance.toStringAsFixed(2)}');
    buffer.writeln('- 痛苦负荷: ${constraints.painLoad.toStringAsFixed(2)}');
    buffer.writeln('- 疲劳: ${constraints.fatigue.toStringAsFixed(2)}');
    buffer.writeln('- 认知清晰度: ${constraints.cognitiveClarity.toStringAsFixed(2)}');

    final reasoning = state.reasoningModifiers;
    buffer.writeln('### 推理修正');
    buffer.writeln('- 认知清晰度: ${reasoning.cognitiveClarity.toStringAsFixed(2)}');
    buffer.writeln('- 痛苦偏差: ${reasoning.painBias.toStringAsFixed(2)}');
    buffer.writeln('- 威胁偏差: ${reasoning.threatBias.toStringAsFixed(2)}');
    buffer.writeln('- 过载偏差: ${reasoning.overloadBias.toStringAsFixed(2)}');
  }

  void _writeFilteredSceneView(StringBuffer buffer, FilteredSceneView view) {
    if (view.visibleEntities.isNotEmpty) {
      buffer.writeln('### 可见实体');
      for (final entity in view.visibleEntities) {
        buffer.writeln('- [${entity.entityId}] 可见度 ${entity.visibilityScore.toStringAsFixed(2)}, 清晰度 ${entity.clarity.toStringAsFixed(2)}');
        if (entity.notes.isNotEmpty) {
          buffer.writeln('  备注: ${entity.notes}');
        }
      }
    }

    if (view.audibleSignals.isNotEmpty) {
      buffer.writeln('### 可听信号');
      for (final signal in view.audibleSignals) {
        buffer.writeln('- [${signal.signalId}] ${signal.content}');
        buffer.writeln('  可听度: ${signal.audibilityScore.toStringAsFixed(2)}, 方向: ${signal.direction}');
      }
    }

    if (view.olfactorySignals.isNotEmpty) {
      buffer.writeln('### 嗅觉信号');
      for (final signal in view.olfactorySignals) {
        buffer.writeln('- [${signal.signalId}] ${signal.content}');
        buffer.writeln('  强度: ${signal.intensity.toStringAsFixed(2)}, 新鲜度: ${signal.freshness}');
      }
    }

    if (view.tactileSignals.isNotEmpty) {
      buffer.writeln('### 触觉信号');
      for (final signal in view.tactileSignals) {
        buffer.writeln('- [${signal.signalId}] ${signal.content}');
        buffer.writeln('  即时性: ${signal.immediacy.toStringAsFixed(2)}');
      }
    }

    if (view.manaSignals.isNotEmpty) {
      buffer.writeln('### 灵觉信号');
      for (final signal in view.manaSignals) {
        buffer.writeln('- [${signal.signalId}] ${signal.content}');
        buffer.writeln('  类型: ${signal.sourceType.name}, 感知强度: ${signal.perceivedIntensity.toStringAsFixed(2)}');
        buffer.writeln('  属性: ${signal.attribute.name}, 清晰度: ${signal.clarity.toStringAsFixed(2)}');
        if (signal.insight != null) {
          final insight = signal.insight!;
          if (insight.estimatedRealm != null) {
            buffer.writeln('  估计境界: ${insight.estimatedRealm}');
          }
          if (insight.threatLevel > 0) {
            buffer.writeln('  威胁等级: ${insight.threatLevel.toStringAsFixed(2)}');
          }
        }
      }
    }

    final env = view.manaEnvironment;
    if (env.perceivedDensity > 0.1) {
      buffer.writeln('### 灵气环境');
      buffer.writeln('- 感知密度: ${env.perceivedDensity.toStringAsFixed(2)}');
      buffer.writeln('- 主导属性: ${env.dominantAttribute.name}');
      if (env.hasAnomaly) {
        buffer.writeln('- 异常: ${env.anomalyDescription}');
      }
    }

    buffer.writeln('### 空间上下文');
    buffer.writeln('- 可达区域: ${view.spatialContext.reachableAreas.join(', ')}');
    buffer.writeln('- 附近障碍: ${view.spatialContext.nearbyObstacles.join(', ')}');
  }

  void _writeBodyState(StringBuffer buffer, TemporaryBodyState state) {
    buffer.writeln('- 疲劳: ${state.fatigue.toStringAsFixed(2)}');
    buffer.writeln('- 痛苦: ${state.painLevel.toStringAsFixed(2)}');
    buffer.writeln('- 眩晕: ${state.dizziness.toStringAsFixed(2)}');

    if (state.injuries.isNotEmpty) {
      buffer.writeln('- 伤势:');
      for (final injury in state.injuries) {
        buffer.writeln('  - ${injury.part}: 严重度 ${injury.severity.toStringAsFixed(2)}');
      }
    }

    if (state.sensoryBlocks.visionBlocked ||
        state.sensoryBlocks.hearingBlocked ||
        state.sensoryBlocks.smellBlocked ||
        state.sensoryBlocks.manaBlocked) {
      buffer.writeln('- 感知阻断:');
      if (state.sensoryBlocks.visionBlocked) buffer.writeln('  - 视觉被阻断');
      if (state.sensoryBlocks.hearingBlocked) buffer.writeln('  - 听觉被阻断');
      if (state.sensoryBlocks.smellBlocked) buffer.writeln('  - 嗅觉被阻断');
      if (state.sensoryBlocks.manaBlocked) buffer.writeln('  - 灵觉被阻断');
    }

    if (state.manaDepletion != null && state.manaDepletion! > 0) {
      buffer.writeln('- 灵力耗竭: ${state.manaDepletion!.toStringAsFixed(2)}');
    }
  }

  void _writeBeliefState(StringBuffer buffer, BeliefState state) {
    if (state.beliefConfidences.isNotEmpty) {
      buffer.writeln('### 信念置信度');
      state.beliefConfidences.forEach((belief, confidence) {
        buffer.writeln('- $belief: ${(confidence * 100).toStringAsFixed(0)}%');
      });
    }

    if (state.activeHypotheses.isNotEmpty) {
      buffer.writeln('### 活跃假设');
      for (final hypothesis in state.activeHypotheses) {
        buffer.writeln('- $hypothesis');
      }
    }

    if (state.currentHypothesis != null) {
      buffer.writeln('### 当前假设');
      buffer.writeln(state.currentHypothesis);
    }
  }

  void _writeRelationModels(StringBuffer buffer, Map<String, dynamic> models) {
    models.forEach((targetId, model) {
      buffer.writeln('- 目标: $targetId');
      if (model is Map<String, dynamic>) {
        if (model.containsKey('trust')) {
          buffer.writeln('  信任: ${model['trust']}');
        }
        if (model.containsKey('perceivedIntent')) {
          buffer.writeln('  感知意图: ${model['perceivedIntent']}');
        }
      }
    });
  }

  void _writeEmotionState(StringBuffer buffer, EmotionState state) {
    if (state.emotions.isEmpty) {
      buffer.writeln('- 无明显情感');
      return;
    }

    final sortedEmotions = state.emotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEmotions.take(5)) {
      buffer.writeln('- ${entry.key}: ${entry.value.toStringAsFixed(2)}');
    }
  }

  void _writeCurrentGoals(StringBuffer buffer, CurrentGoals goals) {
    if (goals.shortTerm.isNotEmpty) {
      buffer.writeln('### 短期目标');
      for (final goal in goals.shortTerm) {
        buffer.writeln('- $goal');
      }
    }

    if (goals.mediumTerm.isNotEmpty) {
      buffer.writeln('### 中期目标');
      for (final goal in goals.mediumTerm) {
        buffer.writeln('- $goal');
      }
    }

    if (goals.hidden.isNotEmpty) {
      buffer.writeln('### 隐藏目标');
      for (final goal in goals.hidden) {
        buffer.writeln('- $goal');
      }
    }
  }

  /// Parse model response into structured output.
  CharacterCognitivePassOutput parseOutput(String rawResponse, String characterId, String sceneTurnId) {
    final jsonStr = _extractJson(rawResponse);
    if (jsonStr == null) {
      return _createFallbackOutput(characterId, sceneTurnId, rawResponse);
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CharacterCognitivePassOutput.fromJson({
        'characterId': characterId,
        'sceneTurnId': sceneTurnId,
        ...json,
      });
    } catch (e) {
      return _createFallbackOutput(characterId, sceneTurnId, rawResponse);
    }
  }

  String? _extractJson(String response) {
    // Try to find JSON in code blocks
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(response);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)?.trim();
    }

    // Try to find raw JSON object
    final jsonObjectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonObjectMatch != null) {
      return jsonObjectMatch.group(0);
    }

    return null;
  }

  CharacterCognitivePassOutput _createFallbackOutput(
    String characterId,
    String sceneTurnId,
    String rawResponse,
  ) {
    return CharacterCognitivePassOutput(
      characterId: characterId,
      sceneTurnId: sceneTurnId,
      perceptionDelta: PerceptionDelta(
        noticedFacts: [
          NoticedFact(
            factId: 'fallback_fact',
            content: rawResponse.substring(0, rawResponse.length.clamp(0, 200)),
            sourceType: 'fallback',
          ),
        ],
      ),
      beliefUpdate: BeliefUpdate(
        emotionalShift: const EmotionalShift(
          emotion: 'neutral',
          oldIntensity: 0.5,
          newIntensity: 0.5,
          trigger: 'fallback',
        ),
      ),
      intentPlan: IntentPlan(
        activeGoals: const CurrentGoals(),
        decisionFrame: const DecisionFrame(
          context: '解析失败，使用降级输出',
          constraints: '无约束',
          timePressure: 0.0,
        ),
        selectedIntent: SelectedIntent(
          intent: '等待进一步信息',
          reason: '模型输出解析失败',
        ),
        expressionConstraints: const ExpressionConstraints(
          revealLevel: RevealLevel.guarded,
        ),
      ),
    );
  }

  static const String _outputSchema = '''
{
  "perceptionDelta": {
    "noticedFacts": [
      {"factId": "...", "content": "...", "sourceType": "visual|auditory|olfactory|tactile|mana", "confidence": 0.0-1.0}
    ],
    "unnoticedButObservable": [
      {"observableId": "...", "content": "...", "reason": "..."}
    ],
    "ambiguousSignals": [
      {"signalId": "...", "content": "...", "possibleInterpretations": ["..."]}
    ],
    "subjectiveImpressions": [
      {"impressionId": "...", "targetEntityId": "...", "impression": "...", "basis": "..."}
    ],
    "affectiveColoring": [
      {"targetId": "...", "emotion": "...", "intensity": 0.0-1.0}
    ],
    "memoryActivations": [
      {"memoryId": "...", "activationReason": "...", "relevanceScore": 0.0-1.0}
    ],
    "immediateConcerns": ["..."]
  },
  "beliefUpdate": {
    "stableBeliefsReinforced": [
      {"beliefId": "...", "evidence": "...", "newConfidence": 0.0-1.0}
    ],
    "stableBeliefsWeakened": [
      {"beliefId": "...", "counterEvidence": "...", "newConfidence": 0.0-1.0}
    ],
    "newHypotheses": [
      {"hypothesisId": "...", "content": "...", "prior": 0.0-1.0, "basis": "..."}
    ],
    "revisedModelsOfOthers": [
      {"targetCharacterId": "...", "aspect": "...", "oldValue": "...", "newValue": "...", "reason": "..."}
    ],
    "contradictionsAndTension": [
      {"description": "...", "involvedBeliefs": ["..."], "severity": 0.0-1.0}
    ],
    "emotionalShift": {
      "emotion": "...",
      "oldIntensity": 0.0-1.0,
      "newIntensity": 0.0-1.0,
      "trigger": "..."
    },
    "decisionRelevantBeliefs": ["..."]
  },
  "intentPlan": {
    "activeGoals": {
      "shortTerm": ["..."],
      "mediumTerm": ["..."],
      "hidden": ["..."]
    },
    "decisionFrame": {
      "context": "...",
      "constraints": "...",
      "timePressure": 0.0-1.0
    },
    "candidateIntents": [
      {"intentId": "...", "description": "...", "priority": 0.0-1.0, "feasibility": 0.0-1.0}
    ],
    "selectedIntent": {
      "intent": "...",
      "reason": "...",
      "dependsOnBeliefs": ["..."],
      "emotionalDriver": "...",
      "suppressedAlternatives": [
        {"intent": "...", "reason": "..."}
      ]
    },
    "expressionConstraints": {
      "revealLevel": "direct|guarded|masked|deceptive|silent",
      "tone": "...",
      "behavioralNotes": ["..."]
    }
  }
}
''';

  /// Execute cognitive pass with a model call function.
  /// This is the main entry point for running a cognitive pass.
  Future<CharacterCognitivePassOutput> execute({
    required CharacterCognitivePassInput input,
    required Future<String> Function(String prompt, String model, double temperature) modelCall,
    required String model,
    double temperature = 0.7,
  }) async {
    final prompt = buildPrompt(input);

    try {
      final rawResponse = await modelCall(prompt, model, temperature);
      return parseOutput(rawResponse, input.characterId, input.sceneTurnId);
    } catch (e) {
      return _createFallbackOutput(input.characterId, input.sceneTurnId, 'Model call failed: $e');
    }
  }

  /// Validate output against input constraints.
  List<ValidationIssue> validateOutput(
    CharacterCognitivePassOutput output,
    CharacterCognitivePassInput input,
  ) {
    final issues = <ValidationIssue>[];

    // Check for omniscience leakage in noticed facts
    for (final fact in output.perceptionDelta.noticedFacts) {
      if (!_isSourceTypeAccessible(fact.sourceType, input.filteredSceneView)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          type: ValidationIssueType.omniscienceLeakage,
          message: 'Noticed fact from inaccessible source: ${fact.sourceType}',
          context: 'factId: ${fact.factId}',
        ));
      }
    }

    // Check for memory leakage
    final accessibleMemoryIds = input.accessibleMemories.map((m) => m.memoryId).toSet();
    for (final activation in output.perceptionDelta.memoryActivations) {
      if (!accessibleMemoryIds.contains(activation.memoryId)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          type: ValidationIssueType.memoryLeakage,
          message: 'Referenced inaccessible memory: ${activation.memoryId}',
          context: 'activationReason: ${activation.activationReason}',
        ));
      }
    }

    // Check for embodiment consistency
    final vision = input.embodimentState.sensoryCapabilities.vision;
    if (vision.availability < 0.1) {
      final hasVisualFacts = output.perceptionDelta.noticedFacts
          .any((f) => f.sourceType == 'visual');
      if (hasVisualFacts) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          type: ValidationIssueType.embodimentIgnored,
          message: 'Visual facts noticed despite vision unavailable',
          context: 'vision availability: ${vision.availability}',
        ));
      }
    }

    // Check for mana sense consistency
    final mana = input.embodimentState.sensoryCapabilities.mana;
    if (mana.availability < 0.1) {
      final hasManaFacts = output.perceptionDelta.noticedFacts
          .any((f) => f.sourceType == 'mana');
      if (hasManaFacts) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          type: ValidationIssueType.embodimentIgnored,
          message: 'Mana facts noticed despite mana sense unavailable',
          context: 'mana availability: ${mana.availability}',
        ));
      }
    }

    // Check for belief-belief contradictions
    final contradictions = output.beliefUpdate.contradictionsAndTension;
    for (final contradiction in contradictions) {
      if (contradiction.severity > 0.7) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.warning,
          type: ValidationIssueType.beliefContradiction,
          message: contradiction.description,
          context: 'involved beliefs: ${contradiction.involvedBeliefs.join(", ")}',
        ));
      }
    }

    return issues;
  }

  bool _isSourceTypeAccessible(String sourceType, dynamic filteredSceneView) {
    // Simplified check - in real implementation would check filtered view
    return switch (sourceType) {
      'visual' => true, // Would check visibleEntities
      'auditory' => true, // Would check audibleSignals
      'olfactory' => true, // Would check olfactorySignals
      'tactile' => true, // Would check tactileSignals
      'mana' => true, // Would check manaSignals
      'internal' => true, // Internal thoughts always accessible
      _ => true,
    };
  }
}

/// Severity of a validation issue.
enum ValidationSeverity {
  info,
  warning,
  error,
}

/// Type of validation issue.
enum ValidationIssueType {
  omniscienceLeakage,
  memoryLeakage,
  embodimentIgnored,
  beliefContradiction,
  invalidOutput,
}

/// A single validation issue found during output validation.
class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.type,
    required this.message,
    this.context,
  });

  final ValidationSeverity severity;
  final ValidationIssueType type;
  final String message;
  final String? context;

  @override
  String toString() => 'ValidationIssue($severity, $type: $message)';
}
