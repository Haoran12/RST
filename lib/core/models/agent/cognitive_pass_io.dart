import 'filtered_scene_view.dart';
import 'memory_entry.dart';
import 'scene_model.dart';
import 'character_runtime_state.dart';
import 'embodiment_state.dart';
import 'temporary_body_state.dart';

// 揭示等级
enum RevealLevel {
  direct('direct', '直接'),
  guarded('guarded', '谨慎'),
  masked('masked', '掩饰'),
  deceptive('deceptive', '欺骗'),
  silent('silent', '沉默');

  const RevealLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

RevealLevel revealLevelFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'direct' => RevealLevel.direct,
    'guarded' => RevealLevel.guarded,
    'masked' => RevealLevel.masked,
    'deceptive' => RevealLevel.deceptive,
    'silent' => RevealLevel.silent,
    _ => RevealLevel.guarded,
  };
}

// 注意到的事实
class NoticedFact {
  const NoticedFact({
    required this.factId,
    required this.content,
    required this.sourceType,
    this.confidence = 1.0,
  });

  final String factId;
  final String content;
  final String sourceType;
  final double confidence;

  NoticedFact copyWith({
    String? factId,
    String? content,
    String? sourceType,
    double? confidence,
  }) {
    return NoticedFact(
      factId: factId ?? this.factId,
      content: content ?? this.content,
      sourceType: sourceType ?? this.sourceType,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'factId': factId,
      'content': content,
      'sourceType': sourceType,
      'confidence': confidence,
    };
  }

  factory NoticedFact.fromJson(Map<String, dynamic> json) {
    return NoticedFact(
      factId: '${json['factId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      sourceType: '${json['sourceType'] ?? ''}',
      confidence: _parseDouble(json['confidence']) ?? 1.0,
    );
  }
}

// 未注意但可观察
class UnnoticedButObservable {
  const UnnoticedButObservable({
    required this.observableId,
    required this.content,
    required this.reason,
  });

  final String observableId;
  final String content;
  final String reason;

  UnnoticedButObservable copyWith({
    String? observableId,
    String? content,
    String? reason,
  }) {
    return UnnoticedButObservable(
      observableId: observableId ?? this.observableId,
      content: content ?? this.content,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'observableId': observableId,
      'content': content,
      'reason': reason,
    };
  }

  factory UnnoticedButObservable.fromJson(Map<String, dynamic> json) {
    return UnnoticedButObservable(
      observableId: '${json['observableId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
    );
  }
}

// 模糊信号
class AmbiguousSignal {
  const AmbiguousSignal({
    required this.signalId,
    required this.content,
    required this.possibleInterpretations,
  });

  final String signalId;
  final String content;
  final List<String> possibleInterpretations;

  AmbiguousSignal copyWith({
    String? signalId,
    String? content,
    List<String>? possibleInterpretations,
  }) {
    return AmbiguousSignal(
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      possibleInterpretations: possibleInterpretations ?? this.possibleInterpretations,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'signalId': signalId,
      'content': content,
      'possibleInterpretations': possibleInterpretations,
    };
  }

  factory AmbiguousSignal.fromJson(Map<String, dynamic> json) {
    return AmbiguousSignal(
      signalId: '${json['signalId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      possibleInterpretations: _parseStringList(json['possibleInterpretations']),
    );
  }
}

// 主观印象
class SubjectiveImpression {
  const SubjectiveImpression({
    required this.impressionId,
    required this.targetEntityId,
    required this.impression,
    required this.basis,
  });

  final String impressionId;
  final String targetEntityId;
  final String impression;
  final String basis;

  SubjectiveImpression copyWith({
    String? impressionId,
    String? targetEntityId,
    String? impression,
    String? basis,
  }) {
    return SubjectiveImpression(
      impressionId: impressionId ?? this.impressionId,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      impression: impression ?? this.impression,
      basis: basis ?? this.basis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'impressionId': impressionId,
      'targetEntityId': targetEntityId,
      'impression': impression,
      'basis': basis,
    };
  }

