import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/validation_result.dart';

/// Base class for all validation rules.
///
/// Each rule checks a specific aspect of the cognitive pass output
/// to ensure it respects the character's access boundaries and constraints.
abstract class ValidationRule {
  const ValidationRule();

  /// Unique identifier for this rule.
  String get ruleId;

  /// Human-readable description of what this rule checks.
  String get description;

  /// Validate the given context and return any issues found.
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  });
}
