import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/embodiment_state.dart';
import 'package:rst/core/models/agent/mana_field.dart';
import 'package:rst/core/models/agent/scene_model.dart';
import 'package:rst/core/services/agent/scene_filtering_protocol.dart';

void main() {
  group('SceneFilteringProtocol', () {
    const protocol = SceneFilteringProtocol();

    group('visible entities', () {
      test('blind character sees no entities', () {
        final request = _createFilterRequest(
          scene: _sceneWithEntities,
          embodiment: _blindEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.visibleEntities, isEmpty);
      });

      test('character with normal vision sees entities', () {
        final request = _createFilterRequest(
          scene: _sceneWithEntities,
          embodiment: _normalVisionEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.visibleEntities, isNotEmpty);
      });

      test('dim lighting reduces visibility', () {
        final request = _createFilterRequest(
          scene: _dimlyLitScene,
          embodiment: _normalVisionEmbodiment,
        );

        final result = protocol.filter(request);

        // Entities should have lower visibility scores
        for (final entity in result.visibleEntities) {
          expect(entity.visibilityScore, lessThan(0.7));
        }
      });

      test('entities are sorted by visibility score', () {
        final request = _createFilterRequest(
          scene: _sceneWithMultipleEntities,
          embodiment: _normalVisionEmbodiment,
        );

        final result = protocol.filter(request);

        for (int i = 0; i < result.visibleEntities.length - 1; i++) {
          expect(
            result.visibleEntities[i].visibilityScore,
            greaterThanOrEqualTo(result.visibleEntities[i + 1].visibilityScore),
          );
        }
      });
    });

    group('audible signals', () {
      test('deaf character hears no signals', () {
        final request = _createFilterRequest(
          scene: _sceneWithSounds,
          embodiment: _deafEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.audibleSignals, isEmpty);
      });

      test('character with normal hearing hears signals', () {
        final request = _createFilterRequest(
          scene: _sceneWithSounds,
          embodiment: _normalHearingEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.audibleSignals, isNotEmpty);
      });

      test('high ambient noise reduces audibility', () {
        final request = _createFilterRequest(
          scene: _noisyScene,
          embodiment: _normalHearingEmbodiment,
        );

        final result = protocol.filter(request);

        // Signals should have lower audibility scores
        for (final signal in result.audibleSignals) {
          expect(signal.audibilityScore, lessThan(0.9));
        }
      });
    });

    group('olfactory signals', () {
      test('character with blocked smell detects no odors', () {
        final request = _createFilterRequest(
          scene: _sceneWithOdors,
          embodiment: _noSmellEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.olfactorySignals, isEmpty);
      });

      test('character with enhanced smell detects more odors', () {
        final enhancedSmellRequest = _createFilterRequest(
          scene: _sceneWithOdors,
          embodiment: _enhancedSmellEmbodiment,
        );

        final normalSmellRequest = _createFilterRequest(
          scene: _sceneWithOdors,
          embodiment: _normalSmellEmbodiment,
        );

        final enhancedResult = protocol.filter(enhancedSmellRequest);
        final normalResult = protocol.filter(normalSmellRequest);

        // Enhanced smell should detect equal or more odors
        expect(enhancedResult.olfactorySignals.length, greaterThanOrEqualTo(normalResult.olfactorySignals.length));
      });

      test('fresh odors are stronger than old ones', () {
        final request = _createFilterRequest(
          scene: _sceneWithMixedOdors,
          embodiment: _normalSmellEmbodiment,
        );

        final result = protocol.filter(request);

        // Find fresh and old odor signals
        final freshOdor = result.olfactorySignals.where((s) => s.freshness == '新鲜').firstOrNull;
        final oldOdor = result.olfactorySignals.where((s) => s.freshness == '陈旧').firstOrNull;

        if (freshOdor != null && oldOdor != null) {
          expect(freshOdor.intensity, greaterThan(oldOdor.intensity));
        }
      });
    });

    group('mana signals', () {
      test('mortal cannot detect cultivator aura', () {
        final request = _createFilterRequest(
          scene: _sceneWithCultivatorAura,
          embodiment: _mortalManaEmbodiment,
        );

        final result = protocol.filter(request);

        // Mortal should not detect cultivator aura
        expect(
          result.manaSignals.where((s) => s.sourceType == ManaSourceType.cultivatorAura),
          isEmpty,
        );
      });

      test('cultivator can detect cultivator aura', () {
        final request = _createFilterRequest(
          scene: _sceneWithCultivatorAura,
          embodiment: _cultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        expect(
          result.manaSignals.where((s) => s.sourceType == ManaSourceType.cultivatorAura),
          isNotEmpty,
        );
      });

      test('mana sensing blocked disables all mana signals', () {
        final request = _createFilterRequest(
          scene: _sceneWithCultivatorAura,
          embodiment: _manaBlockedEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.manaSignals, isEmpty);
      });

      test('mana interference reduces perceived intensity', () {
        final noInterferenceRequest = _createFilterRequest(
          scene: _sceneWithManaNoInterference,
          embodiment: _cultivatorManaEmbodiment,
        );

        final withInterferenceRequest = _createFilterRequest(
          scene: _sceneWithManaInterference,
          embodiment: _cultivatorManaEmbodiment,
        );

        final noInterferenceResult = protocol.filter(noInterferenceRequest);
        final withInterferenceResult = protocol.filter(withInterferenceRequest);

        // Interference should reduce perceived intensity
        if (noInterferenceResult.manaSignals.isNotEmpty && withInterferenceResult.manaSignals.isNotEmpty) {
          expect(
            noInterferenceResult.manaSignals.first.perceivedIntensity,
            greaterThan(withInterferenceResult.manaSignals.first.perceivedIntensity),
          );
        }
      });

      test('mana signals include insight for high clarity', () {
        final request = _createFilterRequest(
          scene: _sceneWithStrongCultivatorAura,
          embodiment: _sensitiveCultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        for (final signal in result.manaSignals) {
          if (signal.clarity > 0.5) {
            expect(signal.insight, isNotNull);
          }
        }
      });

      test('corruption aura is marked as hostile', () {
        final request = _createFilterRequest(
          scene: _sceneWithCorruptionAura,
          embodiment: _cultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        final corruptionSignal = result.manaSignals
            .where((s) => s.sourceType == ManaSourceType.corruption)
            .firstOrNull;

        if (corruptionSignal != null && corruptionSignal.insight != null) {
          expect(corruptionSignal.insight!.isHostile, isTrue);
        }
      });
    });

    group('mana environment', () {
      test('mortal senses limited mana environment', () {
        final request = _createFilterRequest(
          scene: _sceneWithManaField,
          embodiment: _mortalManaEmbodiment,
        );

        final result = protocol.filter(request);

        // Mortal has limited mana sensing
        expect(result.manaEnvironment.perceivedDensity, lessThan(0.5));
      });

      test('cultivator senses mana environment', () {
        final request = _createFilterRequest(
          scene: _sceneWithManaField,
          embodiment: _cultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.manaEnvironment.perceivedDensity, greaterThan(0.0));
      });

      test('corrupt mana field is not suitable for cultivation', () {
        final request = _createFilterRequest(
          scene: _sceneWithCorruptManaField,
          embodiment: _cultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.manaEnvironment.suitableForCultivation, isFalse);
      });

      test('anomaly is detected in corrupt field', () {
        final request = _createFilterRequest(
          scene: _sceneWithCorruptManaField,
          embodiment: _cultivatorManaEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.manaEnvironment.hasAnomaly, isTrue);
        expect(result.manaEnvironment.anomalyDescription, isNotEmpty);
      });
    });

    group('spatial context', () {
      test('immobile character has limited reachable areas', () {
        final request = _createFilterRequest(
          scene: _sceneWithSubareas,
          embodiment: _immobileEmbodiment,
        );

        final result = protocol.filter(request);

        // Only entry points should be reachable, not subareas
        expect(result.spatialContext.reachableAreas.length, lessThanOrEqualTo(2));
      });

      test('mobile character can reach all areas', () {
        final request = _createFilterRequest(
          scene: _sceneWithSubareas,
          embodiment: _mobileEmbodiment,
        );

        final result = protocol.filter(request);

        expect(result.spatialContext.reachableAreas.length, greaterThan(2));
      });

      test('nearby obstacles are listed', () {
        final request = _createFilterRequest(
          scene: _sceneWithObstacles,
          embodiment: _normalVisionEmbodiment,
          characterLocation: '0,0',
        );

        final result = protocol.filter(request);

        expect(result.spatialContext.nearbyObstacles, isNotEmpty);
      });
    });
  });
}

// === Test fixtures ===

SceneFilterRequest _createFilterRequest({
  required SceneModel scene,
  required EmbodimentState embodiment,
  String? characterLocation,
}) {
  return SceneFilterRequest(
    characterId: 'test_character',
    sceneTurnId: 'turn_001',
    scene: scene,
    embodiment: embodiment,
    characterLocation: characterLocation,
  );
}

// === Embodiment fixtures ===

final _blindEmbodiment = EmbodimentState(
  characterId: 'blind',
  sceneTurnId: 'turn_001',
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 0.0, acuity: 0.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
  bodyConstraints: const BodyConstraints(mobility: 1.0, balance: 1.0, painLoad: 0.0, fatigue: 0.0, cognitiveClarity: 1.0),
  salienceModifiers: const SalienceModifiers(),
  reasoningModifiers: const ReasoningModifiers(cognitiveClarity: 1.0, painBias: 0.0, threatBias: 0.0, overloadBias: 0.0),
  actionFeasibility: const ActionFeasibility(physicalExecutionCapacity: 1.0, socialPatience: 1.0, fineControl: 1.0, sustainedAttention: 1.0),
);

final _normalVisionEmbodiment = EmbodimentState(
  characterId: 'normal_vision',
  sceneTurnId: 'turn_001',
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
  bodyConstraints: const BodyConstraints(mobility: 1.0, balance: 1.0, painLoad: 0.0, fatigue: 0.0, cognitiveClarity: 1.0),
  salienceModifiers: const SalienceModifiers(),
  reasoningModifiers: const ReasoningModifiers(cognitiveClarity: 1.0, painBias: 0.0, threatBias: 0.0, overloadBias: 0.0),
  actionFeasibility: const ActionFeasibility(physicalExecutionCapacity: 1.0, socialPatience: 1.0, fineControl: 1.0, sustainedAttention: 1.0),
);

final _deafEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 0.0, acuity: 0.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
);

final _normalHearingEmbodiment = _normalVisionEmbodiment;

final _noSmellEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 0.0, acuity: 0.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
);

final _normalSmellEmbodiment = _normalVisionEmbodiment;

final _enhancedSmellEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.5),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
);

