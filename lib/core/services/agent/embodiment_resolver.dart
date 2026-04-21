import '../../models/agent/baseline_body_profile.dart';
import '../../models/agent/embodiment_state.dart';
import '../../models/agent/mana_field.dart';
import '../../models/agent/scene_model.dart';
import '../../models/agent/temporary_body_state.dart';

/// Request for resolving embodiment state.
class EmbodimentResolveRequest {
  const EmbodimentResolveRequest({
    required this.characterId,
    required this.sceneTurnId,
    required this.baselineProfile,
    required this.temporaryState,
    required this.scene,
    this.characterLocation,
  });

  final String characterId;
  final String sceneTurnId;
  final BaselineBodyProfile baselineProfile;
  final TemporaryBodyState temporaryState;
  final SceneModel scene;
  final String? characterLocation;
}

/// Resolves a character's embodiment state based on baseline profile and temporary conditions.
///
/// This is a pure programmatic service that computes:
/// - Sensory capabilities (vision, hearing, smell, touch, proprioception, mana)
/// - Body constraints (mobility, balance, pain load, fatigue, cognitive clarity)
/// - Salience modifiers (attention pulls, aversion triggers, overload risks)
/// - Reasoning modifiers (cognitive clarity, pain bias, threat bias, overload bias)
/// - Action feasibility (physical execution, social patience, fine control, sustained attention)
class EmbodimentResolver {
  const EmbodimentResolver();

  /// Resolve complete embodiment state for a character in the scene.
  EmbodimentState resolve(EmbodimentResolveRequest request) {
    final sensoryCapabilities = computeSensoryCapabilities(
      baseline: request.baselineProfile,
      temporary: request.temporaryState,
      scene: request.scene,
    );

    final bodyConstraints = computeBodyConstraints(
      baseline: request.baselineProfile,
      temporary: request.temporaryState,
    );

    final salienceModifiers = computeSalienceModifiers(
      temporary: request.temporaryState,
    );

    final reasoningModifiers = computeReasoningModifiers(
      temporary: request.temporaryState,
      salience: salienceModifiers,
    );

    final actionFeasibility = computeActionFeasibility(
      constraints: bodyConstraints,
      temporary: request.temporaryState,
    );

    return EmbodimentState(
      characterId: request.characterId,
      sceneTurnId: request.sceneTurnId,
      sensoryCapabilities: sensoryCapabilities,
      bodyConstraints: bodyConstraints,
      salienceModifiers: salienceModifiers,
      reasoningModifiers: reasoningModifiers,
      actionFeasibility: actionFeasibility,
    );
  }

  /// Compute sensory capabilities considering all modifiers.
  SensoryCapabilities computeSensoryCapabilities({
    required BaselineBodyProfile baseline,
    required TemporaryBodyState temporary,
    required SceneModel scene,
  }) {
    final vision = _computeVisionCapability(
      baseline: baseline.sensoryBaseline.vision,
      temporary: temporary,
      lighting: scene.lighting,
    );

    final hearing = _computeHearingCapability(
      baseline: baseline.sensoryBaseline.hearing,
      temporary: temporary,
      acoustics: scene.acoustics,
    );

    final smell = _computeSmellCapability(
      baseline: baseline.sensoryBaseline.smell,
      temporary: temporary,
      olfactoryField: scene.olfactoryField,
    );

    final touch = _computeTouchCapability(
      baseline: baseline.sensoryBaseline.touch,
      temporary: temporary,
    );

    final proprioception = _computeProprioceptionCapability(
      baseline: baseline.sensoryBaseline.proprioception,
      temporary: temporary,
    );

    final mana = _computeManaCapability(
      baseline: baseline.manaSensoryBaseline,
      temporary: temporary,
      manaField: scene.manaField,
    );

    return SensoryCapabilities(
      vision: vision,
      hearing: hearing,
      smell: smell,
      touch: touch,
      proprioception: proprioception,
      mana: mana,
    );
  }

