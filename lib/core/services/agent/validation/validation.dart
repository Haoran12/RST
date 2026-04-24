/// Validation rules and aggregator for agent cognitive pass output.
///
/// This module provides validation infrastructure to ensure that:
/// - Characters do not access information they cannot perceive
/// - Embodiment constraints are respected
/// - Memory access follows visibility rules
/// - Mana sense capabilities are correctly applied
library;

export 'validation_rule.dart';
export 'omniscience_leakage_rule.dart';
export 'embodiment_ignored_rule.dart';
export 'memory_leakage_rule.dart';
export 'mana_sense_validation_rule.dart';
export 'agent_validator.dart';
