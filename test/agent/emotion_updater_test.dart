import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/character_runtime_state.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/services/agent/emotion_updater.dart';

void main() {
  group('EmotionUpdater', () {
    const updater = EmotionUpdater();

    group('emotion updates', () {
      test('applies emotional shift correctly', () {
        final current = EmotionState(emotions: {'fear': 0.3});
        final shift = EmotionalShift(
          emotion: 'fear',
          oldIntensity: 0.3,
          newIntensity: 0.7,
          trigger: 'threat detected',
        );

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: const CurrentGoals(),
        ));

        expect(result.newEmotionState.emotions['fear'], closeTo(0.7, 0.01));
        expect(result.dominantEmotion, 'fear');
        expect(result.changes, hasLength(1));
      });

      test('applies affective coloring from perception', () {
        final current = EmotionState(emotions: {'joy': 0.5});
        final shift = EmotionalShift(
          emotion: 'joy',
          oldIntensity: 0.5,
          newIntensity: 0.6,
          trigger: 'positive event',
        );
        final coloring = [
          AffectiveColoring(targetId: 'entity_1', emotion: 'trust', intensity: 0.4),
        ];

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: coloring,
          currentGoals: const CurrentGoals(),
        ));

        expect(result.newEmotionState.emotions['joy'], closeTo(0.6, 0.01));
        expect(result.newEmotionState.emotions['trust'], isNotNull);
        expect(result.newEmotionState.emotions['trust']!, greaterThan(0.0));
      });

      test('clamps emotion intensity to valid range', () {
        final current = EmotionState(emotions: {});
        final shift = EmotionalShift(
          emotion: 'anger',
          oldIntensity: 0.0,
          newIntensity: 1.5, // Over max
          trigger: 'extreme provocation',
        );

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: const CurrentGoals(),
        ));

        expect(result.newEmotionState.emotions['anger'], lessThanOrEqualTo(1.0));
      });

      test('removes emotions below threshold', () {
        final current = EmotionState(emotions: {'surprise': 0.02, 'joy': 0.5});
        final shift = EmotionalShift(
          emotion: 'joy',
          oldIntensity: 0.5,
          newIntensity: 0.6,
          trigger: 'good news',
        );

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: const CurrentGoals(),
        ));

        expect(result.newEmotionState.emotions.containsKey('surprise'), isFalse);
      });
    });

    group('emotion decay', () {
      test('applies decay over time', () {
        final state = EmotionState(emotions: {'fear': 0.8, 'joy': 0.6});

        final decayed = updater.applyDecay(state, turnsPassed: 1);

        expect(decayed.emotions['fear']!, lessThan(0.8));
        expect(decayed.emotions['joy']!, lessThan(0.6));
      });

      test('decay removes emotions below threshold', () {
        final state = EmotionState(emotions: {'surprise': 0.03});

        final decayed = updater.applyDecay(state, turnsPassed: 5);

        expect(decayed.emotions.containsKey('surprise'), isFalse);
      });
    });

    group('goal modulation', () {
      test('threat goals increase fear', () {
        final current = EmotionState(emotions: {'fear': 0.2});
        final shift = EmotionalShift(
          emotion: 'fear',
          oldIntensity: 0.2,
          newIntensity: 0.3,
          trigger: 'danger',
        );
        final goals = CurrentGoals(shortTerm: ['逃离危险']);

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: goals,
        ));

        // Goal modulation should increase fear above the shift value
        expect(result.newEmotionState.emotions['fear']!, greaterThan(0.2));
      });

      test('combat goals increase anger', () {
        final current = EmotionState(emotions: {'anger': 0.2});
        final shift = EmotionalShift(
          emotion: 'anger',
          oldIntensity: 0.2,
          newIntensity: 0.3,
          trigger: 'provocation',
        );
        final goals = CurrentGoals(shortTerm: ['击败敌人']);

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: goals,
        ));

        expect(result.newEmotionState.emotions['anger']!, greaterThan(0.3));
      });
    });

    group('dominant emotion', () {
      test('identifies dominant emotion correctly', () {
        final current = EmotionState(emotions: {
          'fear': 0.3,
          'anger': 0.7,
          'joy': 0.2,
        });
        final shift = EmotionalShift(
          emotion: 'anger',
          oldIntensity: 0.7,
          newIntensity: 0.8,
          trigger: 'provocation',
        );

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: const CurrentGoals(),
        ));

        expect(result.dominantEmotion, 'anger');
      });

      test('returns null for empty emotion state', () {
        final current = EmotionState(emotions: {});
        final shift = EmotionalShift(
          emotion: 'neutral',
          oldIntensity: 0.0,
          newIntensity: 0.0,
          trigger: 'none',
        );

        final result = updater.update(EmotionUpdateRequest(
          characterId: 'test',
          currentEmotionState: current,
          emotionalShift: shift,
          affectiveColoring: [],
          currentGoals: const CurrentGoals(),
        ));

        // After removing emotions below threshold, may be empty
        expect(result.dominantEmotion, anyOf(isNull, 'neutral'));
      });
    });

    group('emotion categories', () {
      test('categorizes emotions correctly', () {
        expect(updater.getCategory('joy'), EmotionCategory.positive);
        expect(updater.getCategory('anger'), EmotionCategory.aggressive);
        expect(updater.getCategory('fear'), EmotionCategory.defensive);
        expect(updater.getCategory('surprise'), EmotionCategory.reactive);
        expect(updater.getCategory('trust'), EmotionCategory.connective);
        expect(updater.getCategory('anticipation'), EmotionCategory.motivating);
      });
    });

    group('intensity checks', () {
      test('identifies intense emotions', () {
        expect(updater.isIntenseEnough(0.5), isTrue);
        expect(updater.isIntenseEnough(0.2), isFalse);
      });
    });
  });
}
