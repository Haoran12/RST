import '../../models/agent/character_runtime_state.dart';
import '../../models/agent/cognitive_pass_io.dart';

/// Request for emotion update.
class EmotionUpdateRequest {
  const EmotionUpdateRequest({
    required this.characterId,
    required this.currentEmotionState,
    required this.emotionalShift,
    required this.affectiveColoring,
    required this.currentGoals,
  });

  final String characterId;
  final EmotionState currentEmotionState;
  final EmotionalShift emotionalShift;
  final List<AffectiveColoring> affectiveColoring;
  final CurrentGoals currentGoals;
}

/// Result of emotion update.
class EmotionUpdateResult {
  const EmotionUpdateResult({
    required this.newEmotionState,
    required this.changes,
    required this.dominantEmotion,
  });

  final EmotionState newEmotionState;
  final List<EmotionChangeRecord> changes;
  final String? dominantEmotion;
}

/// Record of a single emotion change.
class EmotionChangeRecord {
  const EmotionChangeRecord({
    required this.emotion,
    required this.oldIntensity,
    required this.newIntensity,
    required this.trigger,
  });

  final String emotion;
  final double oldIntensity;
  final double newIntensity;
  final String trigger;

  @override
  String toString() => 'EmotionChangeRecord($emotion: $oldIntensity -> $newIntensity)';
}

/// Updates character emotion state based on cognitive pass output.
///
/// This service handles:
/// - Processing emotional shifts from cognitive pass
/// - Applying affective coloring from perception
/// - Emotion decay over time
/// - Goal-related emotion modulation
/// - Dominant emotion detection
class EmotionUpdater {
  const EmotionUpdater({
    this.minIntensity = 0.0,
    this.maxIntensity = 1.0,
    this.decayRate = 0.1,
    this.defaultDecayThreshold = 0.05,
  });

  final double minIntensity;
  final double maxIntensity;
  final double decayRate;
  final double defaultDecayThreshold;

  /// Apply emotion update to character state.
  EmotionUpdateResult update(EmotionUpdateRequest request) {
    final changes = <EmotionChangeRecord>[];
    final newEmotions = Map<String, double>.from(request.currentEmotionState.emotions);

    // 1. Process primary emotional shift
    final shift = request.emotionalShift;
    final oldIntensity = newEmotions[shift.emotion] ?? 0.0;
    final newIntensity = _clampIntensity(shift.newIntensity);

    newEmotions[shift.emotion] = newIntensity;

    changes.add(EmotionChangeRecord(
      emotion: shift.emotion,
      oldIntensity: oldIntensity,
      newIntensity: newIntensity,
      trigger: shift.trigger,
    ));

    // 2. Apply affective coloring (secondary emotions from perception)
    for (final coloring in request.affectiveColoring) {
      final currentIntensity = newEmotions[coloring.emotion] ?? 0.0;
      // Affective coloring has less impact than primary shift
      final blendedIntensity = _blendEmotions(currentIntensity, coloring.intensity * 0.5);
      newEmotions[coloring.emotion] = blendedIntensity;

      if ((blendedIntensity - currentIntensity).abs() > 0.01) {
        changes.add(EmotionChangeRecord(
          emotion: coloring.emotion,
          oldIntensity: currentIntensity,
          newIntensity: blendedIntensity,
          trigger: 'perception: ${coloring.targetId}',
        ));
      }
    }

    // 3. Apply emotion decay to non-active emotions
    _applyDecay(newEmotions, shift.emotion);

    // 4. Remove emotions below threshold
    newEmotions.removeWhere((key, value) => value < defaultDecayThreshold);

    // 5. Modulate based on current goals
    _modulateForGoals(newEmotions, request.currentGoals);

    final newEmotionState = EmotionState(emotions: newEmotions);
    final dominant = _findDominantEmotion(newEmotions);

    return EmotionUpdateResult(
      newEmotionState: newEmotionState,
      changes: changes,
      dominantEmotion: dominant,
    );
  }

  /// Apply time-based decay to emotions.
  EmotionState applyDecay(EmotionState state, {int turnsPassed = 1}) {
    final newEmotions = Map<String, double>.from(state.emotions);
    _applyDecay(newEmotions, null, turns: turnsPassed);
    newEmotions.removeWhere((key, value) => value < defaultDecayThreshold);
    return EmotionState(emotions: newEmotions);
  }