  factory SubjectiveImpression.fromJson(Map<String, dynamic> json) {
    return SubjectiveImpression(
      impressionId: '${json['impressionId'] ?? ''}',
      targetEntityId: '${json['targetEntityId'] ?? ''}',
      impression: '${json['impression'] ?? ''}',
      basis: '${json['basis'] ?? ''}',
    );
  }
}

// 情感着色
class AffectiveColoring {
  const AffectiveColoring({
    required this.targetId,
    required this.emotion,
    required this.intensity,
  });

  final String targetId;
  final String emotion;
  final double intensity;

  AffectiveColoring copyWith({
    String? targetId,
    String? emotion,
    double? intensity,
  }) {
    return AffectiveColoring(
      targetId: targetId ?? this.targetId,
      emotion: emotion ?? this.emotion,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetId': targetId,
      'emotion': emotion,
      'intensity': intensity,
    };
  }

  factory AffectiveColoring.fromJson(Map<String, dynamic> json) {
    return AffectiveColoring(
      targetId: '${json['targetId'] ?? ''}',
      emotion: '${json['emotion'] ?? ''}',
      intensity: _parseDouble(json['intensity']) ?? 0.0,
    );
  }
}

// 记忆激活
class MemoryActivation {
  const MemoryActivation({
    required this.memoryId,
    required this.activationReason,
    required this.relevanceScore,
  });

  final String memoryId;
  final String activationReason;
  final double relevanceScore;

  MemoryActivation copyWith({
    String? memoryId,
    String? activationReason,
    double? relevanceScore,
  }) {
    return MemoryActivation(
      memoryId: memoryId ?? this.memoryId,
      activationReason: activationReason ?? this.activationReason,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'memoryId': memoryId,
      'activationReason': activationReason,
      'relevanceScore': relevanceScore,
    };
  }

  factory MemoryActivation.fromJson(Map<String, dynamic> json) {
    return MemoryActivation(
      memoryId: '${json['memoryId'] ?? ''}',
      activationReason: '${json['activationReason'] ?? ''}',
      relevanceScore: _parseDouble(json['relevanceScore']) ?? 0.0,
    );
  }
}

// 感知增量
class PerceptionDelta {
  const PerceptionDelta({
    this.noticedFacts = const [],
    this.unnoticedButObservable = const [],
    this.ambiguousSignals = const [],
    this.subjectiveImpressions = const [],
    this.affectiveColoring = const [],
    this.memoryActivations = const [],
    this.immediateConcerns = const [],
  });

  final List<NoticedFact> noticedFacts;
  final List<UnnoticedButObservable> unnoticedButObservable;
  final List<AmbiguousSignal> ambiguousSignals;
  final List<SubjectiveImpression> subjectiveImpressions;
  final List<AffectiveColoring> affectiveColoring;
  final List<MemoryActivation> memoryActivations;
  final List<String> immediateConcerns;

  PerceptionDelta copyWith({
    List<NoticedFact>? noticedFacts,
    List<UnnoticedButObservable>? unnoticedButObservable,
    List<AmbiguousSignal>? ambiguousSignals,
    List<SubjectiveImpression>? subjectiveImpressions,
    List<AffectiveColoring>? affectiveColoring,
    List<MemoryActivation>? memoryActivations,
    List<String>? immediateConcerns,
  }) {
    return PerceptionDelta(
      noticedFacts: noticedFacts ?? this.noticedFacts,
      unnoticedButObservable: unnoticedButObservable ?? this.unnoticedButObservable,
      ambiguousSignals: ambiguousSignals ?? this.ambiguousSignals,
      subjectiveImpressions: subjectiveImpressions ?? this.subjectiveImpressions,
      affectiveColoring: affectiveColoring ?? this.affectiveColoring,
      memoryActivations: memoryActivations ?? this.memoryActivations,
      immediateConcerns: immediateConcerns ?? this.immediateConcerns,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'noticedFacts': noticedFacts.map((e) => e.toJson()).toList(),
      'unnoticedButObservable': unnoticedButObservable.map((e) => e.toJson()).toList(),
      'ambiguousSignals': ambiguousSignals.map((e) => e.toJson()).toList(),
      'subjectiveImpressions': subjectiveImpressions.map((e) => e.toJson()).toList(),
      'affectiveColoring': affectiveColoring.map((e) => e.toJson()).toList(),
      'memoryActivations': memoryActivations.map((e) => e.toJson()).toList(),
      'immediateConcerns': immediateConcerns,
    };
  }

