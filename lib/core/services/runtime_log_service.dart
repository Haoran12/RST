import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum RuntimeLogLevel { info, warning, error, fatal }

class RuntimeLogEntry {
  const RuntimeLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    required this.data,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final RuntimeLogLevel level;
  final String category;
  final String message;
  final Map<String, Object?> data;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ts': timestamp.toIso8601String(),
      'level': level.name,
      'category': category,
      'message': message,
      if (data.isNotEmpty) 'data': data,
      if (error != null && error!.isNotEmpty) 'error': error,
      if (stackTrace != null && stackTrace!.isNotEmpty) 'stack': stackTrace,
    };
  }

  factory RuntimeLogEntry.fromJson(Map<String, dynamic> json) {
    final timestampRaw = '${json['ts'] ?? ''}'.trim();
    final timestamp =
        DateTime.tryParse(timestampRaw)?.toUtc() ?? DateTime.now().toUtc();
    final levelRaw = '${json['level'] ?? ''}'.trim();
    var level = RuntimeLogLevel.info;
    for (final item in RuntimeLogLevel.values) {
      if (item.name == levelRaw) {
        level = item;
        break;
      }
    }

    final rawData = json['data'];
    final data = <String, Object?>{};
    if (rawData is Map) {
      rawData.forEach((key, value) {
        data['$key'] = value;
      });
    }

    return RuntimeLogEntry(
      timestamp: timestamp,
      level: level,
      category: '${json['category'] ?? ''}'.trim(),
      message: '${json['message'] ?? ''}',
      data: data,
      error: _normalizeOptionalString(json['error']),
      stackTrace: _normalizeOptionalString(json['stack']),
    );
  }

  static String? _normalizeOptionalString(Object? value) {
    final normalized = '$value'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }
}

class RuntimeLogService {
  RuntimeLogService._();

  static final RuntimeLogService instance = RuntimeLogService._();

  static const int _retentionDays = 14;
  static const int _maxFilesToRead = 7;
  static const Duration _defaultHeartbeatInterval = Duration(seconds: 45);
  static const int _maxErrorTextChars = 12000;
  static const int _maxStackTextChars = 24000;

  final JsonEncoder _encoder = const JsonEncoder();