final _mortalManaEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.mortal,
  ),
);

final _cultivatorManaEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.cultivator,
  ),
);

final _sensitiveCultivatorManaEmbodiment = _normalVisionEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability.sensitive,
  ),
);

final _manaBlockedEmbodiment = _cultivatorManaEmbodiment.copyWith(
  sensoryCapabilities: const SensoryCapabilities(
    vision: SensoryCapability(availability: 1.0, acuity: 1.0),
    hearing: SensoryCapability(availability: 1.0, acuity: 1.0),
    smell: SensoryCapability(availability: 1.0, acuity: 1.0),
    touch: SensoryCapability(availability: 1.0, acuity: 1.0),
    proprioception: SensoryCapability(availability: 1.0, acuity: 1.0),
    mana: ManaSensoryCapability(availability: 0.0, acuity: 1.0),
  ),
);

final _immobileEmbodiment = _normalVisionEmbodiment.copyWith(
  bodyConstraints: const BodyConstraints(mobility: 0.1, balance: 1.0, painLoad: 0.0, fatigue: 0.0, cognitiveClarity: 1.0),
);

final _mobileEmbodiment = _normalVisionEmbodiment;

// === Scene fixtures ===

final _sceneWithEntities = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'noon', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  entities: const [
    SceneEntity(entityId: 'entity_001', type: 'person', location: '5,5', state: 'standing'),
  ],
);