  factory PerceptionDelta.fromJson(Map<String, dynamic> json) {
    return PerceptionDelta(
      noticedFacts: _parseList(json['noticedFacts'], NoticedFact.fromJson),
      unnoticedButObservable: _parseList(json['unnoticedButObservable'], UnnoticedButObservable.fromJson),
      ambiguousSignals: _parseList(json['ambiguousSignals'], AmbiguousSignal.fromJson),
      subjectiveImpressions: _parseList(json['subjectiveImpressions'], SubjectiveImpression.fromJson),
      affectiveColoring: _parseList(json['affectiveColoring'], AffectiveColoring.fromJson),
      memoryActivations: _parseList(json['memoryActivations'], MemoryActivation.fromJson),
      immediateConcerns: _parseStringList(json['immediateConcerns']),
    );
  }
}

// 信念强化
class BeliefReinforced {
  const BeliefReinforced({
    required this.beliefId,
    required this.evidence,
    required this.newConfidence,
  });

  final String beliefId;
  final String evidence;
  final double newConfidence;

  BeliefReinforced copyWith({
    String? beliefId,
    String? evidence,
    double? newConfidence,
  }) {
    return BeliefReinforced(
      beliefId: beliefId ?? this.beliefId,
      evidence: evidence ?? this.evidence,
      newConfidence: newConfidence ?? this.newConfidence,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'beliefId': beliefId,
      'evidence': evidence,
      'newConfidence': newConfidence,
    };
  }

  factory BeliefReinforced.fromJson(Map<String, dynamic> json) {
    return BeliefReinforced(
      beliefId: '${json['beliefId'] ?? ''}',
      evidence: '${json['evidence'] ?? ''}',
      newConfidence: _parseDouble(json['newConfidence']) ?? 0.0,
    );
  }
}

// 信念削弱
class BeliefWeakened {
  const BeliefWeakened({
    required this.beliefId,
    required this.counterEvidence,
    required this.newConfidence,
  });

  final String beliefId;
  final String counterEvidence;
  final double newConfidence;

  BeliefWeakened copyWith({
    String? beliefId,
    String? counterEvidence,
    double? newConfidence,
  }) {
    return BeliefWeakened(
      beliefId: beliefId ?? this.beliefId,
      counterEvidence: counterEvidence ?? this.counterEvidence,
      newConfidence: newConfidence ?? this.newConfidence,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'beliefId': beliefId,
      'counterEvidence': counterEvidence,
      'newConfidence': newConfidence,
    };
  }

  factory BeliefWeakened.fromJson(Map<String, dynamic> json) {
    return BeliefWeakened(
      beliefId: '${json['beliefId'] ?? ''}',
      counterEvidence: '${json['counterEvidence'] ?? ''}',
      newConfidence: _parseDouble(json['newConfidence']) ?? 0.0,
    );
  }
}

// 新假设
class NewHypothesis {
  const NewHypothesis({
    required this.hypothesisId,
    required this.content,
    required this.prior,
    required this.basis,
  });

  final String hypothesisId;
  final String content;
  final double prior;
  final String basis;

  NewHypothesis copyWith({
    String? hypothesisId,
    String? content,
    double? prior,
    String? basis,
  }) {
    return NewHypothesis(
      hypothesisId: hypothesisId ?? this.hypothesisId,
      content: content ?? this.content,
      prior: prior ?? this.prior,
      basis: basis ?? this.basis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hypothesisId': hypothesisId,
      'content': content,
      'prior': prior,
      'basis': basis,
    };
  }

