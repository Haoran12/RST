import '../../../models/agent/embodiment_state.dart';
import '../../../models/agent/filtered_scene_view.dart';
import '../../../models/agent/memory_entry.dart';
import '../../../models/agent/cognitive_pass_io.dart';
import '../../../models/agent/validation_result.dart';
import 'validation_rule.dart';
import 'omniscience_leakage_rule.dart';
import 'embodiment_ignored_rule.dart';
import 'memory_leakage_rule.dart';
import 'mana_sense_validation_rule.dart';

/// Aggregates all validation rules and runs them against cognitive pass output.
///
/// Usage:
/// ```dart
/// final validator = AgentValidator.withDefaultRules();
/// final results = validator.validate(
///   filteredView: filteredView,
///   embodimentState: embodimentState,
///   output: cognitiveOutput,
///   accessibleMemories: memories,
/// );
///
/// final errors = results.where((r) => r.severity == ValidationSeverity.error);
/// if (errors.isNotEmpty) {
///   // Handle validation failures
/// }
/// ```
class AgentValidator {
  const AgentValidator(this._rules);

  /// Create validator with default rule set.
  factory AgentValidator.withDefaultRules() {
    return AgentValidator([
      const OmniscienceLeakageRule(),
      const EmbodimentIgnoredRule(),
      const MemoryLeakageRule(),
      const ManaSenseValidationRule(),
    ]);
  }

  /// Create validator with no rules (for testing or custom configurations).
  factory AgentValidator.empty() {
    return AgentValidator([]);
  }

  final List<ValidationRule> _rules;

  /// Get all registered rules.
  List<ValidationRule> get rules => List.unmodifiable(_rules);

  /// Add a rule to the validator.
  AgentValidator withRule(ValidationRule rule) {
    return AgentValidator([..._rules, rule]);
  }

  /// Remove a rule by its ID.
  AgentValidator withoutRule(String ruleId) {
    return AgentValidator(_rules.where((r) => r.ruleId != ruleId).toList());
  }

  /// Run all validation rules and collect results.
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];

    for (final rule in _rules) {
      try {
        final ruleResults = rule.validate(
          filteredView: filteredView,
          embodimentState: embodimentState,
          output: output,
          accessibleMemories: accessibleMemories,
        );
        results.addAll(ruleResults);
      } catch (e) {
        // Rule threw an exception - record as error
        results.add(ValidationResult(
          ruleId: rule.ruleId,
          severity: ValidationSeverity.error,
          message: 'Validation rule threw exception: $e',
          details: 'rule=${rule.ruleId}',
        ));
      }
    }

    return results;
  }

  /// Check if there are any error-level validation failures.
  bool hasErrors(List<ValidationResult> results) {
    return results.any((r) => r.severity == ValidationSeverity.error);
  }

  /// Check if there are any warning-level validation failures.
  bool hasWarnings(List<ValidationResult> results) {
    return results.any((r) => r.severity == ValidationSeverity.warning);
  }

  /// Get only error-level results.
  List<ValidationResult> getErrors(List<ValidationResult> results) {
    return results.where((r) => r.severity == ValidationSeverity.error).toList();
  }

  /// Get only warning-level results.
  List<ValidationResult> getWarnings(List<ValidationResult> results) {
    return results.where((r) => r.severity == ValidationSeverity.warning).toList();
  }

  /// Group results by rule ID.
  Map<String, List<ValidationResult>> groupByRule(List<ValidationResult> results) {
    final grouped = <String, List<ValidationResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.ruleId, () => []).add(result);
    }
    return grouped;
  }

  /// Generate a summary report of validation results.
  String generateReport(List<ValidationResult> results) {
    final buffer = StringBuffer();
    buffer.writeln('=== Agent Validation Report ===');
    buffer.writeln();

    final errors = getErrors(results);
    final warnings = getWarnings(results);
    final infos = results.where((r) => r.severity == ValidationSeverity.info).toList();

    buffer.writeln('Summary: ${results.length} issues');
    buffer.writeln('  Errors: ${errors.length}');
    buffer.writeln('  Warnings: ${warnings.length}');
    buffer.writeln('  Info: ${infos.length}');
    buffer.writeln();

    if (errors.isNotEmpty) {
      buffer.writeln('--- Errors ---');
      for (final error in errors) {
        buffer.writeln('[${error.ruleId}] ${error.message}');
        if (error.details != null) {
          buffer.writeln('  Details: ${error.details}');
        }
      }
      buffer.writeln();
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('--- Warnings ---');
      for (final warning in warnings) {
        buffer.writeln('[${warning.ruleId}] ${warning.message}');
        if (warning.details != null) {
          buffer.writeln('  Details: ${warning.details}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