final _sceneWithMultipleEntities = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'noon', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '20x20'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  entities: const [
    SceneEntity(entityId: 'entity_001', type: 'person', location: '2,2', state: 'standing'),
    SceneEntity(entityId: 'entity_002', type: 'person', location: '10,10', state: 'standing'),
    SceneEntity(entityId: 'entity_003', type: 'person', location: '18,18', state: 'standing'),
  ],
);

final _dimlyLitScene = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'night', weather: 'clear', visibilityCondition: 'poor'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.cave, dimensionsEstimate: '20x15'),
  lighting: const LightingState(overallLevel: LightingLevel.veryDim),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.2, reflectiveQuality: ReflectiveQuality.echoing),
  olfactoryField: OlfactoryField(
    overallDensity: 0.5,
    airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
  ),
  entities: const [
    SceneEntity(entityId: 'entity_001', type: 'person', location: '5,5', state: 'standing'),
  ],
);

final _sceneWithSounds = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  observableSignals: const [
    ObservableSignal(signalId: 'sound_001', type: 'speech', content: 'Hello', location: '5,5', intensity: 0.8),
  ],
);

final _noisyScene = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.street, dimensionsEstimate: '100x20'),
  lighting: const LightingState(overallLevel: LightingLevel.bright),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.9, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.6,
    airflow: const Airflow(strength: AirflowStrength.flowing, direction: 'east'),
  ),
  observableSignals: const [
    ObservableSignal(signalId: 'sound_001', type: 'speech', content: 'Hello', location: '5,5', intensity: 0.8),
  ],
);

