import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/import_export_models.dart';
import 'package:rst/core/providers/app_state.dart';
import 'package:rst/core/services/api_service.dart';

void main() {
  test('appearance catalog roundtrip', () async {
    const apiService = ApiService();
    final appearance = buildAppearanceOptionTemplate(
      id: 'appearance-test-${DateTime.now().microsecondsSinceEpoch}',
      name: '测试外观',
      description: 'appearance import export test',
      themeMode: 'light',
    );

    await apiService.saveAppearanceCatalog(<ManagedOption>[appearance]);

    final loaded = await apiService.loadAppearanceCatalog();
    expect(loaded, isNotNull);
    final matched = loaded!
        .where((item) => item.id == appearance.id)
        .toList(growable: false);
    expect(matched, hasLength(1));
    expect(matched.first.name, appearance.name);

    await apiService.saveAppearanceCatalog(const <ManagedOption>[]);
  });

  test('session metadata and raw session document roundtrip', () async {
    const apiService = ApiService();
    final sessionId =
        'session-storage-${DateTime.now().microsecondsSinceEpoch}';
    const metadata = SessionStoredMetadata(
      schedulerMode: 'sillyTavern',
      appearanceId: 'appearance-default',
      backgroundImagePath: 'C:/tmp/background.png',
      userDescription: 'user',
      scene: 'scene',
      lores: 'lores',
    );

    await apiService.saveSessionMetadata(
      sessionId: sessionId,
      metadata: metadata,
    );
    final loadedMetadata = await apiService.loadSessionMetadata(sessionId);
    expect(loadedMetadata, isNotNull);
    expect(loadedMetadata!.appearanceId, metadata.appearanceId);
    expect(loadedMetadata.backgroundImagePath, metadata.backgroundImagePath);

    final allMetadata = await apiService.loadAllSessionMetadata();
    expect(allMetadata[sessionId], isNotNull);

    await apiService.writeSessionDocument(
      sessionId: sessionId,
      document: <String, dynamic>{
        'config': <String, dynamic>{
          'sessionId': sessionId,
          'sessionName': '测试会话',
          'mode': 'st',
          'mainApiConfigId': 'api-startup',
          'presetId': 'preset-startup',
          'stWorldBookId': 'wb-test',
          'createdAt': '2026-01-01T00:00:00Z',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
        'runtime': <String, dynamic>{
          'sessionId': sessionId,
          'activeMessageId': null,
          'streamingStatus': 'idle',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
        'messages': const <Map<String, dynamic>>[],
      },
    );

    final loadedDocument = await apiService.readSessionDocument(sessionId);
    expect(loadedDocument, isNotNull);
    expect(
      (loadedDocument!['config'] as Map<String, dynamic>)['sessionName'],
      '测试会话',
    );

    await apiService.deleteSessionDocument(sessionId);
    await apiService.deleteSessionMetadata(sessionId);
    expect(await apiService.readSessionDocument(sessionId), isNull);
    expect(await apiService.loadSessionMetadata(sessionId), isNull);
  });
}
