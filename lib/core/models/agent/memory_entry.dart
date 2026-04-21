// 记忆可见性
enum MemoryVisibility {
  public('public', '公开'),
  private('private', '私有'),
  shared('shared', '共享');

  const MemoryVisibility(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

MemoryVisibility memoryVisibilityFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'public' => MemoryVisibility.public,
    'private' => MemoryVisibility.private,
    'shared' => MemoryVisibility.shared,
    _ => MemoryVisibility.private,
  };
}

// 记忆条目
class MemoryEntry {
  const MemoryEntry({
    required this.memoryId,
    required this.content,
    required this.ownerCharacterId,
    required this.knownBy,
    required this.visibility,
    this.emotionalWeight = 0.0,
    required this.createdAt,
    this.lastAccessedAt,
  });

  final String memoryId;
  final String content;
  final String ownerCharacterId;
  final List<String> knownBy;
  final MemoryVisibility visibility;
  final double emotionalWeight;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;

  bool canAccess(String characterId) {
    if (visibility == MemoryVisibility.public) return true;
    return knownBy.contains(characterId);
  }

  MemoryEntry copyWith({
    String? memoryId,
    String? content,
    String? ownerCharacterId,
    List<String>? knownBy,
    MemoryVisibility? visibility,
    double? emotionalWeight,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool clearLastAccessedAt = false,
  }) {
    return MemoryEntry(
      memoryId: memoryId ?? this.memoryId,
      content: content ?? this.content,
      ownerCharacterId: ownerCharacterId ?? this.ownerCharacterId,
      knownBy: knownBy ?? this.knownBy,
      visibility: visibility ?? this.visibility,
      emotionalWeight: emotionalWeight ?? this.emotionalWeight,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: clearLastAccessedAt ? null : (lastAccessedAt ?? this.lastAccessedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'memoryId': memoryId,
      'content': content,
      'ownerCharacterId': ownerCharacterId,
      'knownBy': knownBy,
      'visibility': visibility.wireValue,
      'emotionalWeight': emotionalWeight,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toUtc().toIso8601String(),
    };
  }

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      memoryId: '${json['memoryId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      ownerCharacterId: '${json['ownerCharacterId'] ?? ''}',
      knownBy: _parseStringList(json['knownBy']),
      visibility: memoryVisibilityFromWire(json['visibility']),
      emotionalWeight: _parseDouble(json['emotionalWeight']) ?? 0.0,
      createdAt: _parseDateTime(json['createdAt']),
      lastAccessedAt: _parseDateTimeOptional(json['lastAccessedAt']),
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

DateTime _parseDateTime(Object? raw) {
  final parsed = DateTime.tryParse('$raw');
  return parsed?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _parseDateTimeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') return null;
  return DateTime.tryParse(normalized)?.toUtc();
}
