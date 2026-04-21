import 'baseline_body_profile.dart';
import 'temporary_body_state.dart';
import 'embodiment_state.dart';

// 角色档案
class CharacterProfile {
  const CharacterProfile({
    this.traits = const [],
    this.values = const [],
    this.cognitiveStyle = '',
    this.socialStyle = '',
  });

  final List<String> traits;
  final List<String> values;
  final String cognitiveStyle;
  final String socialStyle;

  CharacterProfile copyWith({
    List<String>? traits,
    List<String>? values,
    String? cognitiveStyle,
    String? socialStyle,
  }) {
    return CharacterProfile(
      traits: traits ?? this.traits,
      values: values ?? this.values,
      cognitiveStyle: cognitiveStyle ?? this.cognitiveStyle,
      socialStyle: socialStyle ?? this.socialStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'traits': traits,
      'values': values,
      'cognitiveStyle': cognitiveStyle,
      'socialStyle': socialStyle,
    };
  }

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    return CharacterProfile(
      traits: _parseStringList(json['traits']),
      values: _parseStringList(json['values']),
      cognitiveStyle: '${json['cognitiveStyle'] ?? ''}',
      socialStyle: '${json['socialStyle'] ?? ''}',
    );
  }
}

// 心智模型卡片
class MindModelCard {
  const MindModelCard({
    this.selfImage = '',
    this.worldview = const [],
    this.socialLogic = const [],
    this.fearTriggers = const [],
    this.defensePatterns = const [],
    this.desirePatterns = const [],
  });

  final String selfImage;
  final List<String> worldview;
  final List<String> socialLogic;
  final List<String> fearTriggers;
  final List<String> defensePatterns;
  final List<String> desirePatterns;

  MindModelCard copyWith({
    String? selfImage,
    List<String>? worldview,
    List<String>? socialLogic,
    List<String>? fearTriggers,
    List<String>? defensePatterns,
    List<String>? desirePatterns,
  }) {
    return MindModelCard(
      selfImage: selfImage ?? this.selfImage,
      worldview: worldview ?? this.worldview,
      socialLogic: socialLogic ?? this.socialLogic,
      fearTriggers: fearTriggers ?? this.fearTriggers,
      defensePatterns: defensePatterns ?? this.defensePatterns,
      desirePatterns: desirePatterns ?? this.desirePatterns,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selfImage': selfImage,
      'worldview': worldview,
      'socialLogic': socialLogic,
      'fearTriggers': fearTriggers,
      'defensePatterns': defensePatterns,
      'desirePatterns': desirePatterns,
    };
  }

  factory MindModelCard.fromJson(Map<String, dynamic> json) {
    return MindModelCard(
      selfImage: '${json['selfImage'] ?? ''}',
      worldview: _parseStringList(json['worldview']),
      socialLogic: _parseStringList(json['socialLogic']),
      fearTriggers: _parseStringList(json['fearTriggers']),
      defensePatterns: _parseStringList(json['defensePatterns']),
      desirePatterns: _parseStringList(json['desirePatterns']),
    );
  }
}

// 关系模型
class RelationModel {
  const RelationModel({
    required this.targetCharacterId,
    this.trust = 0.5,
    this.perceivedIntent = '',
    this.pastInteractions = '',
    this.additionalAttributes = const {},
  });

  final String targetCharacterId;
  final double trust;
  final String perceivedIntent;
  final String pastInteractions;
  final Map<String, dynamic> additionalAttributes;

  RelationModel copyWith({
    String? targetCharacterId,
    double? trust,
    String? perceivedIntent,
    String? pastInteractions,
    Map<String, dynamic>? additionalAttributes,
  }) {
    return RelationModel(
      targetCharacterId: targetCharacterId ?? this.targetCharacterId,
      trust: trust ?? this.trust,
      perceivedIntent: perceivedIntent ?? this.perceivedIntent,
      pastInteractions: pastInteractions ?? this.pastInteractions,
      additionalAttributes: additionalAttributes ?? this.additionalAttributes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetCharacterId': targetCharacterId,
      'trust': trust,
      'perceivedIntent': perceivedIntent,
      'pastInteractions': pastInteractions,
      'additionalAttributes': additionalAttributes,
    };
  }

