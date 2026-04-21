import '../../models/agent/embodiment_state.dart';
import '../../models/agent/filtered_scene_view.dart';
import '../../models/agent/mana_field.dart';
import '../../models/agent/scene_model.dart';

/// Request for scene filtering.
class SceneFilterRequest {
  const SceneFilterRequest({
    required this.characterId,
    required this.sceneTurnId,
    required this.scene,
    required this.embodiment,
    this.characterLocation,
  });

  final String characterId;
  final String sceneTurnId;
  final SceneModel scene;
  final EmbodimentState embodiment;
  final String? characterLocation;
}

/// Generates character-specific filtered scene view based on embodiment state.
///
/// This is a pure programmatic service that filters:
/// - Visible entities (visibility calculation, obstacle blocking, lighting effects)
/// - Audible signals (sound propagation, acoustics environment)
/// - Olfactory signals (odor propagation, airflow effects)
/// - Mana signals (mana sensing, distance attenuation, interference, attribute sensitivity)
/// - Spatial context (reachable areas, nearby obstacles)
class SceneFilteringProtocol {
  const SceneFilteringProtocol();

  static const double _visibilityThreshold = 0.1;
  static const double _audibilityThreshold = 0.1;
  static const double _olfactoryThreshold = 0.1;
  static const double _manaThreshold = 0.1;

  /// Generate filtered scene view for the character.
  FilteredSceneView filter(SceneFilterRequest request) {
    final visibleEntities = filterVisibleEntities(
      scene: request.scene,
      vision: request.embodiment.sensoryCapabilities.vision,
      characterLocation: request.characterLocation,
    );

    final audibleSignals = filterAudibleSignals(
      scene: request.scene,
      hearing: request.embodiment.sensoryCapabilities.hearing,
      acoustics: request.scene.acoustics,
      characterLocation: request.characterLocation,
    );

    final olfactorySignals = filterOlfactorySignals(
      scene: request.scene,
      smell: request.embodiment.sensoryCapabilities.smell,
      olfactoryField: request.scene.olfactoryField,
      characterLocation: request.characterLocation,
    );

    final manaSignals = filterManaSignals(
      scene: request.scene,
      manaSense: request.embodiment.sensoryCapabilities.mana,
      manaField: request.scene.manaField,
      characterLocation: request.characterLocation,
    );

    final manaEnvironment = computeManaEnvironment(
      manaField: request.scene.manaField,
      manaSense: request.embodiment.sensoryCapabilities.mana,
    );

    final spatialContext = computeSpatialContext(
      scene: request.scene,
      constraints: request.embodiment.bodyConstraints,
      characterLocation: request.characterLocation,
    );

    return FilteredSceneView(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      visibleEntities: visibleEntities,
      audibleSignals: audibleSignals,
      olfactorySignals: olfactorySignals,
      tactileSignals: const [], // Tactile signals require direct contact
      manaSignals: manaSignals,
      manaEnvironment: manaEnvironment,
      spatialContext: spatialContext,
    );
  }

  /// Filter visible entities based on vision capability and obstacles.
  List<VisibleEntity> filterVisibleEntities({
    required SceneModel scene,
    required SensoryCapability vision,
    required String? characterLocation,
  }) {
    if (vision.availability < _visibilityThreshold) {
      return const [];
    }

    final visibleEntities = <VisibleEntity>[];
    final lighting = scene.lighting;
    final obstacles = scene.spatialLayout.obstacles;

    for (final entity in scene.entities) {
      final visibilityScore = _calculateVisibilityScore(
        entity: entity,
        lighting: lighting,
        vision: vision,
        obstacles: obstacles,
        observerLocation: characterLocation,
      );

      if (visibilityScore > _visibilityThreshold) {
        final clarity = (visibilityScore * vision.stability).clamp(0.0, 1.0);
        visibleEntities.add(VisibleEntity(
          entityId: entity.entityId,
          visibilityScore: visibilityScore,
          clarity: clarity,
          notes: _buildVisibilityNotes(visibilityScore, lighting.overallLevel),
        ));
      }
    }

    // Sort by visibility score descending
    visibleEntities.sort((a, b) => b.visibilityScore.compareTo(a.visibilityScore));
    return visibleEntities;
  }

