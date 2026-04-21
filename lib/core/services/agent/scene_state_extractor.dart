import '../../models/agent/scene_model.dart';

/// Scene extraction request containing raw input sources.
class SceneExtractionRequest {
  const SceneExtractionRequest({
    required this.sceneId,
    required this.sceneTurnId,
    this.narrativeInput,
    this.worldStateJson,
    this.previousScene,
  });

  final String sceneId;
  final String sceneTurnId;
  final String? narrativeInput;
  final Map<String, dynamic>? worldStateJson;
  final SceneModel? previousScene;
}

/// Result of scene extraction with the model and extraction metadata.
class SceneExtractionResult {
  const SceneExtractionResult({
    required this.scene,
    required this.extractionSource,
    required this.confidence,
    this.parseWarnings = const [],
  });

  final SceneModel scene;
  final String extractionSource; // 'world_state', 'narrative', 'inherited'
  final double confidence;
  final List<String> parseWarnings;
}

/// Extracts structured SceneModel from world state or narrative input.
///
/// This is a pure programmatic service that parses:
/// - Time context (time expressions, weather, visibility)
/// - Spatial layout (scene type, dimensions, obstacles)
/// - Entities (named entity patterns from narrative)
/// - Lighting (time-of-day + scene type + explicit mentions)
/// - Acoustics (scene type + spatial characteristics)
/// - Mana field (spiritual energy patterns)
class SceneStateExtractor {
  const SceneStateExtractor();

  /// Extract scene model from available input sources.
  /// Priority: worldStateJson > narrativeInput > previousScene
  Future<SceneExtractionResult> extract(SceneExtractionRequest request) async {
    // Priority 1: World state JSON
    if (request.worldStateJson != null) {
      final result = _parseWorldState(
        sceneId: request.sceneId,
        sceneTurnId: request.sceneTurnId,
        worldState: request.worldStateJson!,
        previousScene: request.previousScene,
      );
      return SceneExtractionResult(
        scene: result,
        extractionSource: 'world_state',
        confidence: 0.9,
      );
    }

    // Priority 2: Narrative input
    if (request.narrativeInput != null && request.narrativeInput!.isNotEmpty) {
      final result = parseNarrative(
        sceneId: request.sceneId,
        sceneTurnId: request.sceneTurnId,
        narrative: request.narrativeInput!,
        previousScene: request.previousScene,
      );
      return SceneExtractionResult(
        scene: result,
        extractionSource: 'narrative',
        confidence: 0.7,
        parseWarnings: _extractWarnings(result),
      );
    }

    // Priority 3: Inherit from previous scene
    if (request.previousScene != null) {
      final result = request.previousScene!.copyWith(
        sceneTurnId: request.sceneTurnId,
      );
      return SceneExtractionResult(
        scene: result,
        extractionSource: 'inherited',
        confidence: 0.5,
      );
    }

    // Fallback: Create minimal scene
    return SceneExtractionResult(
      scene: _createMinimalScene(request.sceneId, request.sceneTurnId),
      extractionSource: 'fallback',
      confidence: 0.1,
      parseWarnings: const ['No input sources available, created minimal scene'],
    );
  }

  /// Parse narrative text into scene model components.
  /// Uses pattern matching and keyword extraction (no LLM).
  SceneModel parseNarrative({
    required String sceneId,
    required String sceneTurnId,
    required String narrative,
    SceneModel? previousScene,
  }) {
    final narrativeLower = narrative.toLowerCase();

    // Parse time context
    final timeContext = _parseTimeContext(narrativeLower, previousScene);

    // Parse spatial layout
    final spatialLayout = _parseSpatialLayout(narrativeLower, previousScene);

    // Parse lighting
    final lighting = _parseLighting(narrativeLower, timeContext, spatialLayout, previousScene);

    // Parse acoustics
    final acoustics = _parseAcoustics(narrativeLower, spatialLayout, previousScene);

    // Parse olfactory field
    final olfactoryField = _parseOlfactoryField(narrativeLower, previousScene);

    // Parse entities
    final entities = _parseEntities(narrative, previousScene);

    // Parse observable signals
    final observableSignals = _parseObservableSignals(narrative, previousScene);

    return SceneModel(
      sceneId: sceneId,
      sceneTurnId: sceneTurnId,
      timeContext: timeContext,
      spatialLayout: spatialLayout,
      lighting: lighting,
      acoustics: acoustics,
      olfactoryField: olfactoryField,
      manaField: previousScene?.manaField,
      entities: entities,
      observableSignals: observableSignals,
      eventStream: previousScene?.eventStream ?? const [],
      observabilityConstraints: previousScene?.observabilityConstraints ?? const [],
      uncertaintyNotes: _extractUncertaintyNotes(narrativeLower),
    );
  }

