// 脏标志
class DirtyFlags {
  const DirtyFlags({
    this.sceneChanged = false,
    this.bodyChanged = false,
    this.relationChanged = false,
    this.beliefInvalidated = false,
    this.intentInvalidated = false,
    this.directlyAddressed = false,
    this.underThreat = false,
    this.reactionWindowOpen = false,
    this.receivedNewSalientSignal = false,
  });

  final bool sceneChanged;
  final bool bodyChanged;
  final bool relationChanged;
  final bool beliefInvalidated;
  final bool intentInvalidated;
  final bool directlyAddressed;
  final bool underThreat;
  final bool reactionWindowOpen;
  final bool receivedNewSalientSignal;

  bool get isDirty =>
      sceneChanged ||
      bodyChanged ||
      relationChanged ||
      beliefInvalidated ||
      intentInvalidated ||
      directlyAddressed ||
      underThreat ||
      reactionWindowOpen ||
      receivedNewSalientSignal;

  DirtyFlags copyWith({
    bool? sceneChanged,
    bool? bodyChanged,
    bool? relationChanged,
    bool? beliefInvalidated,
    bool? intentInvalidated,
    bool? directlyAddressed,
    bool? underThreat,
    bool? reactionWindowOpen,
    bool? receivedNewSalientSignal,
  }) {
    return DirtyFlags(
      sceneChanged: sceneChanged ?? this.sceneChanged,
      bodyChanged: bodyChanged ?? this.bodyChanged,
      relationChanged: relationChanged ?? this.relationChanged,
      beliefInvalidated: beliefInvalidated ?? this.beliefInvalidated,
      intentInvalidated: intentInvalidated ?? this.intentInvalidated,
      directlyAddressed: directlyAddressed ?? this.directlyAddressed,
      underThreat: underThreat ?? this.underThreat,
      reactionWindowOpen: reactionWindowOpen ?? this.reactionWindowOpen,
      receivedNewSalientSignal: receivedNewSalientSignal ?? this.receivedNewSalientSignal,
    );
  }

  DirtyFlags reset() => const DirtyFlags();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sceneChanged': sceneChanged,
      'bodyChanged': bodyChanged,
      'relationChanged': relationChanged,
      'beliefInvalidated': beliefInvalidated,
      'intentInvalidated': intentInvalidated,
      'directlyAddressed': directlyAddressed,
      'underThreat': underThreat,
      'reactionWindowOpen': reactionWindowOpen,
      'receivedNewSalientSignal': receivedNewSalientSignal,
    };
  }

  factory DirtyFlags.fromJson(Map<String, dynamic> json) {
    return DirtyFlags(
      sceneChanged: _parseBool(json['sceneChanged']) ?? false,
      bodyChanged: _parseBool(json['bodyChanged']) ?? false,
      relationChanged: _parseBool(json['relationChanged']) ?? false,
      beliefInvalidated: _parseBool(json['beliefInvalidated']) ?? false,
      intentInvalidated: _parseBool(json['intentInvalidated']) ?? false,
      directlyAddressed: _parseBool(json['directlyAddressed']) ?? false,
      underThreat: _parseBool(json['underThreat']) ?? false,
      reactionWindowOpen: _parseBool(json['reactionWindowOpen']) ?? false,
      receivedNewSalientSignal: _parseBool(json['receivedNewSalientSignal']) ?? false,
    );
  }
}

bool? _parseBool(Object? raw) {
  if (raw is bool) return raw;
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}
