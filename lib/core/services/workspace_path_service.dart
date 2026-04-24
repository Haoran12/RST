import 'dart:io';

class WorkspacePathService {
  WorkspacePathService._();

  static const String workspaceDirectoryName = 'rst_data';
  static const String _probeFileName = '.write_probe';
  static bool _legacyMigrationChecked = false;

  static Directory resolveExecutableDirectory() {
    try {
      final resolved = Platform.resolvedExecutable.trim();
      if (resolved.isNotEmpty) {
        return File(resolved).parent;
      }
    } catch (_) {
      // fallback below
    }
    return Directory.current;
  }

  static Future<Directory> resolveWorkspaceDirectory() async {
    final executableDir = resolveExecutableDirectory();
    final candidates = <Directory>[
      Directory('${executableDir.path}/$workspaceDirectoryName'),
      Directory('${Directory.current.path}/$workspaceDirectoryName'),
      Directory('${Directory.systemTemp.path}/rst_test_support/$workspaceDirectoryName'),
    ];

    for (final candidate in candidates) {
      if (await _ensureWritable(candidate)) {
        await _migrateLegacyWorkspaceIfNeeded(candidate);
        return candidate;
      }
    }

    throw StateError('unable to resolve writable workspace directory');
  }

  static Future<bool> _ensureWritable(Directory dir) async {
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final probe = File('${dir.path}/$_probeFileName');
      await probe.writeAsString(
        DateTime.now().toUtc().toIso8601String(),
        flush: true,
      );
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _migrateLegacyWorkspaceIfNeeded(Directory target) async {
    if (_legacyMigrationChecked) {
      return;
    }
    _legacyMigrationChecked = true;

    if (await _hasWorkspaceData(target)) {
      return;
    }

    for (final legacy in _legacyWorkspaceCandidates()) {
      if (legacy.path == target.path) {
        continue;
      }
      if (!legacy.existsSync()) {
        continue;
      }
      if (!await _hasWorkspaceData(legacy)) {
        continue;
      }
      await _copyDirectoryContent(from: legacy, to: target);
      break;
    }
  }

  static List<Directory> _legacyWorkspaceCandidates() {
    final candidates = <Directory>[];
    final appData = Platform.environment['APPDATA'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      candidates.addAll(<Directory>[
        Directory('$appData/com.rst.app/rst/rst_data'),
        Directory('$appData/rst/rst_data'),
        Directory('$appData/RST/rst_data'),
      ]);
    }
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      candidates.addAll(<Directory>[
        Directory('$localAppData/com.rst.app/rst/rst_data'),
        Directory('$localAppData/rst/rst_data'),
        Directory('$localAppData/RST/rst_data'),
      ]);
    }
    return candidates;
  }

  static Future<bool> _hasWorkspaceData(Directory dir) async {
    final markers = <String>[
      'sessions',
      'request_logs',
      'config',
      'logs',
      'agent',
    ];
    for (final marker in markers) {
      if (Directory('${dir.path}/$marker').existsSync()) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _copyDirectoryContent({
    required Directory from,
    required Directory to,
  }) async {
    if (!to.existsSync()) {
      to.createSync(recursive: true);
    }
    await for (final entity in from.list(recursive: true)) {
      final relative = entity.path.substring(from.path.length).replaceAll(
        '\\',
        '/',
      );
      final normalized = relative.startsWith('/')
          ? relative.substring(1)
          : relative;
      final targetPath = '${to.path}/$normalized';
      if (entity is Directory) {
        final dir = Directory(targetPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        continue;
      }
      if (entity is File) {
        final file = File(targetPath);
        if (file.existsSync()) {
          continue;
        }
        final parent = file.parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        await entity.copy(file.path);
      }
    }
  }
}