  /// Compute body constraints from baseline and temporary state.
  BodyConstraints computeBodyConstraints({
    required BaselineBodyProfile baseline,
    required TemporaryBodyState temporary,
  }) {
    // Mobility: baseline * injury penalty * fatigue penalty
    // Consider injuries that affect mobility: leg, foot, full_body, spine
    final mobilityInjuryPenalty = _computeMobilityInjuryPenalty(temporary.injuries);
    final mobility = (baseline.motorBaseline.mobility * (1 - mobilityInjuryPenalty) * (1 - temporary.fatigue * 0.3))
        .clamp(0.0, 1.0);

    // Balance: baseline * dizziness * leg injury penalty
    final legInjuryPenalty = _computeInjuryPenalty(temporary.injuries, 'leg');
    final balance = (baseline.motorBaseline.balance * (1 - temporary.dizziness * 0.5) * (1 - legInjuryPenalty * 0.5))
        .clamp(0.0, 1.0);

    // Pain load: aggregate pain from injuries + temporary pain level
    final painFromInjuries = temporary.injuries.fold(0.0, (sum, injury) => sum + injury.pain);
    final painLoad = (painFromInjuries + temporary.painLevel).clamp(0.0, 1.0);

    // Fatigue: direct from temporary state
    final fatigue = temporary.fatigue.clamp(0.0, 1.0);

    // Cognitive clarity: computed by TemporaryBodyState
    final cognitiveClarity = temporary.cognitiveClarity;

    return BodyConstraints(
      mobility: mobility,
      balance: balance,
      painLoad: painLoad,
      fatigue: fatigue,
      cognitiveClarity: cognitiveClarity,
    );
  }

  /// Compute salience modifiers based on pain and emotional state.
  SalienceModifiers computeSalienceModifiers({
    required TemporaryBodyState temporary,
  }) {
    final attentionPulls = <AttentionPull>[];
    final aversionTriggers = <AversionTrigger>[];
    final overloadRisks = <String>[];

    // Pain creates attention pull and aversion
    if (temporary.painLevel > 0.3) {
      attentionPulls.add(AttentionPull(
        stimulusType: 'pain',
        modifier: 1.0 + temporary.painLevel,
        reason: 'High pain level demands attention',
      ));
    }

    // Dizziness creates overload risk
    if (temporary.dizziness > 0.5) {
      overloadRisks.add('sensory_overload');
    }

    // Blood loss creates attention pull
    if (temporary.bloodLoss > 0.2) {
      attentionPulls.add(AttentionPull(
        stimulusType: 'blood_loss',
        modifier: 1.0 + temporary.bloodLoss,
        reason: 'Blood loss affects consciousness',
      ));
    }

    // Mana depletion creates attention pull for cultivators
    if (temporary.manaDepletion != null && temporary.manaDepletion! > 0.5) {
      attentionPulls.add(AttentionPull(
        stimulusType: 'mana_depletion',
        modifier: 1.0 + temporary.manaDepletion! * 0.5,
        reason: 'Severe mana depletion',
      ));
    }

    // Soul damage creates aversion and overload
    if (temporary.soulDamage > 0.3) {
      aversionTriggers.add(AversionTrigger(
        stimulusType: 'soul_strain',
        modifier: 1.0 + temporary.soulDamage,
        reason: 'Soul damage causes aversion to spiritual stimuli',
      ));
      overloadRisks.add('spiritual_overload');
    }

    return SalienceModifiers(
      attentionPull: attentionPulls,
      aversionTriggers: aversionTriggers,
      overloadRisks: overloadRisks,
    );
  }

