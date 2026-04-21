import '../../models/agent/cognitive_pass_io.dart';
import 'intent_agent.dart';

/// Input for turn-level arbitration.
class ActionArbitrationRequest {
  const ActionArbitrationRequest({
    required this.sceneTurnId,
    required this.candidates,
  });

  final String sceneTurnId;
  final List<ActionArbitrationCandidate> candidates;
}

/// Candidate action from one character.
class ActionArbitrationCandidate {
  const ActionArbitrationCandidate({
    required this.characterId,
    required this.cognitiveOutput,
    required this.intentExecution,
    this.reactionPriority = 0,
    this.directlyAddressed = false,
    this.underThreat = false,
  });

  final String characterId;
  final CharacterCognitivePassOutput cognitiveOutput;
  final IntentExecutionResult intentExecution;
  final int reactionPriority;
  final bool directlyAddressed;
  final bool underThreat;
}

/// Execution order entry after arbitration.
class ExecutionOrderEntry {
  const ExecutionOrderEntry({
    required this.characterId,
    required this.reason,
    required this.priorityScore,
  });

  final String characterId;
  final String reason;
  final double priorityScore;
}

/// Render-ready action selected by arbitration.
class ArbitratedAction {
  const ArbitratedAction({
    required this.characterId,
    required this.outwardAction,
    required this.dialogue,
    required this.visibleBehavior,
    required this.hiddenBehavior,
    required this.priorityScore,
    required this.revealLevel,
  });

  final String characterId;
  final String outwardAction;
  final String dialogue;
  final List<String> visibleBehavior;
  final List<String> hiddenBehavior;
  final double priorityScore;
  final RevealLevel revealLevel;
}

/// Suppressed action due to arbitration conflict.
class SuppressedAction {
  const SuppressedAction({
    required this.characterId,
    required this.originalIntent,
    required this.reason,
  });

  final String characterId;
  final String originalIntent;
  final String reason;
}

/// Conflict type detected by arbitration.
enum ArbitrationConflictType { opposingIntent, timingContention }

/// Conflict record produced during arbitration.
class ArbitrationConflict {
  const ArbitrationConflict({
    required this.type,
    required this.characterIdA,
    required this.characterIdB,
    required this.description,
    required this.resolution,
    required this.winnerCharacterId,
    required this.loserCharacterId,
  });

  final ArbitrationConflictType type;
  final String characterIdA;
  final String characterIdB;
  final String description;
  final String resolution;
  final String winnerCharacterId;
  final String loserCharacterId;
}

/// Result of turn-level action arbitration.
class ActionArbitrationResult {
  const ActionArbitrationResult({
    required this.turnId,
    required this.executionOrder,
    required this.renderedActions,
    required this.suppressedActions,
    required this.conflicts,
  });

  final String turnId;
  final List<ExecutionOrderEntry> executionOrder;
  final List<ArbitratedAction> renderedActions;
  final List<SuppressedAction> suppressedActions;
  final List<ArbitrationConflict> conflicts;
}

/// Resolve multi-character intent ordering and conflicts.
class ActionArbitration {
  const ActionArbitration({this.conflictMargin = 0.08});

  final double conflictMargin;

