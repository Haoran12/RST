import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';

/// Request for belief update.
class BeliefUpdateRequest {
  const BeliefUpdateRequest({
    required this.characterId,
    required this.currentBeliefState,
    required this.beliefUpdate,
    required this.currentRelationModels,
  });

  final String characterId;
  final BeliefState currentBeliefState;
  final BeliefUpdate beliefUpdate;
  final Map<String, dynamic> currentRelationModels;
}

/// Result of belief update.
class BeliefUpdateResult {
  const BeliefUpdateResult({
    required this.newBeliefState,
    required this.updatedRelationModels,
    required this.changes,
  });

  final BeliefState newBeliefState;
  final Map<String, dynamic> updatedRelationModels;
  final List<BeliefChangeRecord> changes;
}

/// Record of a single belief change.
class BeliefChangeRecord {
  const BeliefChangeRecord({
    required this.type,
    required this.beliefId,
    required this.oldValue,
    required this.newValue,
    required this.reason,
  });

  final BeliefChangeType type;
  final String beliefId;
  final dynamic oldValue;
  final dynamic newValue;
  final String reason;

  @override
  String toString() => 'BeliefChangeRecord($type, $beliefId: $oldValue -> $newValue)';
}

/// Type of belief change.
enum BeliefChangeType {
  reinforced,
  weakened,
  hypothesisAdded,
  hypothesisPromoted,
  hypothesisDiscarded,
  relationUpdated,
}

/// Updates character belief state based on cognitive pass output.
///
/// This service handles:
/// - Reinforcing/weakening existing beliefs
/// - Adding new hypotheses
/// - Updating relation models
/// - Managing hypothesis lifecycle
class BeliefUpdater {
  const BeliefUpdater({
    this.minConfidence = 0.1,
    this.maxConfidence = 0.95,
    this.hypothesisPromotionThreshold = 0.8,
    this.hypothesisDiscardThreshold = 0.2,
  });

  final double minConfidence;
  final double maxConfidence;
  final double hypothesisPromotionThreshold;
  final double hypothesisDiscardThreshold;

  /// Apply belief update to character state.
  BeliefUpdateResult update(BeliefUpdateRequest request) {
    final changes = <BeliefChangeRecord>[];
    final newConfidences = Map<String, double>.from(request.currentBeliefState.beliefConfidences);
    final newHypotheses = List<String>.from(request.currentBeliefState.activeHypotheses);
    String? newCurrentHypothesis = request.currentBeliefState.currentHypothesis;
    final newRelationModels = Map<String, dynamic>.from(request.currentRelationModels);

    // Process reinforced beliefs
    for (final reinforced in request.beliefUpdate.stableBeliefsReinforced) {
      final oldConfidence = newConfidences[reinforced.beliefId] ?? 0.5;
      final newConfidence = _clampConfidence(
        oldConfidence + (reinforced.newConfidence - oldConfidence) * 0.5,
      );
      newConfidences[reinforced.beliefId] = newConfidence;

      changes.add(BeliefChangeRecord(
        type: BeliefChangeType.reinforced,
        beliefId: reinforced.beliefId,
        oldValue: oldConfidence,
        newValue: newConfidence,
        reason: reinforced.evidence,
      ));
    }

    // Process weakened beliefs
    for (final weakened in request.beliefUpdate.stableBeliefsWeakened) {
      final oldConfidence = newConfidences[weakened.beliefId] ?? 0.5;
      final rawNewConfidence = weakened.newConfidence;

      // Remove belief if confidence drops too low (before clamping)
      if (rawNewConfidence < minConfidence) {
        newConfidences.remove(weakened.beliefId);
        changes.add(BeliefChangeRecord(
          type: BeliefChangeType.weakened,
          beliefId: weakened.beliefId,
          oldValue: oldConfidence,
          newValue: null,
          reason: '${weakened.counterEvidence} (removed: confidence below ${minConfidence})',
        ));
      } else {
        final newConfidence = _clampConfidence(rawNewConfidence);
        newConfidences[weakened.beliefId] = newConfidence;

        changes.add(BeliefChangeRecord(
          type: BeliefChangeType.weakened,
          beliefId: weakened.beliefId,
          oldValue: oldConfidence,
          newValue: newConfidence,
          reason: weakened.counterEvidence,
        ));
      }
    }

    // Process new hypotheses
    for (final newHypothesis in request.beliefUpdate.newHypotheses) {
      if (!newHypotheses.contains(newHypothesis.hypothesisId)) {
        newHypotheses.add(newHypothesis.hypothesisId);
        newConfidences[newHypothesis.hypothesisId] = newHypothesis.prior;

        changes.add(BeliefChangeRecord(
          type: BeliefChangeType.hypothesisAdded,
          beliefId: newHypothesis.hypothesisId,
          oldValue: null,
          newValue: newHypothesis.prior,
          reason: newHypothesis.basis,
        ));

        // Promote to current hypothesis if high confidence
        if (newHypothesis.prior >= hypothesisPromotionThreshold) {
          newCurrentHypothesis = newHypothesis.hypothesisId;
          changes.add(BeliefChangeRecord(
            type: BeliefChangeType.hypothesisPromoted,
            beliefId: newHypothesis.hypothesisId,
            oldValue: null,
            newValue: 'current',
            reason: 'High prior confidence: ${newHypothesis.prior}',
          ));
        }
      }
    }

    // Check for hypothesis discard
    final hypothesesToRemove = <String>[];
    for (final hypothesisId in newHypotheses) {
      final confidence = newConfidences[hypothesisId] ?? 0.5;
      if (confidence < hypothesisDiscardThreshold) {
        hypothesesToRemove.add(hypothesisId);
        changes.add(BeliefChangeRecord(
          type: BeliefChangeType.hypothesisDiscarded,
          beliefId: hypothesisId,
          oldValue: confidence,
          newValue: null,
          reason: 'Confidence below threshold',
        ));
      }
    }

    for (final id in hypothesesToRemove) {
      newHypotheses.remove(id);
      newConfidences.remove(id);
      if (newCurrentHypothesis == id) {
        newCurrentHypothesis = newHypotheses.isNotEmpty ? newHypotheses.first : null;
      }
    }

    // Process relation model updates
    for (final revised in request.beliefUpdate.revisedModelsOfOthers) {
      final targetId = revised.targetCharacterId;
      final existingModel = request.currentRelationModels[targetId];

      Map<String, dynamic> newModel;
      if (existingModel is Map<String, dynamic>) {
        newModel = Map<String, dynamic>.from(existingModel);
      } else {
        newModel = <String, dynamic>{};
      }

      newModel[revised.aspect] = revised.newValue;
      newRelationModels[targetId] = newModel;

      changes.add(BeliefChangeRecord(
        type: BeliefChangeType.relationUpdated,
        beliefId: targetId,
        oldValue: revised.oldValue,
        newValue: revised.newValue,
        reason: revised.reason,
      ));
    }

    final newBeliefState = BeliefState(
      beliefConfidences: newConfidences,
      activeHypotheses: newHypotheses,
      currentHypothesis: newCurrentHypothesis,
    );

    return BeliefUpdateResult(
      newBeliefState: newBeliefState,
      updatedRelationModels: newRelationModels,
      changes: changes,
    );
  }