  /// Compute reasoning modifiers from cognitive state.
  ReasoningModifiers computeReasoningModifiers({
    required TemporaryBodyState temporary,
    required SalienceModifiers salience,
  }) {
    // Cognitive clarity: from temporary state
    final cognitiveClarity = temporary.cognitiveClarity;

    // Pain bias: pain shifts reasoning toward threat detection
    final painBias = (temporary.painLevel * 0.5 + temporary.bloodLoss * 0.3).clamp(0.0, 1.0);

    // Threat bias: based on overload risks
    final threatBias = (salience.overloadRisks.length * 0.2).clamp(0.0, 1.0);

    // Overload bias: from dizziness and sensory overload
    final overloadBias = (temporary.dizziness * 0.5 + temporary.emotionalArousalBodyEffect * 0.3).clamp(0.0, 1.0);

    return ReasoningModifiers(
      cognitiveClarity: cognitiveClarity,
      painBias: painBias,
      threatBias: threatBias,
      overloadBias: overloadBias,
    );
  }

  /// Compute action feasibility from physical state.
  ActionFeasibility computeActionFeasibility({
    required BodyConstraints constraints,
    required TemporaryBodyState temporary,
  }) {
    // Physical execution capacity: mobility * cognitive clarity * (1 - pain impact)
    final physicalExecutionCapacity = (constraints.mobility * constraints.cognitiveClarity * (1 - constraints.painLoad * 0.3))
        .clamp(0.0, 1.0);

    // Social patience: reduced by pain and fatigue
    final socialPatience = ((1 - constraints.painLoad * 0.4) * (1 - constraints.fatigue * 0.3))
        .clamp(0.0, 1.0);

    // Fine control: reduced by dizziness and hand/arm injuries
    final handInjuryPenalty = _computeInjuryPenalty(temporary.injuries, 'hand');
    final fineControl = ((1 - temporary.dizziness * 0.5) * (1 - handInjuryPenalty * 0.6))
        .clamp(0.0, 1.0);

    // Sustained attention: cognitive clarity * (1 - fatigue)
    final sustainedAttention = (constraints.cognitiveClarity * (1 - constraints.fatigue * 0.5))
        .clamp(0.0, 1.0);

    return ActionFeasibility(
      physicalExecutionCapacity: physicalExecutionCapacity,
      socialPatience: socialPatience,
      fineControl: fineControl,
      sustainedAttention: sustainedAttention,
    );
  }

  // === Private helper methods ===

  SensoryCapability _computeVisionCapability({
    required double baseline,
    required TemporaryBodyState temporary,
    required LightingState lighting,
  }) {
    // Availability: blocked or not
    var availability = temporary.sensoryBlocks.visionBlocked ? 0.0 : 1.0;

    // Acuity: baseline * cognitive clarity * lighting factor
    final lightingFactor = _lightingFactor(lighting.overallLevel);
    final acuity = (baseline * temporary.cognitiveClarity * lightingFactor).clamp(0.0, 2.0);

    // Stability: reduced by dizziness
    final stability = (1.0 - temporary.dizziness * 0.5).clamp(0.0, 1.0);

    // Build notes
    final notes = <String>[];
    if (temporary.sensoryBlocks.visionBlocked) notes.add('vision blocked');
    if (lightingFactor < 0.5) notes.add('low light');
    if (temporary.dizziness > 0.3) notes.add('dizzy');

    return SensoryCapability(
      availability: availability,
      acuity: acuity,
      stability: stability,
      notes: notes.join('; '),
    );
  }

  SensoryCapability _computeHearingCapability({
    required double baseline,
    required TemporaryBodyState temporary,
    required AcousticsState acoustics,
  }) {
    // Availability
    var availability = temporary.sensoryBlocks.hearingBlocked ? 0.0 : 1.0;

    // Acuity: baseline * cognitive clarity * acoustics factor
    final acousticsFactor = _acousticsFactor(acoustics);
    final acuity = (baseline * temporary.cognitiveClarity * acousticsFactor).clamp(0.0, 2.0);

    // Stability: reduced by dizziness
    final stability = (1.0 - temporary.dizziness * 0.3).clamp(0.0, 1.0);

    final notes = <String>[];
    if (temporary.sensoryBlocks.hearingBlocked) notes.add('hearing blocked');
    if (acoustics.ambientNoiseLevel > 0.7) notes.add('high ambient noise');

    return SensoryCapability(
      availability: availability,
      acuity: acuity,
      stability: stability,
      notes: notes.join('; '),
    );
  }

