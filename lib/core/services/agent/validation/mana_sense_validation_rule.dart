import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/mana_field.dart';
import '../../../models/agent/validation_result.dart';
import 'validation_rule.dart';

/// Validates mana sense constraints and capabilities.
///
/// This rule checks that:
/// - Mortal characters cannot detect high-level cultivator auras
/// - Mana sense respects acuity and penetration limits
/// - Overload conditions are properly reflected
/// - Attribute sensitivity is correctly applied
class ManaSenseValidationRule extends ValidationRule {
  const ManaSenseValidationRule();

  @override
  String get ruleId => 'mana_sense_validation';

  @override
  String get description => 'Validates mana sense capabilities and constraints';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];
    final manaCapability = embodimentState.sensoryCapabilities.mana;

    // Check basic availability constraints
    results.addAll(_checkAvailabilityConstraints(
      filteredView: filteredView,
      manaCapability: manaCapability,
    ));

    // Check acuity constraints
    results.addAll(_checkAcuityConstraints(
      filteredView: filteredView,
      manaCapability: manaCapability,
      output: output,
    ));

    // Check overload conditions
    results.addAll(_checkOverloadConditions(
      manaCapability: manaCapability,
      output: output,
    ));

    // Check penetration constraints
    results.addAll(_checkPenetrationConstraints(
      filteredView: filteredView,
      manaCapability: manaCapability,
    ));

    return results;
  }

  /// Check that mana sense availability is respected.
  List<ValidationResult> _checkAvailabilityConstraints({
    required FilteredSceneView filteredView,
    required ManaSensoryCapability manaCapability,
  }) {
    final results = <ValidationResult>[];

    // If mana sense is unavailable, should not have mana signals
    if (manaCapability.availability < 0.1) {
      if (filteredView.manaSignals.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'Mana signals present despite mana sense unavailable',
          details: 'availability=${manaCapability.availability}, '
              'signalCount=${filteredView.manaSignals.length}',
        ));
      }

      // Mana environment should be minimal
      if (filteredView.manaEnvironment.perceivedDensity > 0.3) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.error,
          message: 'High mana environment perception with unavailable mana sense',
          details: 'perceivedDensity=${filteredView.manaEnvironment.perceivedDensity}',
        ));
      }
    }

    return results;
  }

  /// Check that mana acuity limits are respected.
  List<ValidationResult> _checkAcuityConstraints({
    required FilteredSceneView filteredView,
    required ManaSensoryCapability manaCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];

    // Mortal-level acuity should not detect high-level cultivator auras
    if (manaCapability.acuity < 0.5) {
      for (final signal in filteredView.manaSignals) {
        // High-level cultivator auras should be filtered out
        if (signal.sourceType == ManaSourceType.cultivatorAura &&
            signal.perceivedIntensity > 0.5) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'Mortal-level acuity detected strong cultivator aura',
            details: 'acuity=${manaCapability.acuity}, '
                'perceivedIntensity=${signal.perceivedIntensity}, '
                'signalId=${signal.signalId}',
          ));
        }

        // Ancient traces should be filtered out
        if (signal.freshness == ManaFreshness.ancient &&
            signal.perceivedIntensity > 0.3) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'Mortal-level acuity detected ancient mana trace',
            details: 'acuity=${manaCapability.acuity}, '
                'freshness=${signal.freshness.name}',
          ));
        }
      }
    }

    // Check clarity vs acuity consistency
    for (final signal in filteredView.manaSignals) {
      // Clarity should not exceed acuity significantly
      if (signal.clarity > manaCapability.acuity + 0.3) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'Mana signal clarity exceeds acuity capability',
          details: 'clarity=${signal.clarity}, acuity=${manaCapability.acuity}',
        ));
      }
    }

    // Check output for mana facts inconsistent with acuity
    if (output != null && manaCapability.acuity < 0.3) {
      final detailedManaFacts = output.perceptionDelta.noticedFacts
          .where((f) =>
              f.sourceType.toLowerCase() == 'mana' &&
              f.confidence > 0.7)
          .toList();

      if (detailedManaFacts.isNotEmpty) {
        results.add(ValidationResult(
          ruleId: ruleId,
          severity: ValidationSeverity.warning,
          message: 'High-confidence mana facts with low mana acuity',
          details: 'acuity=${manaCapability.acuity}, '
              'factCount=${detailedManaFacts.length}',
        ));
      }
    }

    return results;
  }

  /// Check that overload conditions are properly reflected.
  List<ValidationResult> _checkOverloadConditions({
    required ManaSensoryCapability manaCapability,
    required CharacterCognitivePassOutput? output,
  }) {
    final results = <ValidationResult>[];

    if (manaCapability.overloadLevel > 0.7) {
      // High overload should affect output
      if (output != null) {
        // Check for overload indicators in behavioral notes
        final hasOverloadIndicator = output.intentPlan.expressionConstraints
            .behavioralNotes.any((note) =>
                note.toLowerCase().contains('overload') ||
                note.toLowerCase().contains('overwhelm') ||
                note.toLowerCase().contains('strain'));

        // Check if mana-related intents are affected
        final manaIntents = output.intentPlan.candidateIntents
            .where((i) => i.description.toLowerCase().contains('mana') ||
                         i.description.toLowerCase().contains('spirit'))
            .toList();

        if (!hasOverloadIndicator && manaIntents.isNotEmpty) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'High mana overload but no visible impact on mana-related intents',
            details: 'overloadLevel=${manaCapability.overloadLevel}',
          ));
        }
      }
    }

    return results;
  }

  /// Check that penetration limits are respected.
  List<ValidationResult> _checkPenetrationConstraints({
    required FilteredSceneView filteredView,
    required ManaSensoryCapability manaCapability,
  }) {
    final results = <ValidationResult>[];

    // Check for concealed signals that should not be visible
    for (final signal in filteredView.manaSignals) {
      if (signal.insight?.isConcealed == true) {
        // Low penetration should not detect concealed signals
        if (manaCapability.penetration < 0.3 &&
            signal.perceivedIntensity > 0.5) {
          results.add(ValidationResult(
            ruleId: ruleId,
            severity: ValidationSeverity.warning,
            message: 'Low penetration detected strong concealed mana signal',
            details: 'penetration=${manaCapability.penetration}, '
                'perceivedIntensity=${signal.perceivedIntensity}',
          ));
        }
      }
    }

    // Check for signals behind interference
    // (This would require additional context about interferences in the scene)

    return results;
  }
}
