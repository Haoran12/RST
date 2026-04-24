import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/validation_result.dart';
import 'validation_rule.dart';

/// Validates that the character's embodiment constraints are respected.
///
/// This rule checks that:
/// - Visual signals are not present when vision is unavailable
/// - Auditory signals are not present when hearing is unavailable
/// - Olfactory signals are not present when smell is unavailable
/// - Mana signals are not present when mana sense is unavailable
/// - The output reflects the character's physical limitations
class EmbodimentIgnoredRule extends ValidationRule {
  const EmbodimentIgnoredRule();

  @override
  String get ruleId => 'embodiment_ignored';

  @override
  String get description => 'Checks that embodiment constraints are respected in filtered view and output';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];
    final sensory = embodimentState.sensoryCapabilities;

    // Check vision constraints
    results.addAll(_checkVisionConstraints(
      filteredView: filteredView,
      visionCapability: sensory.vision,
      output: output,
    ));

    // Check hearing constraints
    results.addAll(_checkHearingConstraints(
      filteredView: filteredView,
      hearingCapability: sensory.hearing,
      output: output,
    ));

    // Check smell constraints
    results.addAll(_checkSmellConstraints(
      filteredView: filteredView,
      smellCapability: sensory.smell,
      output: output,
    ));

    // Check mana sense constraints
    results.addAll(_checkManaConstraints(
      filteredView: filteredView,
      manaCapability: sensory.mana,
      output: output,
    ));

    // Check body constraints impact on output
    if (output != null) {
      results.addAll(_checkBodyConstraintsImpact(
        embodimentState: embodimentState,
        output: output,
      ));
    }

    return results;
  }

  List<ValidationResult> _checkVisionConstraints({
    required FilteredSceneView filteredView,
    required SensoryCapability visionCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];

    // Vision availability threshold
    const availabilityThreshold = 0.1;

    if (visionCapability.availability < availabilityThreshold) {
      // Vision is unavailable - should not have visible entities
      if (filteredView.visibleEntities.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Visible entities present despite vision unavailable',
          details: 'availability=${visionCapability.availability}, '
              'entityCount=${filteredView.visibleEntities.length}',
          context: {
            'availability': visionCapability.availability,
            'entityCount': filteredView.visibleEntities.length,
          },
        ));
      }

      // Check output for visual facts
      if (output != null) {
        final visualFacts = output.perceptionDelta.noticedFacts
            .where((f) => f.sourceType.toLowerCase() == 'visual')
            .toList();

        if (visualFacts.isNotEmpty) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Visual facts noticed despite vision unavailable',
            details: 'factCount=${visualFacts.length}',
            context: {
              'availability': visionCapability.availability,
              'facts': visualFacts.map((f) => f.factId).toList(),
            },
          ));
        }
      }
    }

    // Check for low acuity issues
    if (visionCapability.availability >= availabilityThreshold &&
        visionCapability.acuity < 0.3) {
      // Low acuity - check for high-clarity visual perceptions
      final highClarityEntities = filteredView.visibleEntities
          .where((e) => e.clarity > 0.7)
          .toList();

      if (highClarityEntities.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'High-clarity visual entities with low vision acuity',
          details: 'acuity=${visionCapability.acuity}, '
              'highClarityCount=${highClarityEntities.length}',
          context: {
            'acuity': visionCapability.acuity,
          },
        ));
      }
    }

    return results;
  }

  List<ValidationResult> _checkHearingConstraints({
    required FilteredSceneView filteredView,
    required SensoryCapability hearingCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];
    const availabilityThreshold = 0.1;

    if (hearingCapability.availability < availabilityThreshold) {
      if (filteredView.audibleSignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Audible signals present despite hearing unavailable',
          details: 'availability=${hearingCapability.availability}, '
              'signalCount=${filteredView.audibleSignals.length}',
        ));
      }

      if (output != null) {
        final auditoryFacts = output.perceptionDelta.noticedFacts
            .where((f) => f.sourceType.toLowerCase() == 'auditory')
            .toList();

        if (auditoryFacts.isNotEmpty) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Auditory facts noticed despite hearing unavailable',
            details: 'factCount=${auditoryFacts.length}',
          ));
        }
      }
    }

    return results;
  }

  List<ValidationResult> _checkSmellConstraints({
    required FilteredSceneView filteredView,
    required SensoryCapability smellCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];
    const availabilityThreshold = 0.1;

    if (smellCapability.availability < availabilityThreshold) {
      if (filteredView.olfactorySignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Olfactory signals present despite smell unavailable',
          details: 'availability=${smellCapability.availability}, '
              'signalCount=${filteredView.olfactorySignals.length}',
        ));
      }

      if (output != null) {
        final olfactoryFacts = output.perceptionDelta.noticedFacts
            .where((f) => f.sourceType.toLowerCase() == 'olfactory')
            .toList();

        if (olfactoryFacts.isNotEmpty) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Olfactory facts noticed despite smell unavailable',
            details: 'factCount=${olfactoryFacts.length}',
          ));
        }
      }
    }

    return results;
  }

  List<ValidationResult> _checkManaConstraints({
    required FilteredSceneView filteredView,
    required ManaSensoryCapability manaCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];
    const availabilityThreshold = 0.1;

    if (manaCapability.availability < availabilityThreshold) {
      if (filteredView.manaSignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Mana signals present despite mana sense unavailable',
          details: 'availability=${manaCapability.availability}, '
              'signalCount=${filteredView.manaSignals.length}',
        ));
      }

      if (output != null) {
        final manaFacts = output.perceptionDelta.noticedFacts
            .where((f) => f.sourceType.toLowerCase() == 'mana')
            .toList();

        if (manaFacts.isNotEmpty) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.error,
            message: 'Mana facts noticed despite mana sense unavailable',
            details: 'factCount=${manaFacts.length}',
          ));
        }
      }
    }

    // Check for overload conditions
    if (manaCapability.overloadLevel > 0.7 && output != null) {
      // When overloaded, mana perceptions should be distorted or reduced
      final manaFacts = output.perceptionDelta.noticedFacts
          .where((f) => f.sourceType.toLowerCase() == 'mana')
          .toList();

      if (manaFacts.length > 3) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'Many mana facts noticed despite high overload level',
          details: 'overloadLevel=${manaCapability.overloadLevel}, '
              'factCount=${manaFacts.length}',
        ));
      }
    }

    return results;
  }

  List<ValidationResult> _checkBodyConstraintsImpact({
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput output,
  }) {
    final results = <ValidationResult>[];
    final constraints = embodimentState.bodyConstraints;

    // High pain should affect reasoning
    if (constraints.painLoad > 0.7) {
      // Check if output reflects pain impact
      final hasPainIndicator = output.intentPlan.expressionConstraints
          .behavioralNotes.any((note) =>
              note.toLowerCase().contains('pain') ||
              note.toLowerCase().contains('suffer') ||
              note.toLowerCase().contains('hurt'));

      final hasUrgentIntent = output.intentPlan.decisionFrame.timePressure > 0.7;

      if (!hasPainIndicator && !hasUrgentIntent) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'High pain load but no visible impact on behavior',
          details: 'painLoad=${constraints.painLoad}',
        ));
      }
    }

    // Low cognitive clarity should affect complex reasoning
    if (constraints.cognitiveClarity < 0.3) {
      final complexHypotheses = output.beliefUpdate.newHypotheses
          .where((h) => h.prior > 0.5)
          .toList();

      if (complexHypotheses.length > 2) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'Complex reasoning with low cognitive clarity',
          details: 'cognitiveClarity=${constraints.cognitiveClarity}, '
              'hypothesisCount=${complexHypotheses.length}',
        ));
      }
    }

    return results;
  }
}