  SensoryCapability _computeSmellCapability({
    required double baseline,
    required TemporaryBodyState temporary,
    required OlfactoryField olfactoryField,
  }) {
    // Availability
    var availability = temporary.sensoryBlocks.smellBlocked ? 0.0 : 1.0;

    // Acuity: baseline * cognitive clarity * airflow factor
    final airflowFactor = _airflowFactor(olfactoryField.airflow);
    final acuity = (baseline * temporary.cognitiveClarity * airflowFactor).clamp(0.0, 2.0);

    // Stability: reduced by illness
    final stability = (1.0 - (temporary.illness.isNotEmpty ? 0.3 : 0.0)).clamp(0.0, 1.0);

    final notes = <String>[];
    if (temporary.sensoryBlocks.smellBlocked) notes.add('smell blocked');
    if (temporary.illness.isNotEmpty) notes.add('illness affects smell');

    return SensoryCapability(
      availability: availability,
      acuity: acuity,
      stability: stability,
      notes: notes.join('; '),
    );
  }

  SensoryCapability _computeTouchCapability({
    required double baseline,
    required TemporaryBodyState temporary,
  }) {
    // Touch is always available unless severely injured
    final availability = temporary.bloodLoss > 0.7 ? 0.5 : 1.0;

    // Acuity: baseline * cognitive clarity
    final acuity = (baseline * temporary.cognitiveClarity).clamp(0.0, 2.0);

    // Stability: reduced by dizziness
    final stability = (1.0 - temporary.dizziness * 0.3).clamp(0.0, 1.0);

    return SensoryCapability(
      availability: availability,
      acuity: acuity,
      stability: stability,
      notes: '',
    );
  }

  SensoryCapability _computeProprioceptionCapability({
    required double baseline,
    required TemporaryBodyState temporary,
  }) {
    // Proprioception availability
    final availability = 1.0;

    // Acuity: baseline * cognitive clarity * (1 - dizziness)
    final acuity = (baseline * temporary.cognitiveClarity * (1 - temporary.dizziness * 0.5)).clamp(0.0, 2.0);

    // Stability: reduced by dizziness and fatigue
    final stability = ((1 - temporary.dizziness * 0.4) * (1 - temporary.fatigue * 0.2)).clamp(0.0, 1.0);

    return SensoryCapability(
      availability: availability,
      acuity: acuity,
      stability: stability,
      notes: '',
    );
  }

