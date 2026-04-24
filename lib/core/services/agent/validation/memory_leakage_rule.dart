import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/validation_result.dart';
import 'validation_rule.dart';

/// Validates that the character only accesses memories they are allowed to access.
///
/// This rule checks that:
/// - Private memories are only accessible to the owner
/// - Shared memories are only accessible to characters in known_by list
/// - Output does not reference memories the character cannot access
class MemoryLeakageRule extends ValidationRule {
  const MemoryLeakageRule();

  @override
  String get ruleId => 'memory_leakage';

  @override
  String get description => 'Checks that memory access respects visibility and known_by constraints';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    // Validate memory entry structure
    results.addAll(_validateMemoryStructure(accessibleMemories));

    // Validate output memory references
    if (output != null) {
      results.addAll(_validateMemoryReferences(
        output: output,
        accessibleMemories: accessibleMemories,
        characterId: filteredView.characterId,
      ));
    }

    return results;
  }

  /// Validate that memory entries have correct structure.
  List<ValidationResult> _validateMemoryStructure(
    List<MemoryEntry> memories,
  ) {
    final results = <ValidationResult>[];

    for (final memory in memories) {
      // Private memories should only have owner in known_by
      if (memory.visibility == MemoryVisibility.private) {
        if (memory.knownBy.length != 1 ||
            memory.knownBy.first != memory.ownerCharacterId) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Private memory has incorrect known_by list',
            details: 'memoryId=${memory.memoryId}, '
                'owner=${memory.ownerCharacterId}, '
                'knownBy=${memory.knownBy.join(",")}',
          ));
        }
      }

      // Shared memories should have at least owner in known_by
      if (memory.visibility == MemoryVisibility.shared) {
        if (!memory.knownBy.contains(memory.ownerCharacterId)) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Shared memory missing owner in known_by',
            details: 'memoryId=${memory.memoryId}, '
                'owner=${memory.ownerCharacterId}',
          ));
        }
      }

      // Check for empty known_by (invalid state)
      if (memory.knownBy.isEmpty &&
          memory.visibility != MemoryVisibility.public) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Non-public memory has empty known_by list',
          details: 'memoryId=${memory.memoryId}, '
              'visibility=${memory.visibility.name}',
        ));
      }
    }

    return results;
  }

  /// Validate that output only references accessible memories.
  List<ValidationResult> _validateMemoryReferences({
    required CharacterCognitivePassOutput output,
    required List<MemoryEntry> accessibleMemories,
    required String characterId,
  }) {
    final results = <ValidationResult>[];
    final accessibleMemoryIds = accessibleMemories.map((m) => m.memoryId).toSet();

    // Check memory activations in perception delta
    for (final activation in output.perceptionDelta.memoryActivations) {
      if (activation.memoryId.isNotEmpty &&
          !accessibleMemoryIds.contains(activation.memoryId)) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Output references inaccessible memory',
          details: 'memoryId=${activation.memoryId}, '
              'activationReason=${activation.activationReason}',
          context: {
            'memoryId': activation.memoryId,
            'characterId': characterId,
          },
        ));
      }
    }

    // Check belief update for memory references
    for (final belief in output.beliefUpdate.stableBeliefsReinforced) {
      final memoryRefs = _extractMemoryReferences(belief.evidence);
      for (final ref in memoryRefs) {
        if (ref.isNotEmpty && !accessibleMemoryIds.contains(ref)) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'Belief reinforcement references inaccessible memory',
            details: 'memoryId=$ref, beliefId=${belief.beliefId}',
          ));
        }
      }
    }

    // Check intent dependencies for memory references
    for (final dep in output.intentPlan.selectedIntent.dependsOnBeliefs) {
      final memoryRefs = _extractMemoryReferences(dep);
      for (final ref in memoryRefs) {
        if (ref.isNotEmpty && !accessibleMemoryIds.contains(ref)) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'Intent depends on belief referencing inaccessible memory',
            details: 'memoryId=$ref',
          ));
        }
      }
    }

    return results;
  }

  /// Extract memory references from text content.
  /// Looks for patterns like memory_id, [memory_id], or "memory:memory_id".
  Set<String> _extractMemoryReferences(String content) {
    final references = <String>{};

    // Match [memory_id] pattern
    final bracketPattern = RegExp(r'\[([a-zA-Z0-9_]+)\]');
    for (final match in bracketPattern.allMatches(content)) {
      references.add(match.group(1)!);
    }

    // Match memory:id pattern
    final memoryPattern = RegExp(r'memory[:\s]+([a-zA-Z0-9_]+)');
    for (final match in memoryPattern.allMatches(content)) {
      references.add(match.group(1)!);
    }

    return references;
  }
}