  /// Merge partial updates with previous scene state.
  SceneModel mergeWithPrevious({
    required SceneModel previous,
    required Map<String, dynamic> updates,
  }) {
    return previous.copyWith(
      timeContext: updates['timeContext'] != null
          ? TimeContext.fromJson(updates['timeContext'])
          : null,
      spatialLayout: updates['spatialLayout'] != null
          ? SpatialLayout.fromJson(updates['spatialLayout'])
          : null,
      lighting: updates['lighting'] != null
          ? LightingState.fromJson(updates['lighting'])
          : null,
      acoustics: updates['acoustics'] != null
          ? AcousticsState.fromJson(updates['acoustics'])
          : null,
    );
  }

  // === Private helper methods ===

  SceneModel _parseWorldState({
    required String sceneId,
    required String sceneTurnId,
    required Map<String, dynamic> worldState,
    SceneModel? previousScene,
  }) {
    return SceneModel.fromJson({
      'sceneId': sceneId,
      'sceneTurnId': sceneTurnId,
      ...worldState,
    });
  }

  TimeContext _parseTimeContext(String narrativeLower, SceneModel? previous) {
    // Time of day patterns
    String timeOfDay = previous?.timeContext.timeOfDay ?? 'day';

    if (narrativeLower.contains('dawn') || narrativeLower.contains('日出')) {
      timeOfDay = 'dawn';
    } else if (narrativeLower.contains('morning') || narrativeLower.contains('早晨')) {
      timeOfDay = 'morning';
    } else if (narrativeLower.contains('noon') || narrativeLower.contains('正午')) {
      timeOfDay = 'noon';
    } else if (narrativeLower.contains('afternoon') || narrativeLower.contains('下午')) {
      timeOfDay = 'afternoon';
    } else if (narrativeLower.contains('dusk') || narrativeLower.contains('黄昏') || narrativeLower.contains('日落')) {
      timeOfDay = 'dusk';
    } else if (narrativeLower.contains('night') || narrativeLower.contains('夜晚') || narrativeLower.contains('深夜')) {
      timeOfDay = 'night';
    } else if (narrativeLower.contains('midnight') || narrativeLower.contains('午夜')) {
      timeOfDay = 'midnight';
    }

    // Weather patterns
    String weather = previous?.timeContext.weather ?? 'clear';

    if (narrativeLower.contains('rain') || narrativeLower.contains('雨')) {
      weather = 'rain';
    } else if (narrativeLower.contains('snow') || narrativeLower.contains('雪')) {
      weather = 'snow';
    } else if (narrativeLower.contains('fog') || narrativeLower.contains('雾')) {
      weather = 'fog';
    } else if (narrativeLower.contains('storm') || narrativeLower.contains('暴风雨')) {
      weather = 'storm';
    } else if (narrativeLower.contains('cloudy') || narrativeLower.contains('阴天')) {
      weather = 'cloudy';
    }

    // Visibility
    String visibility = previous?.timeContext.visibilityCondition ?? 'good';

    if (weather == 'fog' || weather == 'storm') {
      visibility = 'poor';
    } else if (narrativeLower.contains('clear') || narrativeLower.contains('晴朗')) {
      visibility = 'excellent';
    }

    return TimeContext(
      timeOfDay: timeOfDay,
      weather: weather,
      visibilityCondition: visibility,
      ambientContextNotes: previous?.timeContext.ambientContextNotes ?? const [],
    );
  }