  /// Filter audible signals based on hearing capability.
  List<AudibleSignal> filterAudibleSignals({
    required SceneModel scene,
    required SensoryCapability hearing,
    required AcousticsState acoustics,
    required String? characterLocation,
  }) {
    if (hearing.availability < _audibilityThreshold) {
      return const [];
    }

    final audibleSignals = <AudibleSignal>[];

    // Process observable signals that are sound-type
    for (final signal in scene.observableSignals) {
      if (signal.type != 'sound' && signal.type != 'speech' && signal.type != 'noise') {
        continue;
      }

      final distance = _estimateDistance(characterLocation, signal.location);
      final distanceFactor = _soundDistanceDecay(distance);
      final acousticsFactor = _acousticsPropagationFactor(acoustics);

      final audibilityScore = (signal.intensity * hearing.acuity * distanceFactor * acousticsFactor)
          .clamp(0.0, 1.0);

      if (audibilityScore > _audibilityThreshold) {
        final direction = _computeDirection(characterLocation, signal.location);
        audibleSignals.add(AudibleSignal(
          signalId: signal.signalId,
          content: signal.content,
          audibilityScore: audibilityScore,
          direction: direction,
        ));
      }
    }

    // Process ambient sound sources
    for (final source in acoustics.ambientSources) {
      final distance = _estimateDistance(characterLocation, source.location);
      final distanceFactor = _soundDistanceDecay(distance);

      final audibilityScore = (source.volume * hearing.acuity * distanceFactor).clamp(0.0, 1.0);

      if (audibilityScore > _audibilityThreshold) {
        final direction = _computeDirection(characterLocation, source.location);
        audibleSignals.add(AudibleSignal(
          signalId: source.sourceId,
          content: source.type,
          audibilityScore: audibilityScore,
          direction: direction,
        ));
      }
    }

    audibleSignals.sort((a, b) => b.audibilityScore.compareTo(a.audibilityScore));
    return audibleSignals;
  }

  /// Filter olfactory signals based on smell capability.
  List<OlfactorySignal> filterOlfactorySignals({
    required SceneModel scene,
    required SensoryCapability smell,
    required OlfactoryField olfactoryField,
    required String? characterLocation,
  }) {
    if (smell.availability < _olfactoryThreshold) {
      return const [];
    }

    final olfactorySignals = <OlfactorySignal>[];

    for (final odor in olfactoryField.odorSources) {
      final distance = _estimateDistance(characterLocation, odor.sourcePosition);
      final distanceFactor = _odorDistanceDecay(distance, odor.spreadRange);
      final airflowFactor = _odorAirflowFactor(olfactoryField.airflow, characterLocation, odor.sourcePosition);
      final freshnessFactor = _odorFreshnessFactor(odor.freshness);

      final intensity = (odor.intensity * smell.acuity * distanceFactor * airflowFactor * freshnessFactor)
          .clamp(0.0, 1.0);

      if (intensity > _olfactoryThreshold) {
        olfactorySignals.add(OlfactorySignal(
          signalId: odor.id,
          content: odor.type.label,
          intensity: intensity,
          freshness: odor.freshness.label,
        ));
      }
    }

    olfactorySignals.sort((a, b) => b.intensity.compareTo(a.intensity));
    return olfactorySignals;
  }

