class ImportWarning {
  const ImportWarning({required this.code, required this.message});

  final String code;
  final String message;
}

class ImportResult<T> {
  const ImportResult({
    required this.value,
    this.warnings = const <ImportWarning>[],
  });

  final T value;
  final List<ImportWarning> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

class SessionStoredMetadata {
  const SessionStoredMetadata({
    required this.schedulerMode,
    required this.appearanceId,
    required this.backgroundImagePath,
    required this.userDescription,
    required this.scene,
    required this.lores,
  });

  final String schedulerMode;
  final String appearanceId;
  final String backgroundImagePath;
  final String userDescription;
  final String scene;
  final String lores;

  SessionStoredMetadata copyWith({
    String? schedulerMode,
    String? appearanceId,
    String? backgroundImagePath,
    String? userDescription,
    String? scene,
    String? lores,
  }) {
    return SessionStoredMetadata(
      schedulerMode: schedulerMode ?? this.schedulerMode,
      appearanceId: appearanceId ?? this.appearanceId,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      userDescription: userDescription ?? this.userDescription,
      scene: scene ?? this.scene,
      lores: lores ?? this.lores,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schedulerMode': schedulerMode,
      'appearanceId': appearanceId,
      'backgroundImagePath': backgroundImagePath,
      'userDescription': userDescription,
      'scene': scene,
      'lores': lores,
    };
  }

  factory SessionStoredMetadata.fromJson(Map<String, dynamic> json) {
    return SessionStoredMetadata(
      schedulerMode: '${json['schedulerMode'] ?? 'sillyTavern'}',
      appearanceId: '${json['appearanceId'] ?? 'appearance-default'}',
      backgroundImagePath: '${json['backgroundImagePath'] ?? ''}',
      userDescription: '${json['userDescription'] ?? ''}',
      scene: '${json['scene'] ?? ''}',
      lores: '${json['lores'] ?? ''}',
    );
  }
}

class SessionWorldBookSnapshotData {
  const SessionWorldBookSnapshotData({
    required this.sessionId,
    required this.sourceWorldBookId,
    required this.sourceWorldBookName,
    required this.capturedAt,
    required this.worldBookJson,
    this.version = 1,
  });

  final String sessionId;
  final String sourceWorldBookId;
  final String sourceWorldBookName;
  final String capturedAt;
  final String worldBookJson;
  final int version;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'sourceWorldBookId': sourceWorldBookId,
      'sourceWorldBookName': sourceWorldBookName,
      'capturedAt': capturedAt,
      'worldBookJson': worldBookJson,
      'version': version,
    };
  }

  factory SessionWorldBookSnapshotData.fromJson(Map<String, dynamic> json) {
    return SessionWorldBookSnapshotData(
      sessionId: '${json['sessionId'] ?? ''}',
      sourceWorldBookId: '${json['sourceWorldBookId'] ?? ''}',
      sourceWorldBookName: '${json['sourceWorldBookName'] ?? ''}',
      capturedAt: '${json['capturedAt'] ?? ''}',
      worldBookJson: '${json['worldBookJson'] ?? ''}',
      version: int.tryParse('${json['version'] ?? '1'}') ?? 1,
    );
  }
}

enum WorldBookImportSourceKind {
  rstWorldBook,
  stWorldInfo,
  stCharacterCardJson,
  stCharacterCardPng,
  unsupported,
}

class WorldBookImportProbe {
  const WorldBookImportProbe({
    required this.kind,
    this.detectedName,
    this.attachedCharacterBookEntryCount = 0,
  });

  final WorldBookImportSourceKind kind;
  final String? detectedName;
  final int attachedCharacterBookEntryCount;

  bool get requiresClassification => attachedCharacterBookEntryCount > 0;
}