  factory NewHypothesis.fromJson(Map<String, dynamic> json) {
    return NewHypothesis(
      hypothesisId: '${json['hypothesisId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      prior: _parseDouble(json['prior']) ?? 0.5,
      basis: '${json['basis'] ?? ''}',
    );
  }
}

// 他人模型修订
class RevisedModelOfOther {
  const RevisedModelOfOther({
    required this.targetCharacterId,
    required this.aspect,
    required this.oldValue,
    required this.newValue,
    required this.reason,
  });

  final String targetCharacterId;
  final String aspect;
  final String oldValue;
  final String newValue;
  final String reason;

  RevisedModelOfOther copyWith({
    String? targetCharacterId,
    String? aspect,
    String? oldValue,
    String? newValue,
    String? reason,
  }) {
    return RevisedModelOfOther(
      targetCharacterId: targetCharacterId ?? this.targetCharacterId,
      aspect: aspect ?? this.aspect,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetCharacterId': targetCharacterId,
      'aspect': aspect,
      'oldValue': oldValue,
      'newValue': newValue,
      'reason': reason,
    };
  }

  factory RevisedModelOfOther.fromJson(Map<String, dynamic> json) {
    return RevisedModelOfOther(
      targetCharacterId: '${json['targetCharacterId'] ?? ''}',
      aspect: '${json['aspect'] ?? ''}',
      oldValue: '${json['oldValue'] ?? ''}',
      newValue: '${json['newValue'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
    );
  }
}

// 矛盾与张力
class ContradictionAndTension {
  const ContradictionAndTension({
    required this.description,
    required this.involvedBeliefs,
    required this.severity,
  });

  final String description;
  final List<String> involvedBeliefs;
  final double severity;

  ContradictionAndTension copyWith({
    String? description,
    List<String>? involvedBeliefs,
    double? severity,
  }) {
    return ContradictionAndTension(
      description: description ?? this.description,
      involvedBeliefs: involvedBeliefs ?? this.involvedBeliefs,
      severity: severity ?? this.severity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'involvedBeliefs': involvedBeliefs,
      'severity': severity,
    };
  }

  factory ContradictionAndTension.fromJson(Map<String, dynamic> json) {
    return ContradictionAndTension(
      description: '${json['description'] ?? ''}',
      involvedBeliefs: _parseStringList(json['involvedBeliefs']),
      severity: _parseDouble(json['severity']) ?? 0.0,
    );
  }
}

// 情感转变
class EmotionalShift {
  const EmotionalShift({
    required this.emotion,
    required this.oldIntensity,
    required this.newIntensity,
    required this.trigger,
  });

  final String emotion;
  final double oldIntensity;
  final double newIntensity;
  final String trigger;

  EmotionalShift copyWith({
    String? emotion,
    double? oldIntensity,
    double? newIntensity,
    String? trigger,
  }) {
    return EmotionalShift(
      emotion: emotion ?? this.emotion,
      oldIntensity: oldIntensity ?? this.oldIntensity,
      newIntensity: newIntensity ?? this.newIntensity,
      trigger: trigger ?? this.trigger,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotion': emotion,
      'oldIntensity': oldIntensity,
      'newIntensity': newIntensity,
      'trigger': trigger,
    };
  }

  factory EmotionalShift.fromJson(Map<String, dynamic> json) {
    return EmotionalShift(
      emotion: '${json['emotion'] ?? ''}',
      oldIntensity: _parseDouble(json['oldIntensity']) ?? 0.0,
      newIntensity: _parseDouble(json['newIntensity']) ?? 0.0,
      trigger: '${json['trigger'] ?? ''}',
    );
  }
}

// 信念更新
class BeliefUpdate {
  const BeliefUpdate({
    this.stableBeliefsReinforced = const [],
    this.stableBeliefsWeakened = const [],
    this.newHypotheses = const [],
    this.revisedModelsOfOthers = const [],
    this.contradictionsAndTension = const [],
    required this.emotionalShift,
    this.decisionRelevantBeliefs = const [],
  });