  /// Filter mana signals based on mana sensing capability.
  List<ManaSignal> filterManaSignals({
    required SceneModel scene,
    required ManaSensoryCapability manaSense,
    required ManaField? manaField,
    required String? characterLocation,
  }) {
    if (manaSense.availability <= _manaThreshold || manaField == null) {
      return const [];
    }

    final signals = <ManaSignal>[];

    for (final source in manaField.manaSources) {
      // 1. Distance attenuation
      final distance = _estimateDistance(characterLocation, source.location);
      final distanceFactor = _manaDistanceDecay(distance, manaSense.rangeModifier);

      // 2. Interference factor
      final interferenceFactor = _computeInterferenceFactor(
        interferences: manaField.interferences,
        sourceLocation: source.location,
        observerLocation: characterLocation,
        penetration: manaSense.penetration,
      );

      // 3. Attribute sensitivity factor
      final attributeFactor = _computeAttributeFactor(
        sourceAttribute: source.attribute,
        sensitivity: manaSense.attributeSensitivity,
      );

      // 4. Perceived intensity
      final perceivedIntensity = (source.intensity *
              distanceFactor *
              interferenceFactor *
              attributeFactor *
              manaSense.acuity)
          .clamp(0.0, 2.0);

      // 5. Threshold check
      final threshold = _manaThresholdByType(source.type, source.freshness);
      if (perceivedIntensity < threshold) continue;

      // 6. Clarity calculation
      final clarity = _computeManaClarity(
        perceivedIntensity: perceivedIntensity,
        stability: source.stability,
        manaStability: manaSense.stability,
        interferenceFactor: interferenceFactor,
      );

      // 7. Generate insight if clarity is sufficient
      ManaSignalInsight? insight;
      if (clarity > 0.5 && manaSense.availability > 0.5) {
        insight = _interpretManaSignal(
          source: source,
          clarity: clarity,
        );
      }

      signals.add(ManaSignal(
        signalId: 'mana_${source.sourceId}',
        content: _describeManaSource(source, perceivedIntensity),
        sourceType: source.type,
        perceivedIntensity: perceivedIntensity,
        attribute: source.attribute,
        clarity: clarity,
        direction: _computeDirection(characterLocation, source.location),
        estimatedDistance: distance,
        perceivedStability: source.stability,
        freshness: source.freshness,
        associatedEntityId: source.ownerEntityId,
        insight: insight,
        notes: _buildManaSignalNotes(perceivedIntensity, clarity, interferenceFactor),
      ));
    }

    signals.sort((a, b) => b.perceivedIntensity.compareTo(a.perceivedIntensity));
    return signals;
  }

  /// Compute mana environment perception.
  ManaEnvironmentSense computeManaEnvironment({
    required ManaField? manaField,
    required ManaSensoryCapability manaSense,
  }) {
    if (manaField == null || manaSense.availability < _manaThreshold) {
      return const ManaEnvironmentSense();
    }

    final perceivedDensity = (manaField.ambientDensity * manaSense.acuity).clamp(0.0, 2.0);

    final suitableForCultivation = perceivedDensity > 0.3 &&
        manaField.ambientAttribute != ManaAttribute.corrupt;

    final hasAnomaly = manaField.manaSources.any(
      (s) => s.type == ManaSourceType.corruption || s.type == ManaSourceType.voidRift || s.type == ManaSourceType.tribulation,
    );

    String anomalyDescription = '';
    if (hasAnomaly) {
      final anomalies = manaField.manaSources
          .where((s) => s.type == ManaSourceType.corruption || s.type == ManaSourceType.voidRift)
          .map((s) => s.type.name)
          .toSet()
          .toList();
      anomalyDescription = '检测到：${anomalies.join('、')}';
    }

    final convergencePoints = manaField.flow.vortices
        .where((v) => v.isConverging && v.intensity > 0.3)
        .map((v) => v.location)
        .toList();

    String? flowDescription;
    if (manaField.flow.strength > 0.1) {
      flowDescription = '灵气流动，方向${manaField.flow.direction}';
    }

    return ManaEnvironmentSense(
      perceivedDensity: perceivedDensity,
      dominantAttribute: manaField.ambientAttribute,
      suitableForCultivation: suitableForCultivation,
      hasAnomaly: hasAnomaly,
      anomalyDescription: anomalyDescription,
      flowDescription: flowDescription,
      convergencePoints: convergencePoints,
    );
  }

