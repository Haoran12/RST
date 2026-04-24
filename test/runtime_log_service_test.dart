import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/services/runtime_log_service.dart';

void main() {
  test('writes and reads runtime log entries', () async {
    final service = RuntimeLogService.instance;
    await service.initialize();
    await service.info(
      category: 'test.runtime',
      message: 'probe',
      data: const <String, Object?>{'value': 1},
    );

    final entries = await service.readRecentEntries(limit: 50);
    final matched = entries.any(
      (entry) =>
          entry.category == 'test.runtime' &&
          entry.message == 'probe' &&
          entry.data['value'] == 1,
    );
    expect(matched, isTrue);
  });
}
