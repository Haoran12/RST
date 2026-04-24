import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/validation_result.dart';
import 'validation_rule.dart';

/// Validates that the character does not reference entities or signals
/// that are not in their filtered scene view.
///
/// This rule prevents "omniscience leakage" where a character acts on
/// information they could not have perceived.
class OmniscienceLeakageRule extends ValidationRule {
  const OmniscienceLeakageRule();

  @override
  String get ruleId => 'omniscience_leakage';

  @override
  String get description => 'Checks that output does not reference inaccessible entities or signals';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    if (output == null) return results;

    // Build set of accessible entity IDs
    final visibleEntityIds = filteredView.visibleEntities
        .map((e) => e.entityId)
        .toSet();

    // Build set of accessible signal IDs (for future signal reference validation)
    final _ = <String>{
      ...filteredView.audibleSignals.map((s) => s.signalId),
      ...filteredView.olfactorySignals.map((s) => s.signalId),
      ...filteredView.tactileSignals.map((s) => s.signalId),
      ...filteredView.manaSignals.map((s) => s.signalId),
    };

    // Check noticed facts for inaccessible references
    for (final fact in output.perceptionDelta.noticedFacts) {
      // Check if fact references an entity not in visible set
      final referencedEntities = _extractEntityReferences(fact.content);
      for (final entityId in referencedEntities) {
        if (!visibleEntityIds.contains(entityId)) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Noticed fact references invisible entity',
            details: 'entityId=$entityId, factId=${fact.factId}',
            context: {'factContent': fact.content, 'sourceType': fact.sourceType},
          ));
        }
      }

      // Check source type accessibility
      if (!_isSourceTypeAccessible(fact.sourceType, filteredView)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Noticed fact from inaccessible source type',
          details: 'sourceType=${fact.sourceType}, factId=${fact.factId}',
          context: {'factContent': fact.content},
        ));
      }
    }

    // Check subjective impressions for invisible targets
    for (final impression in output.perceptionDelta.subjectiveImpressions) {
      if (impression.targetEntityId.isNotEmpty &&
          !visibleEntityIds.contains(impression.targetEntityId)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Subjective impression targets invisible entity',
          details: 'entityId=${impression.targetEntityId}',
          context: {'impression': impression.impression},
        ));
      }
    }

    // Check intent plan for references to invisible entities
    final intentEntities = _extractEntityReferences(
      output.intentPlan.selectedIntent.intent,
    );
    for (final entityId in intentEntities) {
      if (entityId.isNotEmpty && !visibleEntityIds.contains(entityId)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'Intent references invisible entity',
          details: 'entityId=$entityId',
          context: {'intent': output.intentPlan.selectedIntent.intent},
        ));
      }
    }

    return results;
  }

  /// Extract entity references from text content.
  /// Looks for patterns like [entity_id] or "entity:entity_id".
  Set<String> _extractEntityReferences(String content) {
    final references = <String>{};

    // Match [entity_id] pattern
    final bracketPattern = RegExp(r'\[([a-zA-Z0-9_]+)\]');
    for (final match in bracketPattern.allMatches(content)) {
      references.add(match.group(1)!);
    }

    // Match entity:id pattern
    final entityPattern = RegExp(r'entity[:\s]+([a-zA-Z0-9_]+)');
    for (final match in entityPattern.allMatches(content)) {
      references.add(match.group(1)!);
    }

    return references;
  }

  /// Check if a source type is accessible in the filtered view.
  bool _isSourceTypeAccessible(String sourceType, FilteredSceneView view) {
    return switch (sourceType.toLowerCase()) {
      'visual' => view.visibleEntities.isNotEmpty,
      'auditory' => view.audibleSignals.isNotEmpty,
      'olfactory' => view.olfactorySignals.isNotEmpty,
      'tactile' => view.tactileSignals.isNotEmpty,
      'mana' => view.manaSignals.isNotEmpty,
      'internal' || 'memory' || 'inference' => true,
      _ => true, // Allow unknown source types
    };
  }
}