  /// Compute spatial context for the character.
  SpatialContext computeSpatialContext({
    required SceneModel scene,
    required BodyConstraints constraints,
    required String? characterLocation,
  }) {
    final reachableAreas = <String>[];
    final nearbyObstacles = <String>[];

    // Add subareas as reachable if mobility is sufficient
    if (constraints.mobility > 0.3) {
      for (final subarea in scene.spatialLayout.subareas) {
        reachableAreas.add(subarea.name);
      }
    }

    // Add entry points as reachable
    for (final entry in scene.spatialLayout.entryPoints) {
      reachableAreas.add(entry.direction);
    }

    // List nearby obstacles
    for (final obstacle in scene.spatialLayout.obstacles) {
      final distance = _estimateDistance(characterLocation, obstacle.location);
      if (distance < 5.0) {
        nearbyObstacles.add(obstacle.type.label);
      }
    }

    return SpatialContext(
      reachableAreas: reachableAreas,
      nearbyObstacles: nearbyObstacles,
    );
  }

  // === Private helper methods ===

  double _calculateVisibilityScore({
    required SceneEntity entity,
    required LightingState lighting,
    required SensoryCapability vision,
    required List<Obstacle> obstacles,
    required String? observerLocation,
  }) {
    // Base visibility from lighting
    final lightingFactor = _lightingVisibilityFactor(lighting.overallLevel);

    // Distance decay
    final distance = _estimateDistance(observerLocation, entity.location);
    final distanceFactor = _visionDistanceDecay(distance);

    // Obstacle blocking
    final obstacleFactor = _computeObstacleFactor(obstacles, observerLocation, entity.location);

    // Final visibility
    return (vision.acuity * lightingFactor * distanceFactor * obstacleFactor).clamp(0.0, 1.0);
  }

  double _lightingVisibilityFactor(LightingLevel level) {
    return switch (level) {
      LightingLevel.bright => 1.0,
      LightingLevel.normal => 0.9,
      LightingLevel.dim => 0.6,
      LightingLevel.veryDim => 0.3,
      LightingLevel.dark => 0.1,
    };
  }

  double _visionDistanceDecay(double distance) {
    // Vision decays with distance: 1/(1 + 0.1*d)
    return 1.0 / (1.0 + distance * 0.1);
  }

  double _soundDistanceDecay(double distance) {
    // Sound decays with distance: 1/(1 + 0.05*d)
    return 1.0 / (1.0 + distance * 0.05);
  }

  double _odorDistanceDecay(double distance, double spreadRange) {
    // Odor decays with distance, modified by spread range
    final normalizedDistance = distance / spreadRange.clamp(0.1, 10.0);
    return 1.0 / (1.0 + normalizedDistance * 0.3);
  }

  double _manaDistanceDecay(double distance, double rangeModifier) {
    // Mana sensing decays with distance, modified by range
    final normalizedDistance = distance / rangeModifier.clamp(0.1, 10.0);
    return 1.0 / (1.0 + normalizedDistance * 0.05);
  }

  double _acousticsPropagationFactor(AcousticsState acoustics) {
    return switch (acoustics.reflectiveQuality) {
      ReflectiveQuality.open => 0.9,
      ReflectiveQuality.muffled => 0.6,
      ReflectiveQuality.echoing => 1.1,
      ReflectiveQuality.enclosed => 0.8,
      ReflectiveQuality.mixed => 0.9,
    };
  }

  double _odorAirflowFactor(Airflow airflow, String? observerLocation, String sourceLocation) {
    // Airflow strength affects odor propagation
    return switch (airflow.strength) {
      AirflowStrength.still => 0.6,
      AirflowStrength.weak => 0.8,
      AirflowStrength.flowing => 1.0,
      AirflowStrength.gusty => 1.2,
      AirflowStrength.variable => 0.9,
    };
  }

