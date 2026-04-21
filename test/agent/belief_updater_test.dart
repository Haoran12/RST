import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/services/agent/belief_updater.dart';

void main() {
  group('BeliefUpdater', () {
    const updater = BeliefUpdater();

    group('update', () {
      test('reinforces existing beliefs', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(
            beliefConfidences: {'trust_alice': 0.5},
          ),
          beliefUpdate: BeliefUpdate(
            stableBeliefsReinforced: [
              const BeliefReinforced(
                beliefId: 'trust_alice',
                evidence: 'Alice helped in crisis',
                newConfidence: 0.8,
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.beliefConfidences['trust_alice'], greaterThan(0.5));
        expect(result.changes.length, equals(1));
        expect(result.changes.first.type, equals(BeliefChangeType.reinforced));
      });

      test('weakens existing beliefs', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(
            beliefConfidences: {'trust_bob': 0.7},
          ),
          beliefUpdate: BeliefUpdate(
            stableBeliefsWeakened: [
              const BeliefWeakened(
                beliefId: 'trust_bob',
                counterEvidence: 'Bob lied about his identity',
                newConfidence: 0.3,
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'suspicion',
              oldIntensity: 0.3,
              newIntensity: 0.6,
              trigger: 'deception detected',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.beliefConfidences['trust_bob'], lessThan(0.7));
        expect(result.changes.first.type, equals(BeliefChangeType.weakened));
      });

      test('adds new hypotheses', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(),
          beliefUpdate: BeliefUpdate(
            newHypotheses: [
              const NewHypothesis(
                hypothesisId: 'hypo_enemy_spy',
                content: 'The stranger might be an enemy spy',
                prior: 0.4,
                basis: 'Suspicious behavior patterns',
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.activeHypotheses, contains('hypo_enemy_spy'));
        expect(result.newBeliefState.beliefConfidences['hypo_enemy_spy'], equals(0.4));
        expect(result.changes.any((c) => c.type == BeliefChangeType.hypothesisAdded), isTrue);
      });

      test('promotes high-confidence hypothesis to current', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(),
          beliefUpdate: BeliefUpdate(
            newHypotheses: [
              const NewHypothesis(
                hypothesisId: 'hypo_trusted_ally',
                content: 'The stranger is a trusted ally',
                prior: 0.85,
                basis: 'Multiple confirmations',
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.currentHypothesis, equals('hypo_trusted_ally'));
        expect(result.changes.any((c) => c.type == BeliefChangeType.hypothesisPromoted), isTrue);
      });

      test('discards low-confidence hypotheses', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(
            beliefConfidences: {'hypo_old': 0.15},
            activeHypotheses: ['hypo_old'],
          ),
          beliefUpdate: const BeliefUpdate(
            emotionalShift: EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.activeHypotheses, isNot(contains('hypo_old')));
        expect(result.changes.any((c) => c.type == BeliefChangeType.hypothesisDiscarded), isTrue);
      });

      test('updates relation models', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(),
          beliefUpdate: BeliefUpdate(
            revisedModelsOfOthers: [
              const RevisedModelOfOther(
                targetCharacterId: 'char_alice',
                aspect: 'trust',
                oldValue: '0.5',
                newValue: '0.8',
                reason: 'Alice proved reliable',
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.updatedRelationModels['char_alice'], isNotNull);
        expect(result.updatedRelationModels['char_alice']['trust'], equals('0.8'));
        expect(result.changes.any((c) => c.type == BeliefChangeType.relationUpdated), isTrue);
      });

      test('removes beliefs below minimum confidence', () {
        final request = BeliefUpdateRequest(
          characterId: 'test_char',
          currentBeliefState: const BeliefState(
            beliefConfidences: {'old_belief': 0.5},
          ),
          beliefUpdate: BeliefUpdate(
            stableBeliefsWeakened: [
              const BeliefWeakened(
                beliefId: 'old_belief',
                counterEvidence: 'Completely disproven',
                newConfidence: 0.05,
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          currentRelationModels: {},
        );

        final result = updater.update(request);

        expect(result.newBeliefState.beliefConfidences.containsKey('old_belief'), isFalse);
      });
    });

    group('detectContradictions', () {
      test('detects mutually exclusive beliefs', () {
        const state = BeliefState(
          beliefConfidences: {
            'alive': 0.8,
            'dead': 0.7,
          },
        );

        final contradictions = updater.detectContradictions(state);

        expect(contradictions.length, equals(1));
        expect(contradictions.first.belief1, equals('alive'));
        expect(contradictions.first.belief2, equals('dead'));
      });

      test('does not flag low-confidence contradictions', () {
        const state = BeliefState(
          beliefConfidences: {
            'alive': 0.8,
            'dead': 0.3,
          },
        );

        final contradictions = updater.detectContradictions(state);

        expect(contradictions.isEmpty, isTrue);
      });

      test('returns empty for non-contradictory beliefs', () {
        const state = BeliefState(
          beliefConfidences: {
            'friendly': 0.7,
            'helpful': 0.8,
          },
        );

        final contradictions = updater.detectContradictions(state);

        expect(contradictions.isEmpty, isTrue);
      });
    });

    group('mergeUpdates', () {
      test('merges multiple updates sequentially', () {
        const baseState = BeliefState(
          beliefConfidences: {'initial': 0.5},
        );

        final updates = [
          BeliefUpdate(
            stableBeliefsReinforced: [
              const BeliefReinforced(
                beliefId: 'initial',
                evidence: 'First update',
                newConfidence: 0.7,
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
          BeliefUpdate(
            stableBeliefsReinforced: [
              const BeliefReinforced(
                beliefId: 'initial',
                evidence: 'Second update',
                newConfidence: 0.9,
              ),
            ],
            emotionalShift: const EmotionalShift(
              emotion: 'neutral',
              oldIntensity: 0.5,
              newIntensity: 0.5,
              trigger: 'none',
            ),
          ),
        ];

        final result = updater.mergeUpdates(baseState: baseState, updates: updates);

        expect(result.beliefConfidences['initial'], greaterThan(0.7));
      });
    });
  });
}
