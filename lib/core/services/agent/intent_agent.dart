import '../../models/agent/cognitive_pass_io.dart';
import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/embodiment_state.dart';

/// Request for intent execution.
class IntentExecutionRequest {
  const IntentExecutionRequest({
    required this.characterId,
    required this.intentPlan,
    required this.embodimentState,
    required this.emotionState,
    required this.beliefState,
  });

  final String characterId;
  final IntentPlan intentPlan;
  final EmbodimentState embodimentState;
  final EmotionState emotionState;
  final BeliefState beliefState;
}

/// Result of intent execution.
class IntentExecutionResult {
  const IntentExecutionResult({
    required this.characterId,
    required this.selectedIntent,
    required this.expressionConstraints,
    required this.actionPlan,
    required this.feasibilityScore,
    required this.modifications,
  });

  final String characterId;
  final SelectedIntent selectedIntent;
  final ExpressionConstraints expressionConstraints;
  final ActionPlan actionPlan;
  final double feasibilityScore;
  final List<IntentModification> modifications;
}

/// Plan for executing an intent.
class ActionPlan {
  const ActionPlan({
    required this.intentId,
    required this.description,
    required this.steps,
    required this.estimatedOutcome,
    this.requiredResources = const [],
    this.risks = const [],
  });

  final String intentId;
  final String description;
  final List<ActionStep> steps;
  final String estimatedOutcome;
  final List<String> requiredResources;
  final List<String> risks;
}

/// A single step in an action plan.
class ActionStep {
  const ActionStep({
    required this.stepId,
    required this.description,
    required this.type,
    required this.feasibility,
    this.dependencies = const [],
  });

  final String stepId;
  final String description;
  final ActionStepType type;
  final double feasibility;
  final List<String> dependencies;
}

/// Type of action step.
enum ActionStepType {
  verbal,
  physical,
  mental,
  social,
  magical,
  wait,
  observe,
}

/// Modification applied to intent during execution planning.
class IntentModification {
  const IntentModification({
    required this.type,
    required this.reason,
    required this.originalValue,
    required this.modifiedValue,
  });

  final IntentModificationType type;
  final String reason;
  final dynamic originalValue;
  final dynamic modifiedValue;
}

/// Type of intent modification.
enum IntentModificationType {
  toneAdjusted,
  revealLevelDowngraded,
  actionSimplified,
  actionDelayed,
  actionAborted,
}

/// Coordinates intent execution and action planning.
///
/// This service handles:
/// - Translating intents into executable action plans
/// - Adjusting expression based on constraints
/// - Checking feasibility against embodiment state
/// - Managing intent conflicts and priorities
class IntentAgent {
  const IntentAgent({
    this.minFeasibility = 0.3,
    this.defaultTimePressure = 0.5,
  });

  final double minFeasibility;
  final double defaultTimePressure;

  /// Execute intent planning and produce action plan.
  IntentExecutionResult execute(IntentExecutionRequest request) {
    final modifications = <IntentModification>[];
    var selectedIntent = request.intentPlan.selectedIntent;
    var expressionConstraints = request.intentPlan.expressionConstraints;

    // Check feasibility against embodiment state
    final feasibilityScore = _computeFeasibility(
      selectedIntent,
      request.embodimentState,
    );

    // Adjust expression based on emotional state
    expressionConstraints = _adjustExpressionForEmotion(
      expressionConstraints,
      request.emotionState,
      modifications,
    );

    // Adjust expression based on cognitive clarity
    expressionConstraints = _adjustExpressionForCognition(
      expressionConstraints,
      request.embodimentState.reasoningModifiers,
      modifications,
    );

    // Generate action plan
    final actionPlan = _generateActionPlan(
      selectedIntent,
      request.intentPlan.decisionFrame,
      request.embodimentState,
      feasibilityScore,
    );

    // If feasibility is too low, simplify or abort
    if (feasibilityScore < minFeasibility) {
      selectedIntent = _createFallbackIntent(selectedIntent, feasibilityScore);
      modifications.add(IntentModification(
        type: IntentModificationType.actionSimplified,
        reason: 'Feasibility below threshold: ${feasibilityScore.toStringAsFixed(2)}',
        originalValue: request.intentPlan.selectedIntent.intent,
        modifiedValue: selectedIntent.intent,
      ));
    }

    return IntentExecutionResult(
      characterId: request.characterId,
      selectedIntent: selectedIntent,
      expressionConstraints: expressionConstraints,
      actionPlan: actionPlan,
      feasibilityScore: feasibilityScore,
      modifications: modifications,
    );
  }