  factory RelationModel.fromJson(Map<String, dynamic> json) {
    return RelationModel(
      targetCharacterId: '${json['targetCharacterId'] ?? ''}',
      trust: _parseDouble(json['trust']) ?? 0.5,
      perceivedIntent: '${json['perceivedIntent'] ?? ''}',
      pastInteractions: '${json['pastInteractions'] ?? ''}',
      additionalAttributes: Map<String, dynamic>.from(json['additionalAttributes'] ?? <String, dynamic>{}),
    );
  }
}

// 信念状态
class BeliefState {
  const BeliefState({
    this.beliefConfidences = const {},
    this.activeHypotheses = const [],
    this.currentHypothesis,
  });

  final Map<String, double> beliefConfidences;
  final List<String> activeHypotheses;
  final String? currentHypothesis;

  BeliefState copyWith({
    Map<String, double>? beliefConfidences,
    List<String>? activeHypotheses,
    String? currentHypothesis,
    bool clearCurrentHypothesis = false,
  }) {
    return BeliefState(
      beliefConfidences: beliefConfidences ?? this.beliefConfidences,
      activeHypotheses: activeHypotheses ?? this.activeHypotheses,
      currentHypothesis: clearCurrentHypothesis ? null : (currentHypothesis ?? this.currentHypothesis),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'beliefConfidences': beliefConfidences,
      'activeHypotheses': activeHypotheses,
      'currentHypothesis': currentHypothesis,
    };
  }

  factory BeliefState.fromJson(Map<String, dynamic> json) {
    final confidences = <String, double>{};
    final rawConfidences = json['beliefConfidences'];
    if (rawConfidences is Map) {
      rawConfidences.forEach((key, value) {
        final v = _parseDouble(value);
        if (v != null) {
          confidences['$key'] = v;
        }
      });
    }
    return BeliefState(
      beliefConfidences: confidences,
      activeHypotheses: _parseStringList(json['activeHypotheses']),
      currentHypothesis: _normalizeOptional(json['currentHypothesis']),
    );
  }
}

// 情绪状态
class EmotionState {
  const EmotionState({
    this.emotions = const {},
  });

  final Map<String, double> emotions;

  EmotionState copyWith({
    Map<String, double>? emotions,
  }) {
    return EmotionState(
      emotions: emotions ?? this.emotions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotions': emotions,
    };
  }

  factory EmotionState.fromJson(Map<String, dynamic> json) {
    final emotions = <String, double>{};
    final rawEmotions = json['emotions'];
    if (rawEmotions is Map) {
      rawEmotions.forEach((key, value) {
        final v = _parseDouble(value);
        if (v != null) {
          emotions['$key'] = v;
        }
      });
    }
    return EmotionState(emotions: emotions);
  }
}

// 当前目标
class CurrentGoals {
  const CurrentGoals({
    this.shortTerm = const [],
    this.mediumTerm = const [],
    this.hidden = const [],
  });

  final List<String> shortTerm;
  final List<String> mediumTerm;
  final List<String> hidden;

  CurrentGoals copyWith({
    List<String>? shortTerm,
    List<String>? mediumTerm,
    List<String>? hidden,
  }) {
    return CurrentGoals(
      shortTerm: shortTerm ?? this.shortTerm,
      mediumTerm: mediumTerm ?? this.mediumTerm,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shortTerm': shortTerm,
      'mediumTerm': mediumTerm,
      'hidden': hidden,
    };
  }

  factory CurrentGoals.fromJson(Map<String, dynamic> json) {
    return CurrentGoals(
      shortTerm: _parseStringList(json['shortTerm']),
      mediumTerm: _parseStringList(json['mediumTerm']),
      hidden: _parseStringList(json['hidden']),
    );
  }
}

// 角色运行时状态
class CharacterRuntimeState {
  const CharacterRuntimeState({
    required this.characterId,
    required this.profile,
    required this.mindModelCard,
    this.relationshipModels = const {},
    required this.beliefState,
    required this.emotionState,
    required this.baselineBodyProfile,
    required this.temporaryBodyState,
    this.currentEmbodimentState,
    required this.currentGoals,
    this.memoryIndexRefs = const [],
  });