  double _odorFreshnessFactor(OdorFreshness freshness) {
    return switch (freshness) {
      OdorFreshness.fresh => 1.0,
      OdorFreshness.recent => 0.8,
      OdorFreshness.old => 0.4,
      OdorFreshness.unknown => 0.6,
    };
  }

  double _computeObstacleFactor(List<Obstacle> obstacles, String? observerLocation, String targetLocation) {
    // Check if any obstacle blocks line of sight
    for (final obstacle in obstacles) {
      if (obstacle.blocksVision) {
        // Simple check: if obstacle is between observer and target
        final observerDist = _estimateDistance(observerLocation, obstacle.location);
        final targetDist = _estimateDistance(obstacle.location, targetLocation);
        final directDist = _estimateDistance(observerLocation, targetLocation);

        // If obstacle is roughly between, reduce visibility
        if (observerDist + targetDist < directDist * 1.3) {
          return 0.1; // Mostly blocked
        }
      }
    }
    return 1.0;
  }

  double _computeInterferenceFactor({
    required List<ManaInterference> interferences,
    required String sourceLocation,
    required String? observerLocation,
    required double penetration,
  }) {
    var factor = 1.0;

    for (final interference in interferences) {
      final distance = _estimateDistance(observerLocation, interference.affectedArea);
      if (distance < 5.0) {
        final strength = interference.strength * (1.0 - penetration);
        factor *= switch (interference.type) {
          InterferenceType.shielding => 1.0 - strength * 0.8,
          InterferenceType.scrambling => 1.0 - strength * 0.5,
          InterferenceType.masking => 1.0 - strength * 0.6,
          InterferenceType.amplifying => 1.0 + strength * 0.3,
          InterferenceType.redirecting => 1.0 - strength * 0.4,
        };
      }
    }

    return factor.clamp(0.0, 2.0);
  }

  double _computeAttributeFactor({
    required ManaAttribute sourceAttribute,
    required Map<ManaAttribute, double> sensitivity,
  }) {
    if (sensitivity.isEmpty) return 1.0;
    return sensitivity[sourceAttribute] ?? 0.8;
  }

  double _manaThresholdByType(ManaSourceType type, ManaFreshness freshness) {
    final baseThreshold = switch (type) {
      ManaSourceType.spiritVein => 0.05,
      ManaSourceType.cultivatorAura => 0.1,
      ManaSourceType.artifactAura => 0.15,
      ManaSourceType.spellResidue => 0.2,
      ManaSourceType.formationCore => 0.1,
      ManaSourceType.formationTrace => 0.25,
      ManaSourceType.corruption => 0.08,
      ManaSourceType.tribulation => 0.02,
      ManaSourceType.spiritBeastAura => 0.12,
      ManaSourceType.breakthrough => 0.05,
      _ => 0.15,
    };

    final freshnessModifier = switch (freshness) {
      ManaFreshness.active => 1.0,
      ManaFreshness.recent => 1.2,
      ManaFreshness.fading => 1.5,
      ManaFreshness.old => 2.0,
      ManaFreshness.ancient => 3.0,
    };

    return baseThreshold * freshnessModifier;
  }

  double _computeManaClarity({
    required double perceivedIntensity,
    required double stability,
    required double manaStability,
    required double interferenceFactor,
  }) {
    return (perceivedIntensity * stability * manaStability * interferenceFactor).clamp(0.0, 1.0);
  }