  SpatialLayout _parseSpatialLayout(String narrativeLower, SceneModel? previous) {
    // Scene type detection
    SceneType sceneType = previous?.spatialLayout.sceneType ?? SceneType.unknown;

    if (narrativeLower.contains('room') || narrativeLower.contains('房间') || narrativeLower.contains('室内')) {
      sceneType = SceneType.room;
    } else if (narrativeLower.contains('street') || narrativeLower.contains('街道') || narrativeLower.contains('路')) {
      sceneType = SceneType.street;
    } else if (narrativeLower.contains('forest') || narrativeLower.contains('森林') || narrativeLower.contains('树林')) {
      sceneType = SceneType.forest;
    } else if (narrativeLower.contains('courtyard') || narrativeLower.contains('庭院') || narrativeLower.contains('院子')) {
      sceneType = SceneType.courtyard;
    } else if (narrativeLower.contains('cave') || narrativeLower.contains('洞穴') || narrativeLower.contains('山洞')) {
      sceneType = SceneType.cave;
    } else if (narrativeLower.contains('hallway') || narrativeLower.contains('走廊') || narrativeLower.contains('过道')) {
      sceneType = SceneType.hallway;
    }

    // Obstacles
    final obstacles = <Obstacle>[];

    if (narrativeLower.contains('wall') || narrativeLower.contains('墙')) {
      obstacles.add(const Obstacle(id: 'wall', type: ObstacleType.wall, location: 'center', blocksVision: true));
    }
    if (narrativeLower.contains('table') || narrativeLower.contains('桌子')) {
      obstacles.add(const Obstacle(id: 'table', type: ObstacleType.table, location: 'center', blocksVision: false));
    }
    if (narrativeLower.contains('curtain') || narrativeLower.contains('帘')) {
      obstacles.add(const Obstacle(id: 'curtain', type: ObstacleType.curtain, location: 'side', blocksVision: true));
    }
    if (narrativeLower.contains('tree') || narrativeLower.contains('树')) {
      obstacles.add(const Obstacle(id: 'tree', type: ObstacleType.tree, location: 'scattered', blocksVision: true));
    }

    return SpatialLayout(
      sceneType: sceneType,
      dimensionsEstimate: previous?.spatialLayout.dimensionsEstimate ?? 'unknown',
      subareas: previous?.spatialLayout.subareas ?? const [],
      obstacles: obstacles.isNotEmpty ? obstacles : (previous?.spatialLayout.obstacles ?? const []),
      entryPoints: previous?.spatialLayout.entryPoints ?? const [],
    );
  }

  LightingState _parseLighting(
    String narrativeLower,
    TimeContext timeContext,
    SpatialLayout spatialLayout,
    SceneModel? previous,
  ) {
    LightingLevel level = previous?.lighting.overallLevel ?? LightingLevel.normal;

    // Time-based lighting
    final timeLower = timeContext.timeOfDay.toLowerCase();
    if (timeLower == 'night' || timeLower == 'midnight') {
      level = LightingLevel.dark;
    } else if (timeLower == 'dusk' || timeLower == 'dawn') {
      level = LightingLevel.dim;
    } else if (timeLower == 'noon') {
      level = LightingLevel.bright;
    }

    // Scene-based lighting adjustment
    if (spatialLayout.sceneType == SceneType.cave) {
      level = LightingLevel.values[level.index.clamp(0, LightingLevel.dark.index)];
    }

    // Explicit lighting mentions
    if (narrativeLower.contains('bright') || narrativeLower.contains('明亮') || narrativeLower.contains('光亮')) {
      level = LightingLevel.bright;
    } else if (narrativeLower.contains('dim') || narrativeLower.contains('昏暗') || narrativeLower.contains('暗')) {
      level = LightingLevel.dim;
    } else if (narrativeLower.contains('dark') || narrativeLower.contains('黑暗')) {
      level = LightingLevel.dark;
    } else if (narrativeLower.contains('candle') || narrativeLower.contains('candlelight') || narrativeLower.contains('烛光')) {
      level = LightingLevel.veryDim;
    }

    return LightingState(
      overallLevel: level,
      sourcePoints: previous?.lighting.sourcePoints ?? const [],
      shadowZones: previous?.lighting.shadowZones ?? const [],
      backlightZones: previous?.lighting.backlightZones ?? const [],
      flicker: narrativeLower.contains('flicker') || narrativeLower.contains('闪烁') ? 0.3 : 0.0,
      visualNoise: previous?.lighting.visualNoise ?? const [],
    );
  }

  AcousticsState _parseAcoustics(String narrativeLower, SpatialLayout spatialLayout, SceneModel? previous) {
    ReflectiveQuality quality = previous?.acoustics.reflectiveQuality ?? ReflectiveQuality.open;

    // Scene-based acoustics
    if (spatialLayout.sceneType == SceneType.cave) {
      quality = ReflectiveQuality.echoing;
    } else if (spatialLayout.sceneType == SceneType.room) {
      quality = ReflectiveQuality.muffled;
    } else if (spatialLayout.sceneType == SceneType.hallway) {
      quality = ReflectiveQuality.enclosed;
    }

    // Explicit mentions
    if (narrativeLower.contains('echo') || narrativeLower.contains('回声')) {
      quality = ReflectiveQuality.echoing;
    } else if (narrativeLower.contains('quiet') || narrativeLower.contains('安静')) {
      quality = ReflectiveQuality.muffled;
    }

    // Noise level
    double noiseLevel = previous?.acoustics.ambientNoiseLevel ?? 0.3;

    if (narrativeLower.contains('noisy') || narrativeLower.contains('嘈杂') || narrativeLower.contains('喧闹')) {
      noiseLevel = 0.8;
    } else if (narrativeLower.contains('silent') || narrativeLower.contains('寂静')) {
      noiseLevel = 0.1;
    }

    return AcousticsState(
      ambientNoiseLevel: noiseLevel,
      ambientSources: previous?.acoustics.ambientSources ?? const [],
      reflectiveQuality: quality,
    );
  }