final _sceneWithOdors = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.5,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
    odorSources: const [
      OdorSource(id: 'odor_001', type: OdorType.blood, intensity: 0.8, freshness: OdorFreshness.fresh, spreadRange: 3.0, sourcePosition: '5,5'),
    ],
  ),
);

final _sceneWithMixedOdors = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.5,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
    odorSources: const [
      OdorSource(id: 'odor_001', type: OdorType.blood, intensity: 0.8, freshness: OdorFreshness.fresh, spreadRange: 3.0, sourcePosition: '5,5'),
      OdorSource(id: 'odor_002', type: OdorType.incense, intensity: 0.6, freshness: OdorFreshness.old, spreadRange: 5.0, sourcePosition: '8,8'),
    ],
  ),
);

final _sceneWithCultivatorAura = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  manaField: const ManaField(
    ambientDensity: 0.5,
    ambientAttribute: ManaAttribute.neutral,
    manaSources: [
      ManaSource(
        sourceId: 'aura_001',
        type: ManaSourceType.cultivatorAura,
        intensity: 0.8,
        attribute: ManaAttribute.fire,
        location: '5,5',
        spreadRadius: 3.0,
        stability: 0.9,
        freshness: ManaFreshness.active,
      ),
    ],
  ),
);

final _sceneWithStrongCultivatorAura = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  manaField: const ManaField(
    ambientDensity: 0.5,
    ambientAttribute: ManaAttribute.neutral,
    manaSources: [
      ManaSource(
        sourceId: 'aura_001',
        type: ManaSourceType.cultivatorAura,
        intensity: 1.5,
        attribute: ManaAttribute.fire,
        location: '5,5',
        spreadRadius: 5.0,
        stability: 1.0,
        freshness: ManaFreshness.active,
      ),
    ],
  ),
);