  ManaSignalInsight _interpretManaSignal({
    required ManaSource source,
    required double clarity,
  }) {
    String? estimatedRealm;
    String? estimatedTechnique;
    double threatLevel = 0.0;
    bool? isHostile;
    bool? isConcealed;

    // Estimate realm based on intensity
    if (source.type == ManaSourceType.cultivatorAura) {
      if (source.intensity > 1.5) {
        estimatedRealm = '高阶';
      } else if (source.intensity > 1.0) {
        estimatedRealm = '中阶';
      } else {
        estimatedRealm = '低阶';
      }
    }

    // Check for hostile intent
    if (source.attribute == ManaAttribute.corrupt ||
        source.type == ManaSourceType.tribulation) {
      isHostile = true;
      threatLevel = 0.8;
    }

    // Check for concealed aura
    if (source.type == ManaSourceType.cultivatorAura && source.stability < 0.5) {
      isConcealed = true;
    }

    return ManaSignalInsight(
      estimatedRealm: estimatedRealm,
      estimatedTechnique: estimatedTechnique,
      threatLevel: threatLevel,
      isHostile: isHostile,
      isConcealed: isConcealed,
    );
  }

  String _describeManaSource(ManaSource source, double perceivedIntensity) {
    final intensityDesc = perceivedIntensity > 1.0 ? '强烈' : perceivedIntensity > 0.5 ? '明显' : '微弱';
    return '$intensityDesc的${source.type.name}';
  }

  double _estimateDistance(String? location1, String? location2) {
    // Simple distance estimation based on location strings
    // In a real implementation, this would use actual coordinates
    if (location1 == null || location2 == null) return 1.0;
    if (location1 == location2) return 0.0;

    // Parse location strings like "x,y" or use hash difference
    try {
      final parts1 = location1.split(',');
      final parts2 = location2.split(',');
      if (parts1.length >= 2 && parts2.length >= 2) {
        final x1 = double.tryParse(parts1[0]) ?? 0.0;
        final y1 = double.tryParse(parts1[1]) ?? 0.0;
        final x2 = double.tryParse(parts2[0]) ?? 0.0;
        final y2 = double.tryParse(parts2[1]) ?? 0.0;
        return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
      }
    } catch (_) {}

    // Fallback: use string hash difference as proxy
    return ((location1.hashCode - location2.hashCode).abs() % 20).toDouble();
  }

  String _computeDirection(String? fromLocation, String? toLocation) {
    if (fromLocation == null || toLocation == null) return 'unknown';
    if (fromLocation == toLocation) return 'here';

    // Simple direction estimation
    try {
      final parts1 = fromLocation.split(',');
      final parts2 = toLocation.split(',');
      if (parts1.length >= 2 && parts2.length >= 2) {
        final x1 = double.tryParse(parts1[0]) ?? 0.0;
        final y1 = double.tryParse(parts1[1]) ?? 0.0;
        final x2 = double.tryParse(parts2[0]) ?? 0.0;
        final y2 = double.tryParse(parts2[1]) ?? 0.0;

        final dx = x2 - x1;
        final dy = y2 - y1;

        if (dx.abs() > dy.abs()) {
          return dx > 0 ? 'east' : 'west';
        } else {
          return dy > 0 ? 'north' : 'south';
        }
      }
    } catch (_) {}

    return 'unknown';
  }

  String _buildVisibilityNotes(double visibilityScore, LightingLevel lighting) {
    final notes = <String>[];
    if (visibilityScore < 0.3) notes.add('barely visible');
    if (lighting == LightingLevel.dark || lighting == LightingLevel.veryDim) notes.add('low light');
    return notes.join('; ');
  }

  String _buildManaSignalNotes(double intensity, double clarity, double interferenceFactor) {
    final notes = <String>[];
    if (clarity < 0.5) notes.add('unclear');
    if (interferenceFactor < 0.7) notes.add('interference detected');
    return notes.join('; ');
  }
}

// Simple sqrt function to avoid importing dart:math
double sqrt(double x) => x < 0 ? 0 : x == 0 ? 0 : _sqrtImpl(x);

double _sqrtImpl(double x) {
  // Newton's method for sqrt
  double guess = x / 2;
  for (int i = 0; i < 10; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