  OlfactoryField _parseOlfactoryField(String narrativeLower, SceneModel? previous) {
    final odorSources = <OdorSource>[];

    // Detect odors
    if (narrativeLower.contains('blood') || narrativeLower.contains('血')) {
      odorSources.add(const OdorSource(
        id: 'blood_odor',
        type: OdorType.blood,
        intensity: 0.7,
        freshness: OdorFreshness.fresh,
        spreadRange: 3.0,
        sourcePosition: 'nearby',
      ));
    }
    if (narrativeLower.contains('incense') || narrativeLower.contains('香')) {
      odorSources.add(const OdorSource(
        id: 'incense_odor',
        type: OdorType.incense,
        intensity: 0.5,
        freshness: OdorFreshness.recent,
        spreadRange: 5.0,
        sourcePosition: 'room',
      ));
    }
    if (narrativeLower.contains('medicine') || narrativeLower.contains('药')) {
      odorSources.add(const OdorSource(
        id: 'medicine_odor',
        type: OdorType.medicine,
        intensity: 0.6,
        freshness: OdorFreshness.fresh,
        spreadRange: 4.0,
        sourcePosition: 'nearby',
      ));
    }

    // Airflow
    AirflowStrength airflowStrength = AirflowStrength.still;
    if (narrativeLower.contains('wind') || narrativeLower.contains('风')) {
      airflowStrength = AirflowStrength.flowing;
    } else if (narrativeLower.contains('breeze') || narrativeLower.contains('微风')) {
      airflowStrength = AirflowStrength.weak;
    }

    return OlfactoryField(
      overallDensity: odorSources.isNotEmpty ? 0.5 : (previous?.olfactoryField.overallDensity ?? 0.3),
      airflow: Airflow(strength: airflowStrength, direction: previous?.olfactoryField.airflow.direction ?? ''),
      odorSources: odorSources.isNotEmpty ? odorSources : (previous?.olfactoryField.odorSources ?? const []),
      interferingOdors: previous?.olfactoryField.interferingOdors ?? const [],
    );
  }

  List<SceneEntity> _parseEntities(String narrative, SceneModel? previous) {
    // Simple entity extraction - in a real implementation, this would use NER
    // For now, just return previous entities
    return previous?.entities ?? const [];
  }

  List<ObservableSignal> _parseObservableSignals(String narrative, SceneModel? previous) {
    // Simple signal extraction
    return previous?.observableSignals ?? const [];
  }

  List<String> _extractUncertaintyNotes(String narrativeLower) {
    final notes = <String>[];

    if (narrativeLower.contains('maybe') || narrativeLower.contains('可能') || narrativeLower.contains('似乎')) {
      notes.add('Contains uncertain language');
    }
    if (narrativeLower.contains('unclear') || narrativeLower.contains('不清楚') || narrativeLower.contains('模糊')) {
      notes.add('Visibility or situation unclear');
    }

    return notes;
  }

  List<String> _extractWarnings(SceneModel scene) {
    final warnings = <String>[];

    if (scene.spatialLayout.sceneType == SceneType.unknown) {
      warnings.add('Scene type could not be determined');
    }
    if (scene.lighting.overallLevel == LightingLevel.dark && scene.entities.isNotEmpty) {
      warnings.add('Dark scene with entities - visibility may be limited');
    }

    return warnings;
  }

  SceneModel _createMinimalScene(String sceneId, String sceneTurnId) {
    return SceneModel(
      sceneId: sceneId,
      sceneTurnId: sceneTurnId,
      timeContext: const TimeContext(timeOfDay: 'day', weather: 'clear', visibilityCondition: 'good'),
      spatialLayout: const SpatialLayout(sceneType: SceneType.unknown, dimensionsEstimate: 'unknown'),
      lighting: const LightingState(overallLevel: LightingLevel.normal),
      acoustics: const AcousticsState(ambientNoiseLevel: 0.3, reflectiveQuality: ReflectiveQuality.open),
      olfactoryField: OlfactoryField(
        overallDensity: 0.3,
        airflow: const Airflow(strength: AirflowStrength.still, direction: ''),
      ),
    );
  }
}