  /// Merge multiple belief updates (for multi-character scenarios).
  BeliefState mergeUpdates({
    required BeliefState baseState,
    required List<BeliefUpdate> updates,
  }) {
    var currentState = baseState;

    for (final beliefUpdate in updates) {
      final result = update(BeliefUpdateRequest(
        characterId: '',
        currentBeliefState: currentState,
        beliefUpdate: beliefUpdate,
        currentRelationModels: {},
      ));
      currentState = result.newBeliefState;
    }

    return currentState;
  }

  /// Check for contradictions in belief state.
  List<ContradictionRecord> detectContradictions(BeliefState state) {
    final contradictions = <ContradictionRecord>[];

    // Check for mutually exclusive beliefs (simplified example)
    final beliefKeys = state.beliefConfidences.keys.toList();

    for (var i = 0; i < beliefKeys.length; i++) {
      for (var j = i + 1; j < beliefKeys.length; j++) {
        final belief1 = beliefKeys[i];
        final belief2 = beliefKeys[j];
        final conf1 = state.beliefConfidences[belief1] ?? 0.0;
        final conf2 = state.beliefConfidences[belief2] ?? 0.0;

        if (_areMutuallyExclusive(belief1, belief2) && conf1 > 0.5 && conf2 > 0.5) {
          contradictions.add(ContradictionRecord(
            belief1: belief1,
            belief2: belief2,
            confidence1: conf1,
            confidence2: conf2,
            severity: (conf1 + conf2) / 2,
          ));
        }
      }
    }

    return contradictions;
  }

  bool _areMutuallyExclusive(String belief1, String belief2) {
    // Simplified mutual exclusion check
    // In a real implementation, this would use a knowledge graph or ontology
    final exclusivePairs = [
      {'alive', 'dead'},
      {'friend', 'enemy'},
      {'honest', 'deceptive'},
      {'safe', 'dangerous'},
    ];

    for (final pair in exclusivePairs) {
      if ((pair.contains(belief1.toLowerCase()) && pair.contains(belief2.toLowerCase())) ||
          (pair.contains(belief2.toLowerCase()) && pair.contains(belief1.toLowerCase()))) {
        return true;
      }
    }

    return false;
  }

  double _clampConfidence(double value) {
    return value.clamp(minConfidence, maxConfidence);
  }
}

/// Record of a contradiction between beliefs.
class ContradictionRecord {
  const ContradictionRecord({
    required this.belief1,
    required this.belief2,
    required this.confidence1,
    required this.confidence2,
    required this.severity,
  });

  final String belief1;
  final String belief2;
  final double confidence1;
  final double confidence2;
  final double severity;

  @override
  String toString() => 'ContradictionRecord($belief1 vs $belief2, severity: $severity)';
}
