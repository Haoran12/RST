import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/embodiment_state.dart';
import 'package:rst/core/models/agent/filtered_scene_view.dart';
import 'package:rst/core/models/agent/mana_field.dart';
import 'package:rst/core/models/agent/memory_entry.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/validation_result.dart';
import 'package:rst/core/services/agent/validation/validation.dart';

void main() {
  group('AgentValidator', () {
    test('withDefaultRules includes all standard rules', () {
      final validator = AgentValidator.withDefaultRules();

      expect(validator.rules.length, equals(4));
      expect(validator.rules.any((r) => r.ruleId == 'omniscience_leakage'), isTrue);
      expect(validator.rules.any((r) => r.ruleId == 'embodiment_ignored'), isTrue);
      expect(validator.rules.any((r) => r.ruleId == 'memory_leakage'), isTrue);
      expect(validator.rules.any((r) => r.ruleId == 'mana_sense_validation'), isTrue);
    });

    test('empty creates validator with no rules', () {
      final validator = AgentValidator.empty();

      expect(validator.rules, isEmpty);
    });

    test('withRule adds rule to validator', () {
      final validator = AgentValidator.empty()
          .withRule(const OmniscienceLeakageRule());

      expect(validator.rules.length, equals(1));
      expect(validator.rules.first.ruleId, equals('omniscience_leakage'));
    });

    test('withoutRule removes rule by ID', () {
      final validator = AgentValidator.withDefaultRules()
          .withoutRule('omniscience_leakage');

      expect(validator.rules.length, equals(3));
      expect(validator.rules.any((r) => r.ruleId == 'omniscience_leakage'), isFalse);
    });

    test('hasErrors and hasWarnings work correctly', () {
      final results = [
        ValidationResult(
          ruleId: 'test',
          severity: ValidationSeverity.error,
          message: 'error',
        ),
        ValidationResult(
          ruleId: 'test',
          severity: ValidationSeverity.warning,
          message: 'warning',
        ),
      ];

      final validator = AgentValidator.empty();
      expect(validator.hasErrors(results), isTrue);
      expect(validator.hasWarnings(results), isTrue);
    });

    test('generateReport produces formatted output', () {
      final results = [
        ValidationResult(
          ruleId: 'test_rule',
          severity: ValidationSeverity.error,
          message: 'Test error message',
          details: 'Test details',
        ),
      ];

      final validator = AgentValidator.empty();
      final report = validator.generateReport(results);

      expect(report, contains('Agent Validation Report'));
      expect(report, contains('Errors: 1'));
      expect(report, contains('test_rule'));
      expect(report, contains('Test error message'));
    });
  });

  group('OmniscienceLeakageRule', () {
    test('passes when output references only visible entities', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        visibleEntities: [
          VisibleEntity(entityId: 'entity1', visibilityScore: 0.8, clarity: 0.9, notes: ''),
        ],
        spatialContext: const SpatialContext(),
      );

      final embodimentState = _createDefaultEmbodiment();
      final output = CharacterCognitivePassOutput(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        perceptionDelta: PerceptionDelta(
          noticedFacts: [
            NoticedFact(
              factId: 'fact1',
              content: 'Saw [entity1] moving',
              sourceType: 'visual',
            ),
          ],
        ),
        beliefUpdate: BeliefUpdate(
          emotionalShift: const EmotionalShift(
            emotion: 'neutral',
            oldIntensity: 0.5,
            newIntensity: 0.5,
            trigger: 'test',
          ),
        ),
        intentPlan: IntentPlan(
          activeGoals: const CurrentGoals(),
          decisionFrame: const DecisionFrame(
            context: 'test',
            constraints: 'none',
            timePressure: 0.0,
          ),
          selectedIntent: SelectedIntent(intent: 'greet entity1', reason: 'test'),
          expressionConstraints: const ExpressionConstraints(
            revealLevel: RevealLevel.direct,
          ),
        ),
      );

      final rule = const OmniscienceLeakageRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: [],
      );

      expect(results.where((r) => r.severity == ValidationSeverity.error), isEmpty);
    });

    test('detects reference to invisible entity', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        visibleEntities: [
          VisibleEntity(entityId: 'entity1', visibilityScore: 0.8, clarity: 0.9, notes: ''),
        ],
        spatialContext: const SpatialContext(),
      );

      final embodimentState = _createDefaultEmbodiment();
      final output = _createDefaultCognitiveOutput(
        noticedFacts: [
          NoticedFact(
            factId: 'fact1',
            content: 'Saw [entity2] hiding', // entity2 not in visible entities
            sourceType: 'visual',
          ),
        ],
      );

      final rule = const OmniscienceLeakageRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: [],
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.error &&
            r.message.contains('invisible entity')),
        isTrue,
      );
    });
  });

  group('EmbodimentIgnoredRule', () {
    test('detects visual facts when vision unavailable', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        visibleEntities: [], // Should be empty when vision unavailable
        spatialContext: const SpatialContext(),
      );

      final embodimentState = EmbodimentState(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        sensoryCapabilities: SensoryCapabilities(
          vision: const SensoryCapability(availability: 0.0, acuity: 0.0),
          hearing: const SensoryCapability(availability: 1.0, acuity: 1.0),
          smell: const SensoryCapability(availability: 1.0, acuity: 1.0),
          touch: const SensoryCapability(availability: 1.0, acuity: 1.0),
          proprioception: const SensoryCapability(availability: 1.0, acuity: 1.0),
          mana: ManaSensoryCapability.mortal,
        ),
        bodyConstraints: _createDefaultBodyConstraints(),
        salienceModifiers: const SalienceModifiers(),
        reasoningModifiers: _createDefaultReasoningModifiers(),
        actionFeasibility: _createDefaultActionFeasibility(),
      );

      final output = _createDefaultCognitiveOutput(
        noticedFacts: [
          NoticedFact(
            factId: 'fact1',
            content: 'Saw something',
            sourceType: 'visual', // Visual fact but vision unavailable
          ),
        ],
      );

      final rule = const EmbodimentIgnoredRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: [],
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.error &&
            r.message.contains('vision unavailable')),
        isTrue,
      );
    });

    test('detects mana facts when mana sense unavailable', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        manaSignals: [], // Should be empty when mana unavailable
        spatialContext: const SpatialContext(),
      );

      final embodimentState = EmbodimentState(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        sensoryCapabilities: SensoryCapabilities(
          vision: const SensoryCapability(availability: 1.0, acuity: 1.0),
          hearing: const SensoryCapability(availability: 1.0, acuity: 1.0),
          smell: const SensoryCapability(availability: 1.0, acuity: 1.0),
          touch: const SensoryCapability(availability: 1.0, acuity: 1.0),
          proprioception: const SensoryCapability(availability: 1.0, acuity: 1.0),
          mana: const ManaSensoryCapability(
            availability: 0.0,
            acuity: 0.0,
          ),
        ),
        bodyConstraints: _createDefaultBodyConstraints(),
        salienceModifiers: const SalienceModifiers(),
        reasoningModifiers: _createDefaultReasoningModifiers(),
        actionFeasibility: _createDefaultActionFeasibility(),
      );

      final output = _createDefaultCognitiveOutput(
        noticedFacts: [
          NoticedFact(
            factId: 'fact1',
            content: 'Sensed mana',
            sourceType: 'mana', // Mana fact but mana sense unavailable
          ),
        ],
      );

      final rule = const EmbodimentIgnoredRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: [],
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.error &&
            r.message.contains('mana sense unavailable')),
        isTrue,
      );
    });
  });

  group('MemoryLeakageRule', () {
    test('passes when output references only accessible memories', () {
      final filteredView = _createDefaultFilteredView();
      final embodimentState = _createDefaultEmbodiment();

      final memories = [
        MemoryEntry(
          memoryId: 'mem1',
          content: 'Test memory',
          ownerCharacterId: 'char1',
          knownBy: ['char1'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        ),
      ];

      final output = _createDefaultCognitiveOutput(
        memoryActivations: [
          MemoryActivation(
            memoryId: 'mem1',
            activationReason: 'relevant',
            relevanceScore: 0.8,
          ),
        ],
      );

      final rule = const MemoryLeakageRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: memories,
      );

      expect(results.where((r) => r.severity == ValidationSeverity.error), isEmpty);
    });

    test('detects reference to inaccessible memory', () {
      final filteredView = _createDefaultFilteredView();
      final embodimentState = _createDefaultEmbodiment();

      final memories = [
        MemoryEntry(
          memoryId: 'mem1',
          content: 'Test memory',
          ownerCharacterId: 'char1',
          knownBy: ['char1'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        ),
      ];

      final output = _createDefaultCognitiveOutput(
        memoryActivations: [
          MemoryActivation(
            memoryId: 'mem2', // Not in accessible memories
            activationReason: 'relevant',
            relevanceScore: 0.8,
          ),
        ],
      );

      final rule = const MemoryLeakageRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: output,
        accessibleMemories: memories,
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.error &&
            r.message.contains('inaccessible memory')),
        isTrue,
      );
    });

    test('detects invalid private memory structure', () {
      final filteredView = _createDefaultFilteredView();
      final embodimentState = _createDefaultEmbodiment();

      // Private memory with wrong known_by
      final memories = [
        MemoryEntry(
          memoryId: 'mem1',
          content: 'Test memory',
          ownerCharacterId: 'char1',
          knownBy: ['char1', 'char2'], // Private should only have owner
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        ),
      ];

      final rule = const MemoryLeakageRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: null,
        accessibleMemories: memories,
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.error &&
            r.message.contains('incorrect known_by')),
        isTrue,
      );
    });
  });

  group('ManaSenseValidationRule', () {
    test('detects mortal detecting high-level cultivator aura', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        manaSignals: [
          ManaSignal(
            signalId: 'mana1',
            content: 'Strong cultivator aura',
            sourceType: ManaSourceType.cultivatorAura,
            perceivedIntensity: 0.8, // High intensity
            attribute: ManaAttribute.neutral,
            clarity: 0.7,
            direction: 'north',
          ),
        ],
        spatialContext: const SpatialContext(),
      );

      // Mortal-level mana capability
      final embodimentState = EmbodimentState(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        sensoryCapabilities: SensoryCapabilities(
          vision: const SensoryCapability(availability: 1.0, acuity: 1.0),
          hearing: const SensoryCapability(availability: 1.0, acuity: 1.0),
          smell: const SensoryCapability(availability: 1.0, acuity: 1.0),
          touch: const SensoryCapability(availability: 1.0, acuity: 1.0),
          proprioception: const SensoryCapability(availability: 1.0, acuity: 1.0),
          mana: const ManaSensoryCapability(
            availability: 1.0,
            acuity: 0.3, // Mortal-level acuity
          ),
        ),
        bodyConstraints: _createDefaultBodyConstraints(),
        salienceModifiers: const SalienceModifiers(),
        reasoningModifiers: _createDefaultReasoningModifiers(),
        actionFeasibility: _createDefaultActionFeasibility(),
      );

      final rule = const ManaSenseValidationRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: null,
        accessibleMemories: [],
      );

      expect(
        results.any((r) =>
            r.severity == ValidationSeverity.warning &&
            r.message.contains('cultivator aura')),
        isTrue,
      );
    });

    test('passes when mana sense is properly constrained', () {
      final filteredView = FilteredSceneView(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        manaSignals: [
          ManaSignal(
            signalId: 'mana1',
            content: 'Weak cultivator aura',
            sourceType: ManaSourceType.cultivatorAura,
            perceivedIntensity: 0.2, // Low intensity, mortal can detect
            attribute: ManaAttribute.neutral,
            clarity: 0.3,
            direction: 'north',
          ),
        ],
        spatialContext: const SpatialContext(),
      );

      final embodimentState = EmbodimentState(
        characterId: 'char1',
        sceneTurnId: 'turn1',
        sensoryCapabilities: SensoryCapabilities(
          vision: const SensoryCapability(availability: 1.0, acuity: 1.0),
          hearing: const SensoryCapability(availability: 1.0, acuity: 1.0),
          smell: const SensoryCapability(availability: 1.0, acuity: 1.0),
          touch: const SensoryCapability(availability: 1.0, acuity: 1.0),
          proprioception: const SensoryCapability(availability: 1.0, acuity: 1.0),
          mana: const ManaSensoryCapability(
            availability: 1.0,
            acuity: 0.3,
          ),
        ),
        bodyConstraints: _createDefaultBodyConstraints(),
        salienceModifiers: const SalienceModifiers(),
        reasoningModifiers: _createDefaultReasoningModifiers(),
        actionFeasibility: _createDefaultActionFeasibility(),
      );

      final rule = const ManaSenseValidationRule();
      final results = rule.validate(
        filteredView: filteredView,
        embodimentState: embodimentState,
        output: null,
        accessibleMemories: [],
      );

      expect(results.where((r) => r.severity == ValidationSeverity.error), isEmpty);
    });
  });
}