  /// Resolve conflicts between multiple character intents.
  ConflictResolution resolveConflicts(List<IntentExecutionResult> results) {
    if (results.isEmpty) {
      return const ConflictResolution(
        resolved: true,
        adjustments: [],
        finalOrder: [],
      );
    }

    if (results.length == 1) {
      return ConflictResolution(
        resolved: true,
        adjustments: [],
        finalOrder: [results.first.characterId],
      );
    }

    // Sort by priority (based on time pressure and feasibility)
    final sorted = List<IntentExecutionResult>.from(results)
      ..sort((a, b) {
        final aScore = a.feasibilityScore;
        final bScore = b.feasibilityScore;
        return bScore.compareTo(aScore);
      });

    final adjustments = <ConflictAdjustment>[];

    // Check for direct conflicts (same target, opposite intents)
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final conflict = _detectConflict(
          sorted[i],
          sorted[j],
        );
        if (conflict != null) {
          adjustments.add(conflict);
        }
      }
    }

    return ConflictResolution(
      resolved: adjustments.isEmpty,
      adjustments: adjustments,
      finalOrder: sorted.map((r) => r.characterId).toList(),
    );
  }

  double _computeFeasibility(
    SelectedIntent intent,
    EmbodimentState embodiment,
  ) {
    var score = 1.0;

    // Physical constraints
    final mobility = embodiment.bodyConstraints.mobility;
    if (intent.intent.contains('移动') || intent.intent.contains('攻击')) {
      score *= mobility;
    }

    // Cognitive constraints
    final clarity = embodiment.reasoningModifiers.cognitiveClarity;
    if (intent.intent.contains('计划') || intent.intent.contains('分析')) {
      score *= clarity;
    }

    // Pain bias
    final painBias = embodiment.reasoningModifiers.painBias;
    if (painBias > 0.5) {
      score *= (1.0 - painBias * 0.3);
    }

    // Threat bias
    final threatBias = embodiment.reasoningModifiers.threatBias;
    if (threatBias > 0.7 && !intent.intent.contains('防御')) {
      score *= (1.0 - threatBias * 0.2);
    }

    return score.clamp(0.0, 1.0);
  }

  ExpressionConstraints _adjustExpressionForEmotion(
    ExpressionConstraints constraints,
    EmotionState emotionState,
    List<IntentModification> modifications,
  ) {
    var revealLevel = constraints.revealLevel;
    var tone = constraints.tone;

    // Check for high-intensity emotions that might affect expression
    final highIntensityEmotions = emotionState.emotions.entries
        .where((e) => e.value > 0.7)
        .toList();

    if (highIntensityEmotions.isNotEmpty) {
      final dominantEmotion = highIntensityEmotions.first.key;

      // Adjust reveal level based on emotion
      if (dominantEmotion == 'anger' || dominantEmotion == 'fear') {
        if (revealLevel == RevealLevel.masked) {
          revealLevel = RevealLevel.guarded;
          modifications.add(IntentModification(
            type: IntentModificationType.revealLevelDowngraded,
            reason: 'High intensity $dominantEmotion broke mask',
            originalValue: RevealLevel.masked,
            modifiedValue: RevealLevel.guarded,
          ));
        }
      }

      // Adjust tone based on emotion
      tone = _inferToneFromEmotion(dominantEmotion, tone);
    }

    return constraints.copyWith(
      revealLevel: revealLevel,
      tone: tone,
    );
  }

  ExpressionConstraints _adjustExpressionForCognition(
    ExpressionConstraints constraints,
    ReasoningModifiers reasoning,
    List<IntentModification> modifications,
  ) {
    var revealLevel = constraints.revealLevel;

    // Low cognitive clarity may cause unintended reveals
    if (reasoning.cognitiveClarity < 0.3 && revealLevel == RevealLevel.masked) {
      revealLevel = RevealLevel.guarded;
      modifications.add(IntentModification(
        type: IntentModificationType.revealLevelDowngraded,
        reason: 'Low cognitive clarity broke mask',
        originalValue: RevealLevel.masked,
        modifiedValue: RevealLevel.guarded,
      ));
    }

    // High overload bias may cause defensive expression
    if (reasoning.overloadBias > 0.7 && revealLevel == RevealLevel.direct) {
      revealLevel = RevealLevel.guarded;
      modifications.add(IntentModification(
        type: IntentModificationType.revealLevelDowngraded,
        reason: 'High overload bias caused guarded expression',
        originalValue: RevealLevel.direct,
        modifiedValue: RevealLevel.guarded,
      ));
    }

    return constraints.copyWith(revealLevel: revealLevel);
  }

  String _inferToneFromEmotion(String emotion, String currentTone) {
    return switch (emotion) {
      'anger' => 'sharp',
      'fear' => 'nervous',
      'joy' => 'bright',
      'sadness' => 'subdued',
      'surprise' => 'startled',
      'disgust' => 'cold',
      'trust' => 'warm',
      'anticipation' => 'eager',
      _ => currentTone,
    };
  }

  ActionPlan _generateActionPlan(
    SelectedIntent intent,
    DecisionFrame decisionFrame,
    EmbodimentState embodiment,
    double feasibility,
  ) {
    final steps = <ActionStep>[];

    // Determine action type from intent
    final actionType = _inferActionType(intent.intent);

    // Generate steps based on intent and feasibility
    if (feasibility > 0.7) {
      // Full execution
      steps.add(ActionStep(
        stepId: '${intent.intent.hashCode}_1',
        description: intent.intent,
        type: actionType,
        feasibility: feasibility,
      ));
    } else if (feasibility > 0.3) {
      // Simplified execution
      steps.add(ActionStep(
        stepId: '${intent.intent.hashCode}_1',
        description: '尝试: ${intent.intent}',
        type: actionType,
        feasibility: feasibility,
      ));
    } else {
      // Wait or observe
      steps.add(ActionStep(
        stepId: '${intent.intent.hashCode}_1',
        description: '等待时机',
        type: ActionStepType.wait,
        feasibility: 0.8,
      ));
    }

    // Add observation step if time allows
    if (decisionFrame.timePressure < 0.5) {
      steps.add(ActionStep(
        stepId: '${intent.intent.hashCode}_observe',
        description: '观察反应',
        type: ActionStepType.observe,
        feasibility: 1.0,
        dependencies: [steps.first.stepId],
      ));
    }

    return ActionPlan(
      intentId: intent.intent.hashCode.toString(),
      description: intent.intent,
      steps: steps,
      estimatedOutcome: _estimateOutcome(intent, feasibility),
      risks: _identifyRisks(intent, embodiment),
    );
  }

  ActionStepType _inferActionType(String intent) {
    final lowerIntent = intent.toLowerCase();

    if (lowerIntent.contains('说') || lowerIntent.contains('问') || lowerIntent.contains('回答')) {
      return ActionStepType.verbal;
    }
    if (lowerIntent.contains('移动') || lowerIntent.contains('攻击') || lowerIntent.contains('拿')) {
      return ActionStepType.physical;
    }
    if (lowerIntent.contains('思考') || lowerIntent.contains('计划') || lowerIntent.contains('分析')) {
      return ActionStepType.mental;
    }
    if (lowerIntent.contains('说服') || lowerIntent.contains('谈判') || lowerIntent.contains('社交')) {
      return ActionStepType.social;
    }
    if (lowerIntent.contains('施法') || lowerIntent.contains('灵力') || lowerIntent.contains('修炼')) {
      return ActionStepType.magical;
    }
    if (lowerIntent.contains('等待') || lowerIntent.contains('观察')) {
      return ActionStepType.wait;
    }

    return ActionStepType.verbal;
  }

  String _estimateOutcome(SelectedIntent intent, double feasibility) {
    if (feasibility > 0.8) {
      return '高概率成功: ${intent.intent}';
    } else if (feasibility > 0.5) {
      return '中等概率成功，可能需要调整';
    } else if (feasibility > 0.3) {
      return '低概率成功，建议简化或延后';
    } else {
      return '极低概率成功，建议放弃或改变策略';
    }
  }

  List<String> _identifyRisks(SelectedIntent intent, EmbodimentState embodiment) {
    final risks = <String>[];

    if (embodiment.bodyConstraints.painLoad > 0.5) {
      risks.add('痛苦可能影响执行质量');
    }
    if (embodiment.bodyConstraints.fatigue > 0.7) {
      risks.add('疲劳可能导致失误');
    }
    if (embodiment.reasoningModifiers.threatBias > 0.6) {
      risks.add('威胁感知可能过度影响判断');
    }

    return risks;
  }

  SelectedIntent _createFallbackIntent(SelectedIntent original, double feasibility) {
    return SelectedIntent(
      intent: '等待更好的时机',
      reason: '当前可行性过低 (${feasibility.toStringAsFixed(2)})，原意图: ${original.intent}',
      dependsOnBeliefs: original.dependsOnBeliefs,
      emotionalDriver: original.emotionalDriver,
      suppressedAlternatives: [
        SuppressedAlternative(
          intent: original.intent,
          reason: '可行性不足',
        ),
        ...original.suppressedAlternatives,
      ],
    );
  }

  ConflictAdjustment? _detectConflict(
    IntentExecutionResult a,
    IntentExecutionResult b,
  ) {
    // Simplified conflict detection
    final intentA = a.selectedIntent.intent.toLowerCase();
    final intentB = b.selectedIntent.intent.toLowerCase();

    // Check for opposite intents
    final conflictPairs = [
      ['攻击', '保护'],
      ['逃跑', '追击'],
      ['说服', '拒绝'],
    ];

    for (final pair in conflictPairs) {
      if ((intentA.contains(pair[0]) && intentB.contains(pair[1])) ||
          (intentB.contains(pair[0]) && intentA.contains(pair[1]))) {
        return ConflictAdjustment(
          characterIdA: a.characterId,
          characterIdB: b.characterId,
          conflictType: ConflictType.opposingIntent,
          description: '冲突: ${a.selectedIntent.intent} vs ${b.selectedIntent.intent}',
          resolution: '按优先级执行',
        );
      }
    }

    return null;
  }
}

/// Result of conflict resolution.
class ConflictResolution {
  const ConflictResolution({
    required this.resolved,
    required this.adjustments,
    required this.finalOrder,
  });

  final bool resolved;
  final List<ConflictAdjustment> adjustments;
  final List<String> finalOrder;
}

/// Adjustment for a detected conflict.
class ConflictAdjustment {
  const ConflictAdjustment({
    required this.characterIdA,
    required this.characterIdB,
    required this.conflictType,
    required this.description,
    required this.resolution,
  });

  final String characterIdA;
  final String characterIdB;
  final ConflictType conflictType;
  final String description;
  final String resolution;
}

/// Type of intent conflict.
enum ConflictType {
  opposingIntent,
  resourceCompetition,
  targetCompetition,
  timingConflict,
}
