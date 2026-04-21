import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/scene_model.dart';
import 'package:rst/core/services/agent/scene_state_extractor.dart';

void main() {
  group('SceneStateExtractor', () {
    const extractor = SceneStateExtractor();

    group('time context parsing', () {
      test('parses dawn time', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The sun began to rise at dawn.',
        );

        expect(result.timeContext.timeOfDay, equals('dawn'));
      });

      test('parses night time', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'It was a dark night.',
        );

        expect(result.timeContext.timeOfDay, equals('night'));
      });

      test('parses weather - rain', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'Heavy rain fell from the sky.',
        );

        expect(result.timeContext.weather, equals('rain'));
      });

      test('parses weather - snow', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'Snow covered the ground.',
        );

        expect(result.timeContext.weather, equals('snow'));
      });

      test('parses fog reduces visibility', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'Thick fog surrounded them.',
        );

        expect(result.timeContext.weather, equals('fog'));
        expect(result.timeContext.visibilityCondition, equals('poor'));
      });
    });

    group('spatial layout parsing', () {
      test('parses room scene type', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'They entered a small room.',
        );

        expect(result.spatialLayout.sceneType, equals(SceneType.room));
      });

      test('parses forest scene type', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'They walked through the forest.',
        );

        expect(result.spatialLayout.sceneType, equals(SceneType.forest));
      });

      test('parses cave scene type', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The cave was dark and cold.',
        );

        expect(result.spatialLayout.sceneType, equals(SceneType.cave));
      });

      test('parses obstacles - wall', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'A wall blocked their path.',
        );

        expect(result.spatialLayout.obstacles.any((o) => o.type == ObstacleType.wall), isTrue);
      });

      test('parses obstacles - table', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'There was a table in the center.',
        );

        expect(result.spatialLayout.obstacles.any((o) => o.type == ObstacleType.table), isTrue);
      });
    });

    group('lighting parsing', () {
      test('night time creates dark lighting', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'It was night.',
        );

        expect(result.lighting.overallLevel, equals(LightingLevel.dark));
      });

      test('noon creates bright lighting', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'At noon, the sun was high.',
        );

        expect(result.lighting.overallLevel, equals(LightingLevel.bright));
      });

      test('explicit dim lighting', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The room was dim.',
        );

        expect(result.lighting.overallLevel, equals(LightingLevel.dim));
      });

      test('candlelight creates very dim lighting', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'A single candle flickered.',
        );

        expect(result.lighting.overallLevel, equals(LightingLevel.veryDim));
        expect(result.lighting.flicker, greaterThan(0));
      });
    });

    group('acoustics parsing', () {
      test('cave creates echoing acoustics', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'They entered a cave.',
        );

        expect(result.acoustics.reflectiveQuality, equals(ReflectiveQuality.echoing));
      });

      test('room creates muffled acoustics', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'They sat in a small room.',
        );

        expect(result.acoustics.reflectiveQuality, equals(ReflectiveQuality.muffled));
      });

      test('noisy environment', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The market was noisy and crowded.',
        );

        expect(result.acoustics.ambientNoiseLevel, greaterThan(0.5));
      });

      test('silent environment', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The temple was silent.',
        );

        expect(result.acoustics.ambientNoiseLevel, lessThan(0.2));
      });
    });

    group('olfactory field parsing', () {
      test('parses blood odor', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The smell of blood filled the air.',
        );

        expect(result.olfactoryField.odorSources.any((o) => o.type == OdorType.blood), isTrue);
      });

      test('parses incense odor', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'Incense burned in the temple.',
        );

        expect(result.olfactoryField.odorSources.any((o) => o.type == OdorType.incense), isTrue);
      });

      test('parses medicine odor', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The medicine smell was strong.',
        );

        expect(result.olfactoryField.odorSources.any((o) => o.type == OdorType.medicine), isTrue);
      });

      test('parses wind airflow', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'A strong wind blew.',
        );

        expect(result.olfactoryField.airflow.strength, equals(AirflowStrength.flowing));
      });
    });

    group('inheritance from previous scene', () {
      test('inherits from previous scene when no input', () async {
        final previousScene = SceneModel(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          timeContext: const TimeContext(timeOfDay: 'dusk', weather: 'rain', visibilityCondition: 'poor'),
          spatialLayout: const SpatialLayout(sceneType: SceneType.forest, dimensionsEstimate: 'large'),
          lighting: const LightingState(overallLevel: LightingLevel.dim),
          acoustics: const AcousticsState(ambientNoiseLevel: 0.5, reflectiveQuality: ReflectiveQuality.open),
          olfactoryField: OlfactoryField(
            overallDensity: 0.4,
            airflow: const Airflow(strength: AirflowStrength.flowing, direction: 'south'),
          ),
        );

        final request = SceneExtractionRequest(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_002',
          previousScene: previousScene,
        );

        final result = await extractor.extract(request);

        expect(result.extractionSource, equals('inherited'));
        expect(result.scene.timeContext.timeOfDay, equals('dusk'));
        expect(result.scene.timeContext.weather, equals('rain'));
        expect(result.scene.spatialLayout.sceneType, equals(SceneType.forest));
        expect(result.scene.sceneTurnId, equals('turn_002'));
      });
    });

    group('world state parsing', () {
      test('parses world state JSON', () async {
        final request = SceneExtractionRequest(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          worldStateJson: {
            'timeContext': {'timeOfDay': 'night', 'weather': 'storm', 'visibilityCondition': 'poor'},
            'spatialLayout': {'sceneType': 'cave', 'dimensionsEstimate': '20x30'},
            'lighting': {'overallLevel': 'dark'},
            'acoustics': {'ambientNoiseLevel': 0.2, 'reflectiveQuality': 'echoing'},
            'olfactoryField': {'overallDensity': 0.3, 'airflow': {'strength': 'still', 'direction': ''}},
          },
        );

        final result = await extractor.extract(request);

        expect(result.extractionSource, equals('world_state'));
        expect(result.scene.timeContext.timeOfDay, equals('night'));
        expect(result.scene.timeContext.weather, equals('storm'));
        expect(result.scene.spatialLayout.sceneType, equals(SceneType.cave));
        expect(result.confidence, greaterThan(0.8));
      });
    });

    group('fallback behavior', () {
      test('creates minimal scene when no input available', () async {
        final request = SceneExtractionRequest(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
        );

        final result = await extractor.extract(request);

        expect(result.extractionSource, equals('fallback'));
        expect(result.confidence, lessThan(0.2));
        expect(result.parseWarnings, isNotEmpty);
        expect(result.scene.sceneId, equals('scene_001'));
      });
    });

    group('uncertainty notes', () {
      test('extracts uncertainty from narrative', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'Maybe they were hiding in the shadows.',
        );

        expect(result.uncertaintyNotes, contains('Contains uncertain language'));
      });

      test('extracts unclear visibility', () {
        final result = extractor.parseNarrative(
          sceneId: 'scene_001',
          sceneTurnId: 'turn_001',
          narrative: 'The situation was unclear.',
        );

        expect(result.uncertaintyNotes, contains('Visibility or situation unclear'));
      });
    });
  });
}