// Helper functions to create default test fixtures
BodyConstraints _createDefaultBodyConstraints() {
  return const BodyConstraints(
    mobility: 1.0,
    balance: 1.0,
    painLoad: 0.0,
    fatigue: 0.0,
    cognitiveClarity: 1.0,
  );
}

ReasoningModifiers _createDefaultReasoningModifiers() {
  return const ReasoningModifiers(
    cognitiveClarity: 1.0,
    painBias: 0.0,
    threatBias: 0.0,
    overloadBias: 0.0,
  );
}

ActionFeasibility _createDefaultActionFeasibility() {
  return const ActionFeasibility(
    physicalExecutionCapacity: 1.0,
    socialPatience: 1.0,
    fineControl: 1.0,
    sustainedAttention: 1.0,
  );
}

EmbodimentState _createDefaultEmbodiment() {
  return EmbodimentState(
    characterId: 'char1',
    sceneTurnId: 'turn1',
    sensoryCapabilities: SensoryCapabilities(
      vision: const SensoryCapability(availability: 1.0, acuity: 1.0),
      hearing: const SensoryCapability(availability: 1.0, acuity: 1.0),
      smell: const SensoryCapability(availability: 1.0, acuity: 1.0),
      touch: const SensoryCapability(availability: 1.0, acuity: 1.0),
      proprioception: const SensoryCapability(availability: 1.0, acuity: 1.0),
      mana: ManaSensoryCapability.cultivator,
    ),
    bodyConstraints: _createDefaultBodyConstraints(),
    salienceModifiers: const SalienceModifiers(),
    reasoningModifiers: _createDefaultReasoningModifiers(),
    actionFeasibility: _createDefaultActionFeasibility(),
  );
}