final _sceneWithCorruptionAura = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.cave, dimensionsEstimate: '20x20'),
  lighting: const LightingState(overallLevel: LightingLevel.dim),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.2, reflectiveQuality: ReflectiveQuality.enclosed),
  olfactoryField: OlfactoryField(
    overallDensity: 0.4,
    airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
  ),
  manaField: const ManaField(
    ambientDensity: 0.8,
    ambientAttribute: ManaAttribute.corrupt,
    manaSources: [
      ManaSource(
        sourceId: 'corruption_001',
        type: ManaSourceType.corruption,
        intensity: 1.0,
        attribute: ManaAttribute.corrupt,
        location: '10,10',
        spreadRadius: 5.0,
        stability: 0.8,
        freshness: ManaFreshness.active,
      ),
    ],
  ),
);

final _sceneWithManaNoInterference = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  manaField: const ManaField(
    ambientDensity: 0.5,
    ambientAttribute: ManaAttribute.neutral,
    manaSources: [
      ManaSource(
        sourceId: 'aura_001',
        type: ManaSourceType.cultivatorAura,
        intensity: 1.0,
        attribute: ManaAttribute.fire,
        location: '5,5',
        spreadRadius: 3.0,
        stability: 0.9,
        freshness: ManaFreshness.active,
      ),
    ],
  ),
);

final _sceneWithManaInterference = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.room, dimensionsEstimate: '10x10'),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
  manaField: const ManaField(
    ambientDensity: 0.5,
    ambientAttribute: ManaAttribute.neutral,
    manaSources: [
      ManaSource(
        sourceId: 'aura_001',
        type: ManaSourceType.cultivatorAura,
        intensity: 1.0,
        attribute: ManaAttribute.fire,
        location: '5,5',
        spreadRadius: 3.0,
        stability: 0.9,
        freshness: ManaFreshness.active,
      ),
    ],
    interferences: [
      ManaInterference(
        interferenceId: 'shield_001',
        type: InterferenceType.shielding,
        strength: 0.8,
        affectedArea: '3,3',
      ),
    ],
  ),
);

final _sceneWithManaField = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.cave, dimensionsEstimate: '30x30'),
  lighting: const LightingState(overallLevel: LightingLevel.dim),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.2, reflectiveQuality: ReflectiveQuality.enclosed),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
  ),
  manaField: const ManaField(
    ambientDensity: 0.8,
    ambientAttribute: ManaAttribute.wood,
  ),
);

final _sceneWithCorruptManaField = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.cave, dimensionsEstimate: '30x30'),
  lighting: const LightingState(overallLevel: LightingLevel.dim),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.2, reflectiveQuality: ReflectiveQuality.enclosed),
  olfactoryField: OlfactoryField(
    overallDensity: 0.4,
    airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
  ),
  manaField: const ManaField(
    ambientDensity: 0.8,
    ambientAttribute: ManaAttribute.corrupt,
    manaSources: [
      ManaSource(
        sourceId: 'corruption_001',
        type: ManaSourceType.corruption,
        intensity: 0.5,
        attribute: ManaAttribute.corrupt,
        location: '15,15',
        spreadRadius: 10.0,
        stability: 0.7,
        freshness: ManaFreshness.active,
      ),
    ],
  ),
);

final _sceneWithSubareas = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(
    sceneType: SceneType.room,
    dimensionsEstimate: '20x20',
    subareas: [
      SubArea(subAreaId: 'area_001', name: 'north_section', location: '10,5'),
      SubArea(subAreaId: 'area_002', name: 'south_section', location: '10,15'),
    ],
    entryPoints: [
      EntryPoint(entryPointId: 'entry_001', location: '0,10', direction: 'west'),
      EntryPoint(entryPointId: 'entry_002', location: '20,10', direction: 'east'),
    ],
  ),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
);

final _sceneWithObstacles = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(
    sceneType: SceneType.room,
    dimensionsEstimate: '10x10',
    obstacles: [
      Obstacle(id: 'obstacle_001', type: ObstacleType.table, location: '3,3', blocksVision: false),
      Obstacle(id: 'obstacle_002', type: ObstacleType.wall, location: '5,5', blocksVision: true),
    ],
  ),
  lighting: const LightingState(overallLevel: LightingLevel.normal),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.3,
    airflow: const Airflow(strength: AirflowStrength.weak, direction: 'north'),
  ),
);