  final List<BeliefReinforced> stableBeliefsReinforced;
  final List<BeliefWeakened> stableBeliefsWeakened;
  final List<NewHypothesis> newHypotheses;
  final List<RevisedModelOfOther> revisedModelsOfOthers;
  final List<ContradictionAndTension> contradictionsAndTension;
  final EmotionalShift emotionalShift;
  final List<String> decisionRelevantBeliefs;

  BeliefUpdate copyWith({
    List<BeliefReinforced>? stableBeliefsReinforced,
    List<BeliefWeakened>? stableBeliefsWeakened,
    List<NewHypothesis>? newHypotheses,
    List<RevisedModelOfOther>? revisedModelsOfOthers,
    List<ContradictionAndTension>? contradictionsAndTension,
    EmotionalShift? emotionalShift,
    List<String>? decisionRelevantBeliefs,
  }) {
    return BeliefUpdate(
      stableBeliefsReinforced: stableBeliefsReinforced ?? this.stableBeliefsReinforced,
      stableBeliefsWeakened: stableBeliefsWeakened ?? this.stableBeliefsWeakened,
      newHypotheses: newHypotheses ?? this.newHypotheses,
      revisedModelsOfOthers: revisedModelsOfOthers ?? this.revisedModelsOfOthers,
      contradictionsAndTension: contradictionsAndTension ?? this.contradictionsAndTension,
      emotionalShift: emotionalShift ?? this.emotionalShift,
      decisionRelevantBeliefs: decisionRelevantBeliefs ?? this.decisionRelevantBeliefs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stableBeliefsReinforced': stableBeliefsReinforced.map((e) => e.toJson()).toList(),
      'stableBeliefsWeakened': stableBeliefsWeakened.map((e) => e.toJson()).toList(),
      'newHypotheses': newHypotheses.map((e) => e.toJson()).toList(),
      'revisedModelsOfOthers': revisedModelsOfOthers.map((e) => e.toJson()).toList(),
      'contradictionsAndTension': contradictionsAndTension.map((e) => e.toJson()).toList(),
      'emotionalShift': emotionalShift.toJson(),
      'decisionRelevantBeliefs': decisionRelevantBeliefs,
    };
  }

  factory BeliefUpdate.fromJson(Map<String, dynamic> json) {
    return BeliefUpdate(
      stableBeliefsReinforced: _parseList(json['stableBeliefsReinforced'], BeliefReinforced.fromJson),
      stableBeliefsWeakened: _parseList(json['stableBeliefsWeakened'], BeliefWeakened.fromJson),
      newHypotheses: _parseList(json['newHypotheses'], NewHypothesis.fromJson),
      revisedModelsOfOthers: _parseList(json['revisedModelsOfOthers'], RevisedModelOfOther.fromJson),
      contradictionsAndTension: _parseList(json['contradictionsAndTension'], ContradictionAndTension.fromJson),
      emotionalShift: EmotionalShift.fromJson(json['emotionalShift'] ?? <String, dynamic>{}),
      decisionRelevantBeliefs: _parseStringList(json['decisionRelevantBeliefs']),
    );
  }
}

// 压制的替代选项
class SuppressedAlternative {
  const SuppressedAlternative({
    required this.intent,
    required this.reason,
  });

  final String intent;
  final String reason;

  SuppressedAlternative copyWith({
    String? intent,
    String? reason,
  }) {
    return SuppressedAlternative(
      intent: intent ?? this.intent,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intent': intent,
      'reason': reason,
    };
  }

  factory SuppressedAlternative.fromJson(Map<String, dynamic> json) {
    return SuppressedAlternative(
      intent: '${json['intent'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
    );
  }
}

// 选定的意图
class SelectedIntent {
  const SelectedIntent({
    required this.intent,
    required this.reason,
    this.dependsOnBeliefs = const [],
    this.emotionalDriver = '',
    this.suppressedAlternatives = const [],
  });

  final String intent;
  final String reason;
  final List<String> dependsOnBeliefs;
  final String emotionalDriver;
  final List<SuppressedAlternative> suppressedAlternatives;

