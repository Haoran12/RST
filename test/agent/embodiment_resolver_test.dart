import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/baseline_body_profile.dart';
import 'package:rst/core/models/agent/mana_field.dart';
import 'package:rst/core/models/agent/scene_model.dart';
import 'package:rst/core/models/agent/temporary_body_state.dart';
import 'package:rst/core/services/agent/embodiment_resolver.dart';

void main() {
  group('EmbodimentResolver', () {
    const resolver = EmbodimentResolver();

    group('sensory capabilities', () {
      test('computes vision capability with normal conditions', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalLitScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.vision.availability, equals(1.0));
        expect(result.sensoryCapabilities.vision.acuity, closeTo(1.0, 0.1));
        expect(result.sensoryCapabilities.vision.stability, equals(1.0));
      });

      test('computes vision capability with blocked vision', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: TemporaryBodyState(
            sensoryBlocks: const SensoryBlocks(visionBlocked: true),
          ),
          scene: _normalLitScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.vision.availability, equals(0.0));
      });

      test('computes vision capability with dim lighting', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _dimLitScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.vision.acuity, lessThan(1.0));
        expect(result.sensoryCapabilities.vision.notes, contains('low light'));
      });

      test('computes hearing capability with high ambient noise', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _noisyScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.hearing.acuity, lessThan(1.0));
        expect(result.sensoryCapabilities.hearing.notes, contains('high ambient noise'));
      });

      test('computes smell capability with blocked smell', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: TemporaryBodyState(
            sensoryBlocks: const SensoryBlocks(smellBlocked: true),
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.smell.availability, equals(0.0));
      });
    });

    group('mana sensory capabilities', () {
      test('mortal has limited mana sensing', () {
        final request = _createRequest(
          baselineProfile: _mortalBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        // Mortal has low acuity due to realm and species modifiers
        // availability is 1.0 because cognitive clarity is 1.0
        expect(result.sensoryCapabilities.mana.acuity, lessThan(0.5));
        expect(result.sensoryCapabilities.mana.penetration, equals(0.0));
      });

      test('cultivator has enhanced mana sensing', () {
        final request = _createRequest(
          baselineProfile: _cultivatorBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.mana.availability, equals(1.0));
        expect(result.sensoryCapabilities.mana.acuity, greaterThan(0.5));
        expect(result.sensoryCapabilities.mana.penetration, greaterThan(0.0));
      });

      test('mana depletion reduces mana sensing availability', () {
        final request = _createRequest(
          baselineProfile: _cultivatorBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            manaDepletion: 0.9,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.mana.availability, lessThan(1.0));
      });

      test('mana blocked disables mana sensing', () {
        final request = _createRequest(
          baselineProfile: _cultivatorBaseline,
          temporaryState: TemporaryBodyState(
            sensoryBlocks: const SensoryBlocks(manaBlocked: true),
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.mana.availability, equals(0.0));
      });

      test('soul perception trait increases penetration', () {
        final request = _createRequest(
          baselineProfile: BaselineBodyProfile(
            species: 'sensitive_cultivator',
            sensoryBaseline: const SensoryBaseline(
              vision: 1.0,
              hearing: 1.0,
              smell: 1.0,
              touch: 1.0,
              proprioception: 1.0,
            ),
            motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
            cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
            manaSensoryBaseline: const ManaSensoryBaseline(
              baseAcuity: 1.0,
              traits: [ManaSenseTrait.soulPerception],
            ),
          ),
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.mana.penetration, greaterThanOrEqualTo(0.5));
      });

      test('high mana density causes overload', () {
        final request = _createRequest(
          baselineProfile: _cultivatorBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _highManaScene,
        );

        final result = resolver.resolve(request);

        expect(result.sensoryCapabilities.mana.overloadLevel, greaterThan(0.0));
      });
    });

    group('body constraints', () {
      test('healthy character has normal body constraints', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.bodyConstraints.mobility, equals(1.0));
        expect(result.bodyConstraints.balance, equals(1.0));
        expect(result.bodyConstraints.painLoad, equals(0.0));
        expect(result.bodyConstraints.fatigue, equals(0.0));
        expect(result.bodyConstraints.cognitiveClarity, equals(1.0));
      });

      test('injuries reduce mobility', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            injuries: [
              Injury(part: 'leg', severity: 0.5, pain: 0.3, functionalPenalty: 0.4),
            ],
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.bodyConstraints.mobility, lessThan(1.0));
      });

      test('fatigue reduces mobility and cognitive clarity', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            fatigue: 0.5,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.bodyConstraints.mobility, lessThan(1.0));
        expect(result.bodyConstraints.fatigue, equals(0.5));
        expect(result.bodyConstraints.cognitiveClarity, lessThan(1.0));
      });

      test('pain increases pain load and reduces cognitive clarity', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            painLevel: 0.6,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.bodyConstraints.painLoad, equals(0.6));
        expect(result.bodyConstraints.cognitiveClarity, lessThan(1.0));
      });

      test('dizziness reduces balance', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            dizziness: 0.5,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.bodyConstraints.balance, lessThan(1.0));
      });
    });

    group('salience modifiers', () {
      test('healthy character has no salience modifiers', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.salienceModifiers.attentionPull, isEmpty);
        expect(result.salienceModifiers.aversionTriggers, isEmpty);
        expect(result.salienceModifiers.overloadRisks, isEmpty);
      });

      test('high pain creates attention pull', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            painLevel: 0.5,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.salienceModifiers.attentionPull, isNotEmpty);
        expect(
          result.salienceModifiers.attentionPull.any((p) => p.stimulusType == 'pain'),
          isTrue,
        );
      });

      test('soul damage creates aversion triggers', () {
        final request = _createRequest(
          baselineProfile: _cultivatorBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            soulDamage: 0.5,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.salienceModifiers.aversionTriggers, isNotEmpty);
        expect(result.salienceModifiers.overloadRisks, contains('spiritual_overload'));
      });

      test('high dizziness creates overload risk', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            dizziness: 0.6,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.salienceModifiers.overloadRisks, contains('sensory_overload'));
      });
    });

    group('reasoning modifiers', () {
      test('healthy character has normal reasoning', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.reasoningModifiers.cognitiveClarity, equals(1.0));
        expect(result.reasoningModifiers.painBias, equals(0.0));
        expect(result.reasoningModifiers.threatBias, equals(0.0));
        expect(result.reasoningModifiers.overloadBias, equals(0.0));
      });

      test('pain creates pain bias in reasoning', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            painLevel: 0.6,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.reasoningModifiers.painBias, greaterThan(0.0));
      });
    });

    group('action feasibility', () {
      test('healthy character has full action feasibility', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: _healthyTemporaryState,
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.actionFeasibility.physicalExecutionCapacity, equals(1.0));
        expect(result.actionFeasibility.socialPatience, equals(1.0));
        expect(result.actionFeasibility.fineControl, equals(1.0));
        expect(result.actionFeasibility.sustainedAttention, equals(1.0));
      });

      test('injuries and fatigue reduce physical execution capacity', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            injuries: [
              Injury(part: 'leg', severity: 0.5, pain: 0.3, functionalPenalty: 0.3),
            ],
            fatigue: 0.4,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.actionFeasibility.physicalExecutionCapacity, lessThan(1.0));
      });

      test('hand injury reduces fine control', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            injuries: [
              Injury(part: 'hand', severity: 0.5, pain: 0.3, functionalPenalty: 0.5),
            ],
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.actionFeasibility.fineControl, lessThan(1.0));
      });

      test('pain and fatigue reduce social patience', () {
        final request = _createRequest(
          baselineProfile: _humanBaseline,
          temporaryState: const TemporaryBodyState(
            sensoryBlocks: SensoryBlocks(),
            painLevel: 0.5,
            fatigue: 0.5,
          ),
          scene: _normalScene,
        );

        final result = resolver.resolve(request);

        expect(result.actionFeasibility.socialPatience, lessThan(1.0));
      });
    });
  });
}