  ActionArbitrationResult arbitrate(ActionArbitrationRequest request) {
    if (request.candidates.isEmpty) {
      return ActionArbitrationResult(
        turnId: request.sceneTurnId,
        executionOrder: const [],
        renderedActions: const [],
        suppressedActions: const [],
        conflicts: const [],
      );
    }

    final ranked =
        request.candidates
            .map(
              (candidate) => _ScoredCandidate(
                candidate: candidate,
                score: _computeScore(candidate),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final accepted = <_ScoredCandidate>[];
    final suppressed = <SuppressedAction>[];
    final conflicts = <ArbitrationConflict>[];

    for (final current in ranked) {
      final existing = _findConflict(accepted, current);
      if (existing == null) {
        accepted.add(current);
        continue;
      }

      if (current.score > existing.score + conflictMargin) {
        accepted.remove(existing);
        accepted.add(current);
        suppressed.add(
          SuppressedAction(
            characterId: existing.candidate.characterId,
            originalIntent:
                existing.candidate.intentExecution.selectedIntent.intent,
            reason: '冲突中优先级较低，被 ${current.candidate.characterId} 覆盖',
          ),
        );
        conflicts.add(
          _buildConflictRecord(
            a: current.candidate,
            b: existing.candidate,
            winner: current.candidate.characterId,
            loser: existing.candidate.characterId,
          ),
        );
        continue;
      }

      suppressed.add(
        SuppressedAction(
          characterId: current.candidate.characterId,
          originalIntent:
              current.candidate.intentExecution.selectedIntent.intent,
          reason: '冲突中优先级较低，保留 ${existing.candidate.characterId}',
        ),
      );
      conflicts.add(
        _buildConflictRecord(
          a: current.candidate,
          b: existing.candidate,
          winner: existing.candidate.characterId,
          loser: current.candidate.characterId,
        ),
      );
    }

    accepted.sort((a, b) => b.score.compareTo(a.score));

    final executionOrder = accepted
        .map(
          (item) => ExecutionOrderEntry(
            characterId: item.candidate.characterId,
            reason: _buildExecutionReason(item),
            priorityScore: item.score,
          ),
        )
        .toList();

    final renderedActions = accepted
        .map((item) => _buildArbitratedAction(item))
        .toList();

    return ActionArbitrationResult(
      turnId: request.sceneTurnId,
      executionOrder: executionOrder,
      renderedActions: renderedActions,
      suppressedActions: suppressed,
      conflicts: conflicts,
    );
  }

  double _computeScore(ActionArbitrationCandidate candidate) {
    final intentPriority = _resolveIntentPriority(
      candidate.cognitiveOutput.intentPlan,
    );
    final feasibility = _clamp01(candidate.intentExecution.feasibilityScore);
    final timePressure = _clamp01(
      candidate.cognitiveOutput.intentPlan.decisionFrame.timePressure,
    );
    final reactionWeight = _clamp01(candidate.reactionPriority / 10);

    var score =
        0.40 * feasibility +
        0.25 * intentPriority +
        0.20 * timePressure +
        0.10 * reactionWeight;

    if (candidate.directlyAddressed) {
      score += 0.05;
    }
    if (candidate.underThreat) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.5).toDouble();
  }

  _ScoredCandidate? _findConflict(
    List<_ScoredCandidate> accepted,
    _ScoredCandidate current,
  ) {
    for (final existing in accepted) {
      if (_hasConflict(existing.candidate, current.candidate)) {
        return existing;
      }
    }
    return null;
  }

  bool _hasConflict(
    ActionArbitrationCandidate a,
    ActionArbitrationCandidate b,
  ) {
    final intentA = a.intentExecution.selectedIntent.intent.toLowerCase();
    final intentB = b.intentExecution.selectedIntent.intent.toLowerCase();

    const opposingPairs = <List<String>>[
      ['攻击', '保护'],
      ['追击', '撤退'],
      ['击杀', '救援'],
      ['attack', 'protect'],
      ['chase', 'retreat'],
      ['kill', 'rescue'],
    ];

    for (final pair in opposingPairs) {
      final left = pair[0];
      final right = pair[1];
      if ((intentA.contains(left) && intentB.contains(right)) ||
          (intentA.contains(right) && intentB.contains(left))) {
        return true;
      }
    }

    final firstStepA = a.intentExecution.actionPlan.steps.isEmpty
        ? ActionStepType.wait
        : a.intentExecution.actionPlan.steps.first.type;
    final firstStepB = b.intentExecution.actionPlan.steps.isEmpty
        ? ActionStepType.wait
        : b.intentExecution.actionPlan.steps.first.type;
    final bothPhysical =
        (firstStepA == ActionStepType.physical ||
            firstStepA == ActionStepType.magical) &&
        (firstStepB == ActionStepType.physical ||
            firstStepB == ActionStepType.magical);

    return bothPhysical && a.underThreat && b.underThreat;
  }

  ArbitrationConflict _buildConflictRecord({
    required ActionArbitrationCandidate a,
    required ActionArbitrationCandidate b,
    required String winner,
    required String loser,
  }) {
    return ArbitrationConflict(
      type: ArbitrationConflictType.opposingIntent,
      characterIdA: a.characterId,
      characterIdB: b.characterId,
      description:
          '意图冲突: ${a.intentExecution.selectedIntent.intent} vs ${b.intentExecution.selectedIntent.intent}',
      resolution: '优先执行 $winner，压制 $loser',
      winnerCharacterId: winner,
      loserCharacterId: loser,
    );
  }

  double _resolveIntentPriority(IntentPlan plan) {
    if (plan.candidateIntents.isEmpty) {
      return 0.5;
    }

    final selected = plan.selectedIntent.intent.trim();
    var best = 0.0;
    var matched = false;

    for (final candidate in plan.candidateIntents) {
      final description = candidate.description.trim();
      final isMatch =
          description.isNotEmpty &&
          (description.contains(selected) || selected.contains(description));
      if (isMatch) {
        best = candidate.priority > best ? candidate.priority : best;
        matched = true;
      }
    }

    if (matched) {
      return _clamp01(best);
    }

    return _clamp01(plan.candidateIntents.first.priority);
  }

  String _buildExecutionReason(_ScoredCandidate candidate) {
    final pressure = candidate
        .candidate
        .cognitiveOutput
        .intentPlan
        .decisionFrame
        .timePressure;
    final feasibility = candidate.candidate.intentExecution.feasibilityScore;
    return 'score=${candidate.score.toStringAsFixed(2)}, '
        'timePressure=${pressure.toStringAsFixed(2)}, '
        'feasibility=${feasibility.toStringAsFixed(2)}';
  }

  ArbitratedAction _buildArbitratedAction(_ScoredCandidate scored) {
    final candidate = scored.candidate;
    final expression = candidate.intentExecution.expressionConstraints;
    final selectedIntent = candidate.intentExecution.selectedIntent;

    return ArbitratedAction(
      characterId: candidate.characterId,
      outwardAction: selectedIntent.intent,
      dialogue: _buildDialogue(candidate),
      visibleBehavior: _buildVisibleBehavior(candidate),
      hiddenBehavior: _buildHiddenBehavior(candidate),
      priorityScore: scored.score,
      revealLevel: expression.revealLevel,
    );
  }

  String _buildDialogue(ActionArbitrationCandidate candidate) {
    final expression = candidate.intentExecution.expressionConstraints;
    if (expression.revealLevel == RevealLevel.silent) {
      return '';
    }

    if (candidate.intentExecution.actionPlan.steps.isEmpty) {
      return '';
    }

    final stepType = candidate.intentExecution.actionPlan.steps.first.type;
    final isSpeakStep =
        stepType == ActionStepType.verbal || stepType == ActionStepType.social;
    if (!isSpeakStep) {
      return '';
    }

    return candidate.intentExecution.selectedIntent.intent.trim();
  }

  List<String> _buildVisibleBehavior(ActionArbitrationCandidate candidate) {
    final steps = candidate.intentExecution.actionPlan.steps
        .map((step) => step.description.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
    if (steps.isNotEmpty) {
      return steps;
    }

    final tone = candidate.intentExecution.expressionConstraints.tone.trim();
    if (tone.isNotEmpty) {
      return <String>['语气:$tone'];
    }

    return const <String>[];
  }

  List<String> _buildHiddenBehavior(ActionArbitrationCandidate candidate) {
    final reveal = candidate.intentExecution.expressionConstraints.revealLevel;
    if (reveal == RevealLevel.direct) {
      return const <String>[];
    }

    final notes = candidate
        .intentExecution
        .expressionConstraints
        .behavioralNotes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (notes.isNotEmpty) {
      return notes;
    }

    final suppressed = candidate
        .intentExecution
        .selectedIntent
        .suppressedAlternatives
        .map((item) => item.intent.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .map((item) => '压制:$item')
        .toList();
    if (suppressed.isNotEmpty) {
      return suppressed;
    }

    return <String>['保持${reveal.label}'];
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({required this.candidate, required this.score});

  final ActionArbitrationCandidate candidate;
  final double score;
}

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();