  SelectedIntent copyWith({
    String? intent,
    String? reason,
    List<String>? dependsOnBeliefs,
    String? emotionalDriver,
    List<SuppressedAlternative>? suppressedAlternatives,
  }) {
    return SelectedIntent(
      intent: intent ?? this.intent,
      reason: reason ?? this.reason,
      dependsOnBeliefs: dependsOnBeliefs ?? this.dependsOnBeliefs,
      emotionalDriver: emotionalDriver ?? this.emotionalDriver,
      suppressedAlternatives: suppressedAlternatives ?? this.suppressedAlternatives,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intent': intent,
      'reason': reason,
      'dependsOnBeliefs': dependsOnBeliefs,
      'emotionalDriver': emotionalDriver,
      'suppressedAlternatives': suppressedAlternatives.map((e) => e.toJson()).toList(),
    };
  }

  factory SelectedIntent.fromJson(Map<String, dynamic> json) {
    return SelectedIntent(
      intent: '${json['intent'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      dependsOnBeliefs: _parseStringList(json['dependsOnBeliefs']),
      emotionalDriver: '${json['emotionalDriver'] ?? ''}',
      suppressedAlternatives: _parseList(json['suppressedAlternatives'], SuppressedAlternative.fromJson),
    );
  }
}

// 表达约束
class ExpressionConstraints {
  const ExpressionConstraints({
    required this.revealLevel,
    this.tone = '',
    this.behavioralNotes = const [],
  });

  final RevealLevel revealLevel;
  final String tone;
  final List<String> behavioralNotes;

  ExpressionConstraints copyWith({
    RevealLevel? revealLevel,
    String? tone,
    List<String>? behavioralNotes,
  }) {
    return ExpressionConstraints(
      revealLevel: revealLevel ?? this.revealLevel,
      tone: tone ?? this.tone,
      behavioralNotes: behavioralNotes ?? this.behavioralNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'revealLevel': revealLevel.wireValue,
      'tone': tone,
      'behavioralNotes': behavioralNotes,
    };
  }

  factory ExpressionConstraints.fromJson(Map<String, dynamic> json) {
    return ExpressionConstraints(
      revealLevel: revealLevelFromWire(json['revealLevel']),
      tone: '${json['tone'] ?? ''}',
      behavioralNotes: _parseStringList(json['behavioralNotes']),
    );
  }
}

// 候选意图
class CandidateIntent {
  const CandidateIntent({
    required this.intentId,
    required this.description,
    required this.priority,
    this.feasibility = 1.0,
  });

  final String intentId;
  final String description;
  final double priority;
  final double feasibility;

  CandidateIntent copyWith({
    String? intentId,
    String? description,
    double? priority,
    double? feasibility,
  }) {
    return CandidateIntent(
      intentId: intentId ?? this.intentId,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      feasibility: feasibility ?? this.feasibility,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intentId': intentId,
      'description': description,
      'priority': priority,
      'feasibility': feasibility,
    };
  }

  factory CandidateIntent.fromJson(Map<String, dynamic> json) {
    return CandidateIntent(
      intentId: '${json['intentId'] ?? ''}',
      description: '${json['description'] ?? ''}',
      priority: _parseDouble(json['priority']) ?? 0.0,
      feasibility: _parseDouble(json['feasibility']) ?? 1.0,
    );
  }
}

// 决策框架
class DecisionFrame {
  const DecisionFrame({
    required this.context,
    required this.constraints,
    required this.timePressure,
  });

  final String context;
  final String constraints;
  final double timePressure;

  DecisionFrame copyWith({
    String? context,
    String? constraints,
    double? timePressure,
  }) {
    return DecisionFrame(
      context: context ?? this.context,
      constraints: constraints ?? this.constraints,
      timePressure: timePressure ?? this.timePressure,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'context': context,
      'constraints': constraints,
      'timePressure': timePressure,
    };
  }

  factory DecisionFrame.fromJson(Map<String, dynamic> json) {
    return DecisionFrame(
      context: '${json['context'] ?? ''}',
      constraints: '${json['constraints'] ?? ''}',
      timePressure: _parseDouble(json['timePressure']) ?? 0.0,
    );
  }
}