  /// Blend two emotion intensities.
  double _blendEmotions(double current, double incoming) {
    // Weighted blend favoring stronger emotion
    if (current > incoming) {
      return current + (incoming * (1 - current) * 0.5);
    } else {
      return incoming + (current * (1 - incoming) * 0.5);
    }
  }

  /// Apply decay to emotions over time.
  void _applyDecay(Map<String, double> emotions, String? activeEmotion, {int turns = 1}) {
    final decayFactor = 1.0 - (decayRate * turns);

    for (final key in emotions.keys) {
      // Active emotion decays slower
      if (key == activeEmotion) {
        emotions[key] = emotions[key]! * (decayFactor + 0.1);
      } else {
        emotions[key] = emotions[key]! * decayFactor;
      }
    }
  }

  /// Modulate emotions based on current goals.
  void _modulateForGoals(Map<String, double> emotions, CurrentGoals goals) {
    // Goals can amplify or suppress certain emotions
    for (final goal in goals.shortTerm) {
      _applyGoalModulation(emotions, goal, 1.0);
    }
    for (final goal in goals.mediumTerm) {
      _applyGoalModulation(emotions, goal, 0.5);
    }
    for (final goal in goals.hidden) {
      _applyGoalModulation(emotions, goal, 0.7);
    }
  }

  /// Apply modulation for a single goal.
  void _applyGoalModulation(Map<String, double> emotions, String goal, double factor) {
    final goalLower = goal.toLowerCase();

    // Threat-related goals increase fear and alertness
    if (goalLower.contains('逃避') || goalLower.contains('躲避') || goalLower.contains('生存')) {
      final fear = emotions['fear'] ?? 0.0;
      emotions['fear'] = _clampIntensity(fear + 0.1 * factor);
    }

    // Combat-related goals increase anger and determination
    if (goalLower.contains('战斗') || goalLower.contains('击败') || goalLower.contains('保护')) {
      final anger = emotions['anger'] ?? 0.0;
      emotions['anger'] = _clampIntensity(anger + 0.1 * factor);
    }

    // Social goals can increase anticipation
    if (goalLower.contains('说服') || goalLower.contains('谈判') || goalLower.contains('合作')) {
      final anticipation = emotions['anticipation'] ?? 0.0;
      emotions['anticipation'] = _clampIntensity(anticipation + 0.1 * factor);
    }

    // Revenge-related goals increase anger
    if (goalLower.contains('复仇') || goalLower.contains('报复')) {
      final anger = emotions['anger'] ?? 0.0;
      emotions['anger'] = _clampIntensity(anger + 0.2 * factor);
    }
  }

  /// Find the dominant emotion in the state.
  String? _findDominantEmotion(Map<String, double> emotions) {
    if (emotions.isEmpty) return null;

    String? dominant;
    double maxVal = 0.0;

    emotions.forEach((key, value) {
      if (value > maxVal) {
        maxVal = value;
        dominant = key;
      }
    });

    return dominant;
  }

  /// Check if an emotion is intense enough to affect behavior.
  bool isIntenseEnough(double intensity) {
    return intensity > 0.3;
  }

  /// Get emotion category for a specific emotion.
  EmotionCategory getCategory(String emotion) {
    return switch (emotion.toLowerCase()) {
      'joy' || 'happiness' || 'delight' || 'elation' => EmotionCategory.positive,
      'sadness' || 'grief' || 'melancholy' || 'sorrow' => EmotionCategory.negative,
      'anger' || 'rage' || 'fury' || 'irritation' => EmotionCategory.aggressive,
      'fear' || 'anxiety' || 'terror' || 'dread' => EmotionCategory.defensive,
      'surprise' || 'shock' || 'amazement' => EmotionCategory.reactive,
      'disgust' || 'revulsion' || 'contempt' => EmotionCategory.rejecting,
      'trust' || 'confidence' || 'faith' => EmotionCategory.connective,
      'anticipation' || 'expectation' || 'hope' => EmotionCategory.motivating,
      _ => EmotionCategory.neutral,
    };
  }

  double _clampIntensity(double value) {
    return value.clamp(minIntensity, maxIntensity);
  }
}

/// Categories of emotions for behavioral analysis.
enum EmotionCategory {
  positive,    // Joy, happiness
  negative,    // Sadness, grief
  aggressive,  // Anger, rage
  defensive,   // Fear, anxiety
  reactive,    // Surprise, shock
  rejecting,   // Disgust, contempt
  connective,  // Trust, confidence
  motivating,  // Anticipation, hope
  neutral,     // Default
}