  bool _initialized = false;
  Future<void>? _initializing;
  Future<void> _writeQueue = Future<void>.value();
  Directory? _logDirectory;
  Timer? _heartbeatTimer;
  int _heartbeatTicks = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final pending = _initializing;
    if (pending != null) {
      await pending;
      return;
    }
    final init = _doInitialize();
    _initializing = init;
    try {
      await init;
    } finally {
      _initializing = null;
    }
  }

  Future<String?> logDirectoryPath() async {
    try {
      await initialize();
      return _logDirectory?.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> info({
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _log(
      level: RuntimeLogLevel.info,
      category: category,
      message: message,
      data: data,
    );
  }

  Future<void> warning({
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _log(
      level: RuntimeLogLevel.warning,
      category: category,
      message: message,
      data: data,
    );
  }

  Future<void> error({
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    return _log(
      level: RuntimeLogLevel.error,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> fatal({
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    return _log(
      level: RuntimeLogLevel.fatal,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void startHeartbeat({
    Duration interval = _defaultHeartbeatInterval,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    if (_heartbeatTimer != null) {
      return;
    }
    _heartbeatTicks = 0;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      _heartbeatTicks += 1;
      unawaited(
        info(
          category: 'app.heartbeat',
          message: 'tick',
          data: <String, Object?>{
            'tick': _heartbeatTicks,
            ...data,
          },
        ),
      );
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<List<RuntimeLogEntry>> readRecentEntries({int limit = 200}) async {
    if (limit <= 0) {
      return const <RuntimeLogEntry>[];
    }
    await initialize();
    final directory = _logDirectory;
    if (directory == null || !directory.existsSync()) {
      return const <RuntimeLogEntry>[];
    }

    final files = await _listLogFiles(directory);
    files.sort((a, b) => b.path.compareTo(a.path));

    final entries = <RuntimeLogEntry>[];
    final filesToRead = files.length < _maxFilesToRead
        ? files.length
        : _maxFilesToRead;
    for (var fileIndex = 0; fileIndex < filesToRead; fileIndex++) {
      final file = files[fileIndex];
      final lines = await file.readAsLines();
      for (var index = lines.length - 1; index >= 0; index--) {
        final line = lines[index].trim();
        if (line.isEmpty) {
          continue;
        }
        try {
          final decoded = jsonDecode(line);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }
          entries.add(RuntimeLogEntry.fromJson(decoded));
        } catch (_) {
          continue;
        }
        if (entries.length >= limit) {
          return entries;
        }
      }
    }
    return entries;
  }

  Future<void> _doInitialize() async {
    final directory = await _resolveLogDirectory();
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    _logDirectory = directory;
    await _cleanupExpiredFiles(directory);
    _initialized = true;
  }

  Future<Directory> _resolveLogDirectory() async {
    final executableBase = _resolveExecutableDirectory();
    final preferred = Directory('${executableBase.path}/logs/runtime');
    try {
      if (!preferred.existsSync()) {
        preferred.createSync(recursive: true);
      }
      final probe = File('${preferred.path}/.write_probe');
      probe.writeAsStringSync(
        DateTime.now().toUtc().toIso8601String(),
        flush: true,
      );
      probe.deleteSync();
      return preferred;
    } catch (_) {
      final fallback = Directory(
        '${Directory.systemTemp.path}/rst_test_support/rst_data/logs/runtime',
      );
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback;
    }
  }

  Directory _resolveExecutableDirectory() {
    try {
      final resolved = Platform.resolvedExecutable;
      if (resolved.trim().isNotEmpty) {
        return File(resolved).parent;
      }
    } catch (_) {
      // ignore and fallback
    }
    return Directory.current;
  }

  Future<void> _cleanupExpiredFiles(Directory directory) async {
    final files = await _listLogFiles(directory);
    if (files.isEmpty) {
      return;
    }
    final cutoff = DateTime.now().toUtc().subtract(
      const Duration(days: _retentionDays),
    );
    for (final file in files) {
      final day = _extractDayFromFileName(file.path);
      if (day == null || day.isAfter(cutoff)) {
        continue;
      }
      try {
        await file.delete();
      } catch (_) {
        continue;
      }
    }
  }

  Future<List<File>> _listLogFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('runtime-') || !name.endsWith('.log')) {
        continue;
      }
      files.add(entity);
    }
    return files;
  }

  DateTime? _extractDayFromFileName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^runtime-(\d{4})(\d{2})(\d{2})\.log$').firstMatch(
      name,
    );
    if (match == null) {
      return null;
    }
    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime.utc(year, month, day);
  }

  Future<File> _resolveCurrentLogFile() async {
    final directory = _logDirectory ?? await _resolveLogDirectory();
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final filename = 'runtime-${now.year}$month$day.log';
    return File('${directory.path}/$filename');
  }

  Future<void> _log({
    required RuntimeLogLevel level,
    required String category,
    required String message,
    required Map<String, Object?> data,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    try {
      await initialize();
      final entry = RuntimeLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: level,
        category: category.trim().isEmpty ? 'general' : category.trim(),
        message: message,
        data: _sanitizeMap(data),
        error: _normalizeText(error, maxChars: _maxErrorTextChars),
        stackTrace: _normalizeText(stackTrace, maxChars: _maxStackTextChars),
      );
      final line = '${_encoder.convert(entry.toJson())}\n';
      _writeQueue = _writeQueue
          .catchError((_) {})
          .then((_) async {
            final file = await _resolveCurrentLogFile();
            await file.writeAsString(line, mode: FileMode.append, flush: false);
          });
      await _writeQueue;
    } catch (_) {
      // Runtime logging must never break app flow.
    }
  }

  Map<String, Object?> _sanitizeMap(Map<String, Object?> raw) {
    if (raw.isEmpty) {
      return const <String, Object?>{};
    }
    final result = <String, Object?>{};
    raw.forEach((key, value) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) {
        return;
      }
      result[normalizedKey] = _sanitizeValue(value);
    });
    return result;
  }

  Object? _sanitizeValue(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is Map) {
      final map = <String, Object?>{};
      value.forEach((key, nestedValue) {
        map['$key'] = _sanitizeValue(nestedValue);
      });
      return map;
    }
    return '$value';
  }

  String? _normalizeText(Object? value, {required int maxChars}) {
    if (value == null) {
      return null;
    }
    final normalized = '$value'.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)} ...<truncated>';
  }
}