// 意图计划
class IntentPlan {
  const IntentPlan({
    required this.activeGoals,
    required this.decisionFrame,
    this.candidateIntents = const [],
    required this.selectedIntent,
    required this.expressionConstraints,
  });

  final CurrentGoals activeGoals;
  final DecisionFrame decisionFrame;
  final List<CandidateIntent> candidateIntents;
  final SelectedIntent selectedIntent;
  final ExpressionConstraints expressionConstraints;

  IntentPlan copyWith({
    CurrentGoals? activeGoals,
    DecisionFrame? decisionFrame,
    List<CandidateIntent>? candidateIntents,
    SelectedIntent? selectedIntent,
    ExpressionConstraints? expressionConstraints,
  }) {
    return IntentPlan(
      activeGoals: activeGoals ?? this.activeGoals,
      decisionFrame: decisionFrame ?? this.decisionFrame,
      candidateIntents: candidateIntents ?? this.candidateIntents,
      selectedIntent: selectedIntent ?? this.selectedIntent,
      expressionConstraints: expressionConstraints ?? this.expressionConstraints,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'activeGoals': activeGoals.toJson(),
      'decisionFrame': decisionFrame.toJson(),
      'candidateIntents': candidateIntents.map((e) => e.toJson()).toList(),
      'selectedIntent': selectedIntent.toJson(),
      'expressionConstraints': expressionConstraints.toJson(),
    };
  }

  factory IntentPlan.fromJson(Map<String, dynamic> json) {
    return IntentPlan(
      activeGoals: CurrentGoals.fromJson(json['activeGoals'] ?? <String, dynamic>{}),
      decisionFrame: DecisionFrame.fromJson(json['decisionFrame'] ?? <String, dynamic>{}),
      candidateIntents: _parseList(json['candidateIntents'], CandidateIntent.fromJson),
      selectedIntent: SelectedIntent.fromJson(json['selectedIntent'] ?? <String, dynamic>{}),
      expressionConstraints: ExpressionConstraints.fromJson(json['expressionConstraints'] ?? <String, dynamic>{}),
    );
  }
}

// 角色认知传递输入
class CharacterCognitivePassInput {
  const CharacterCognitivePassInput({
    required this.characterId,
    required this.sceneTurnId,
    required this.filteredSceneView,
    required this.embodimentState,
    required this.bodyState,
    this.accessibleMemories = const [],
    required this.priorBeliefState,
    this.relationModels = const {},
    required this.emotionState,
    required this.currentGoals,
    this.recentEventDelta = const [],
  });

  final String characterId;
  final String sceneTurnId;
  final FilteredSceneView filteredSceneView;
  final EmbodimentState embodimentState;
  final TemporaryBodyState bodyState;
  final List<MemoryEntry> accessibleMemories;
  final BeliefState priorBeliefState;
  final Map<String, dynamic> relationModels;
  final EmotionState emotionState;
  final CurrentGoals currentGoals;
  final List<SceneEvent> recentEventDelta;

  CharacterCognitivePassInput copyWith({
    String? characterId,
    String? sceneTurnId,
    FilteredSceneView? filteredSceneView,
    EmbodimentState? embodimentState,
    TemporaryBodyState? bodyState,
    List<MemoryEntry>? accessibleMemories,
    BeliefState? priorBeliefState,
    Map<String, dynamic>? relationModels,
    EmotionState? emotionState,
    CurrentGoals? currentGoals,
    List<SceneEvent>? recentEventDelta,
  }) {
    return CharacterCognitivePassInput(
      characterId: characterId ?? this.characterId,
      sceneTurnId: sceneTurnId ?? this.sceneTurnId,
      filteredSceneView: filteredSceneView ?? this.filteredSceneView,
      embodimentState: embodimentState ?? this.embodimentState,
      bodyState: bodyState ?? this.bodyState,
      accessibleMemories: accessibleMemories ?? this.accessibleMemories,
      priorBeliefState: priorBeliefState ?? this.priorBeliefState,
      relationModels: relationModels ?? this.relationModels,
      emotionState: emotionState ?? this.emotionState,
      currentGoals: currentGoals ?? this.currentGoals,
      recentEventDelta: recentEventDelta ?? this.recentEventDelta,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'sceneTurnId': sceneTurnId,
      'filteredSceneView': filteredSceneView.toJson(),
      'embodimentState': embodimentState.toJson(),
      'bodyState': bodyState.toJson(),
      'accessibleMemories': accessibleMemories.map((e) => e.toJson()).toList(),
      'priorBeliefState': priorBeliefState.toJson(),
      'relationModels': relationModels,
      'emotionState': emotionState.toJson(),
      'currentGoals': currentGoals.toJson(),
      'recentEventDelta': recentEventDelta.map((e) => e.toJson()).toList(),
    };
  }