  ManaSensoryCapability _computeManaCapability({
    required ManaSensoryBaseline baseline,
    required TemporaryBodyState temporary,
    required ManaField? manaField,
  }) {
    // 1. Availability
    var availability = 1.0;
    if (temporary.sensoryBlocks.manaBlocked) {
      availability = 0.0;
    }
    availability *= temporary.cognitiveClarity;
    if (temporary.manaDepletion != null && temporary.manaDepletion! > 0.8) {
      availability *= (1.0 - temporary.manaDepletion! * 0.5);
    }

    // 2. Acuity: from baseline
    final acuity = baseline.effectiveAcuity;

    // 3. Stability: affected by cognitive clarity and mana field density
    var stability = 1.0;
    stability *= temporary.cognitiveClarity;
    if (manaField != null && manaField.ambientDensity > 1.0) {
      stability *= 1.0 / manaField.ambientDensity;
    }

    // 4. Range modifier: from baseline realm modifier
    final rangeModifier = baseline.realmModifier;

    // 5. Penetration: based on traits
    var penetration = 0.0;
    if (baseline.traits.contains(ManaSenseTrait.soulPerception)) {
      penetration = 0.5;
    }
    if (baseline.traits.contains(ManaSenseTrait.formationInsight)) {
      penetration = (penetration + 0.3).clamp(0.0, 1.0);
    }
    if (baseline.traits.contains(ManaSenseTrait.hiddenSense)) {
      penetration = (penetration + 0.2).clamp(0.0, 1.0);
    }

    // 6. Overload level: from high mana density
    var overloadLevel = 0.0;
    if (manaField != null && manaField.ambientDensity * acuity > 1.5) {
      overloadLevel = (manaField.ambientDensity * acuity - 1.5).clamp(0.0, 1.0);
    }

    // 7. Attribute sensitivity: from baseline affinity + temporary boost
    final attributeSensitivity = Map<ManaAttribute, double>.from(baseline.attributeAffinity);
    if (temporary.manaAttributeBoost != null) {
      attributeSensitivity[temporary.manaAttributeBoost!] =
          (attributeSensitivity[temporary.manaAttributeBoost!] ?? 1.0) + 0.5;
    }

    // 8. Build notes
    final notes = _buildManaNotes(availability, overloadLevel, baseline.traits);

    return ManaSensoryCapability(
      availability: availability.clamp(0.0, 1.0),
      acuity: acuity,
      stability: stability.clamp(0.0, 1.0),
      rangeModifier: rangeModifier,
      attributeSensitivity: attributeSensitivity,
      penetration: penetration,
      overloadLevel: overloadLevel,
      notes: notes,
    );
  }

  double _lightingFactor(LightingLevel level) {
    return switch (level) {
      LightingLevel.bright => 1.0,
      LightingLevel.normal => 0.9,
      LightingLevel.dim => 0.6,
      LightingLevel.veryDim => 0.3,
      LightingLevel.dark => 0.1,
    };
  }

  double _acousticsFactor(AcousticsState acoustics) {
    // High ambient noise reduces hearing effectiveness
    return (1.0 - acoustics.ambientNoiseLevel * 0.3).clamp(0.3, 1.0);
  }

  double _airflowFactor(Airflow airflow) {
    // Airflow helps smell propagation
    return switch (airflow.strength) {
      AirflowStrength.still => 0.7,
      AirflowStrength.weak => 0.9,
      AirflowStrength.flowing => 1.0,
      AirflowStrength.gusty => 1.1,
      AirflowStrength.variable => 0.9,
    };
  }

  double _computeInjuryPenalty(List<Injury> injuries, String partFilter) {
    double penalty = 0.0;
    for (final injury in injuries) {
      final partLower = injury.part.toLowerCase();
      final matches = partFilter.isEmpty ||
          partLower.contains(partFilter.toLowerCase()) ||
          partLower == 'full_body';
      if (matches) {
        penalty += injury.functionalPenalty;
      }
    }
    return penalty.clamp(0.0, 1.0);
  }

  /// Compute mobility penalty from injuries affecting movement.
  /// Considers: leg, foot, spine, hip, full_body
  double _computeMobilityInjuryPenalty(List<Injury> injuries) {
    const mobilityParts = {'leg', 'foot', 'feet', 'spine', 'hip', 'knee', 'ankle', 'thigh', 'full_body'};
    double penalty = 0.0;
    for (final injury in injuries) {
      final partLower = injury.part.toLowerCase();
      // Check if any mobility-related part is mentioned
      final affectsMobility = mobilityParts.any((part) => partLower.contains(part));
      if (affectsMobility) {
        penalty += injury.functionalPenalty;
      }
    }
    return penalty.clamp(0.0, 1.0);
  }

  String _buildManaNotes(double availability, double overloadLevel, List<ManaSenseTrait> traits) {
    final notes = <String>[];
    if (availability < 0.3) notes.add('mana sense impaired');
    if (overloadLevel > 0.5) notes.add('mana overload');
    if (traits.contains(ManaSenseTrait.soulPerception)) notes.add('soul perception');
    if (traits.isEmpty) notes.add('no special traits');
    return notes.join('; ');
  }
}