  final String characterId;
  final CharacterProfile profile;
  final MindModelCard mindModelCard;
  final Map<String, RelationModel> relationshipModels;
  final BeliefState beliefState;
  final EmotionState emotionState;
  final BaselineBodyProfile baselineBodyProfile;
  final TemporaryBodyState temporaryBodyState;
  final EmbodimentState? currentEmbodimentState;
  final CurrentGoals currentGoals;
  final List<String> memoryIndexRefs;

  CharacterRuntimeState copyWith({
    String? characterId,
    CharacterProfile? profile,
    MindModelCard? mindModelCard,
    Map<String, RelationModel>? relationshipModels,
    BeliefState? beliefState,
    EmotionState? emotionState,
    BaselineBodyProfile? baselineBodyProfile,
    TemporaryBodyState? temporaryBodyState,
    EmbodimentState? currentEmbodimentState,
    bool clearCurrentEmbodimentState = false,
    CurrentGoals? currentGoals,
    List<String>? memoryIndexRefs,
  }) {
    return CharacterRuntimeState(
      characterId: characterId ?? this.characterId,
      profile: profile ?? this.profile,
      mindModelCard: mindModelCard ?? this.mindModelCard,
      relationshipModels: relationshipModels ?? this.relationshipModels,
      beliefState: beliefState ?? this.beliefState,
      emotionState: emotionState ?? this.emotionState,
      baselineBodyProfile: baselineBodyProfile ?? this.baselineBodyProfile,
      temporaryBodyState: temporaryBodyState ?? this.temporaryBodyState,
      currentEmbodimentState: clearCurrentEmbodimentState ? null : (currentEmbodimentState ?? this.currentEmbodimentState),
      currentGoals: currentGoals ?? this.currentGoals,
      memoryIndexRefs: memoryIndexRefs ?? this.memoryIndexRefs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'profile': profile.toJson(),
      'mindModelCard': mindModelCard.toJson(),
      'relationshipModels': relationshipModels.map((k, v) => MapEntry(k, v.toJson())),
      'beliefState': beliefState.toJson(),
      'emotionState': emotionState.toJson(),
      'baselineBodyProfile': baselineBodyProfile.toJson(),
      'temporaryBodyState': temporaryBodyState.toJson(),
      'currentEmbodimentState': currentEmbodimentState?.toJson(),
      'currentGoals': currentGoals.toJson(),
      'memoryIndexRefs': memoryIndexRefs,
    };
  }

  factory CharacterRuntimeState.fromJson(Map<String, dynamic> json) {
    final relationships = <String, RelationModel>{};
    final rawRelationships = json['relationshipModels'];
    if (rawRelationships is Map) {
      rawRelationships.forEach((key, value) {
        if (value is Map) {
          relationships['$key'] = RelationModel.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }
    return CharacterRuntimeState(
      characterId: '${json['characterId'] ?? ''}',
      profile: CharacterProfile.fromJson(json['profile'] ?? <String, dynamic>{}),
      mindModelCard: MindModelCard.fromJson(json['mindModelCard'] ?? <String, dynamic>{}),
      relationshipModels: relationships,
      beliefState: BeliefState.fromJson(json['beliefState'] ?? <String, dynamic>{}),
      emotionState: EmotionState.fromJson(json['emotionState'] ?? <String, dynamic>{}),
      baselineBodyProfile: BaselineBodyProfile.fromJson(json['baselineBodyProfile'] ?? <String, dynamic>{}),
      temporaryBodyState: TemporaryBodyState.fromJson(json['temporaryBodyState'] ?? <String, dynamic>{}),
      currentEmbodimentState: json['currentEmbodimentState'] != null
          ? EmbodimentState.fromJson(Map<String, dynamic>.from(json['currentEmbodimentState']))
          : null,
      currentGoals: CurrentGoals.fromJson(json['currentGoals'] ?? <String, dynamic>{}),
      memoryIndexRefs: _parseStringList(json['memoryIndexRefs']),
    );
  }
}

// Helper functions
String? _normalizeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') return null;
  return normalized;
}

double? _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
}