  factory CharacterCognitivePassInput.fromJson(Map<String, dynamic> json) {
    return CharacterCognitivePassInput(
      characterId: '${json['characterId'] ?? ''}',
      sceneTurnId: '${json['sceneTurnId'] ?? ''}',
      filteredSceneView: FilteredSceneView.fromJson(json['filteredSceneView'] ?? <String, dynamic>{}),
      embodimentState: EmbodimentState.fromJson(json['embodimentState'] ?? <String, dynamic>{}),
      bodyState: TemporaryBodyState.fromJson(json['bodyState'] ?? <String, dynamic>{}),
      accessibleMemories: _parseList(json['accessibleMemories'], MemoryEntry.fromJson),
      priorBeliefState: BeliefState.fromJson(json['priorBeliefState'] ?? <String, dynamic>{}),
      relationModels: Map<String, dynamic>.from(json['relationModels'] ?? <String, dynamic>{}),
      emotionState: EmotionState.fromJson(json['emotionState'] ?? <String, dynamic>{}),
      currentGoals: CurrentGoals.fromJson(json['currentGoals'] ?? <String, dynamic>{}),
      recentEventDelta: _parseList(json['recentEventDelta'], SceneEvent.fromJson),
    );
  }
}

// 角色认知传递输出
class CharacterCognitivePassOutput {
  const CharacterCognitivePassOutput({
    required this.characterId,
    required this.sceneTurnId,
    required this.perceptionDelta,
    required this.beliefUpdate,
    required this.intentPlan,
  });

  final String characterId;
  final String sceneTurnId;
  final PerceptionDelta perceptionDelta;
  final BeliefUpdate beliefUpdate;
  final IntentPlan intentPlan;

  CharacterCognitivePassOutput copyWith({
    String? characterId,
    String? sceneTurnId,
    PerceptionDelta? perceptionDelta,
    BeliefUpdate? beliefUpdate,
    IntentPlan? intentPlan,
  }) {
    return CharacterCognitivePassOutput(
      characterId: characterId ?? this.characterId,
      sceneTurnId: sceneTurnId ?? this.sceneTurnId,
      perceptionDelta: perceptionDelta ?? this.perceptionDelta,
      beliefUpdate: beliefUpdate ?? this.beliefUpdate,
      intentPlan: intentPlan ?? this.intentPlan,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'sceneTurnId': sceneTurnId,
      'perceptionDelta': perceptionDelta.toJson(),
      'beliefUpdate': beliefUpdate.toJson(),
      'intentPlan': intentPlan.toJson(),
    };
  }

  factory CharacterCognitivePassOutput.fromJson(Map<String, dynamic> json) {
    return CharacterCognitivePassOutput(
      characterId: '${json['characterId'] ?? ''}',
      sceneTurnId: '${json['sceneTurnId'] ?? ''}',
      perceptionDelta: PerceptionDelta.fromJson(json['perceptionDelta'] ?? <String, dynamic>{}),
      beliefUpdate: BeliefUpdate.fromJson(json['beliefUpdate'] ?? <String, dynamic>{}),
      intentPlan: IntentPlan.fromJson(json['intentPlan'] ?? <String, dynamic>{}),
    );
  }
}

// Helper functions
double? _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