// === Test fixtures ===

EmbodimentResolveRequest _createRequest({
  required BaselineBodyProfile baselineProfile,
  required TemporaryBodyState temporaryState,
  required SceneModel scene,
}) {
  return EmbodimentResolveRequest(
    characterId: 'test_character',
    sceneTurnId: 'turn_001',
    baselineProfile: baselineProfile,
    temporaryState: temporaryState,
    scene: scene,
  );
}

const _healthyTemporaryState = TemporaryBodyState(
  sensoryBlocks: SensoryBlocks(),
);

final _humanBaseline = BaselineBodyProfile(
  species: 'human',
  sensoryBaseline: const SensoryBaseline(
    vision: 1.0,
    hearing: 1.0,
    smell: 1.0,
    touch: 1.0,
    proprioception: 1.0,
  ),
  motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
  cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
  manaSensoryBaseline: const ManaSensoryBaseline(baseAcuity: 0.3),
);

final _mortalBaseline = BaselineBodyProfile(
  species: 'mortal',
  sensoryBaseline: const SensoryBaseline(
    vision: 1.0,
    hearing: 1.0,
    smell: 1.0,
    touch: 1.0,
    proprioception: 1.0,
  ),
  motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
  cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
  manaSensoryBaseline: const ManaSensoryBaseline(
    baseAcuity: 0.3,
    realmModifier: 0.5,
    speciesModifier: 0.5,
  ),
);

final _cultivatorBaseline = BaselineBodyProfile(
  species: 'cultivator',
  sensoryBaseline: const SensoryBaseline(
    vision: 1.0,
    hearing: 1.0,
    smell: 1.0,
    touch: 1.0,
    proprioception: 1.0,
  ),
  motorBaseline: const MotorBaseline(mobility: 1.0, balance: 1.0, stamina: 1.0),
  cognitionBaseline: const CognitionBaseline(stressTolerance: 1.0, sensoryOverloadTolerance: 1.0),
  manaSensoryBaseline: const ManaSensoryBaseline(
    baseAcuity: 1.0,
    realmModifier: 1.5,
    traits: [ManaSenseTrait.auraReading, ManaSenseTrait.attributeSense, ManaSenseTrait.soulPerception],
  ),
);

final _normalScene = SceneModel(
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
);

final _normalLitScene = SceneModel(
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
);

final _dimLitScene = SceneModel(
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
);

final _noisyScene = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.street, dimensionsEstimate: '100x20'),
  lighting: const LightingState(overallLevel: LightingLevel.bright),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.8, reflectiveQuality: ReflectiveQuality.open),
  olfactoryField: OlfactoryField(
    overallDensity: 0.6,
    airflow: const Airflow(strength: AirflowStrength.flowing, direction: 'east'),
  ),
);

final _highManaScene = SceneModel(
  sceneId: 'scene_001',
  sceneTurnId: 'turn_001',
  timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
  spatialLayout: const SpatialLayout(sceneType: SceneType.cave, dimensionsEstimate: '30x30'),
  lighting: const LightingState(overallLevel: LightingLevel.dim),
  acoustics: const AcousticsState(ambientNoiseLevel: 0.1, reflectiveQuality: ReflectiveQuality.enclosed),
  olfactoryField: OlfactoryField(
    overallDensity: 0.2,
    airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
  ),
  manaField: const ManaField(
    ambientDensity: 2.0,
    ambientAttribute: ManaAttribute.wood,
  ),
);
