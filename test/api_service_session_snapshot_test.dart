import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/services/api_service.dart';

void main() {
  test('session world book snapshot roundtrip', () async {
    const apiService = ApiService();
    const sessionId = 'snapshot-test-session';
    const snapshotJson = '{"entries":{"1":{"uid":1,"content":"snapshot"}}}';

    await apiService.deleteSessionWorldBookSnapshot(sessionId: sessionId);
    await apiService.writeSessionWorldBookSnapshot(
      sessionId: sessionId,
      sourceWorldBookId: 'wb-main',
      sourceWorldBookName: 'Main World Book',
      worldBookJson: snapshotJson,
    );

    final loaded = await apiService.loadSessionWorldBookSnapshotJson(
      sessionId: sessionId,
    );
    expect(loaded, snapshotJson);

    await apiService.deleteSessionWorldBookSnapshot(sessionId: sessionId);
    final deleted = await apiService.loadSessionWorldBookSnapshotJson(
      sessionId: sessionId,
    );
    expect(deleted, isNull);
  });
}