FilteredSceneView _createDefaultFilteredView() {
  return FilteredSceneView(
    characterId: 'char1',
    sceneTurnId: 'turn1',
    spatialContext: const SpatialContext(),
  );
}

CharacterCognitivePassOutput _createDefaultCognitiveOutput({
  List<NoticedFact> noticedFacts = const [],
  List<MemoryActivation> memoryActivations = const [],
}) {
  return CharacterCognitivePassOutput(
    characterId: 'char1',
    sceneTurnId: 'turn1',
    perceptionDelta: PerceptionDelta(
      noticedFacts: noticedFacts,
      memoryActivations: memoryActivations,
    ),
    beliefUpdate: BeliefUpdate(
      emotionalShift: const EmotionalShift(
        emotion: 'neutral',
        oldIntensity: 0.5,
        newIntensity: 0.5,
        trigger: 'test',
      ),
    ),
    intentPlan: IntentPlan(
      activeGoals: const CurrentGoals(),
      decisionFrame: const DecisionFrame(
        context: 'test',
        constraints: 'none',
        timePressure: 0.0,
      ),
      selectedIntent: SelectedIntent(intent: 'test', reason: 'test'),
      expressionConstraints: const ExpressionConstraints(
        revealLevel: RevealLevel.direct,
      ),
    ),
  );
}
