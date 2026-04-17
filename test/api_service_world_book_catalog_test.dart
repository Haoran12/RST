import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/providers/app_state.dart';
import 'package:rst/core/services/api_service.dart';
import 'package:rst/core/services/world_book_injection.dart';

void main() {
  test('world book catalog roundtrip', () async {
    const apiService = ApiService();
    final id = 'wb-test-${DateTime.now().microsecondsSinceEpoch}';
    final worldBook = ManagedOption(
      id: id,
      name: '测试世界书',
      description: 'catalog test',
      updatedAt: DateTime.now().toUtc(),
      type: ManagedOptionType.worldBook,
      sections: const <ManagedOptionSection>[
        ManagedOptionSection(
          title: 'Snapshot',
          description: '',
          fields: <ManagedOptionField>[
            ManagedOptionField(
              key: worldBookJsonFieldKey,
              label: 'worldbook_json',
              type: ManagedFieldType.multiline,
              value: '{"entries":{"1":{"uid":1,"comment":"test-entry"}}}',
            ),
          ],
        ),
      ],
    );

    await apiService.saveWorldBookCatalog(<ManagedOption>[worldBook]);

    final loaded = await apiService.loadWorldBookCatalog();
    expect(loaded, isNotNull);
    final matched = loaded!
        .where((item) => item.id == id)
        .toList(growable: false);
    expect(matched, hasLength(1));
    expect(
      matched.first.fieldValue(worldBookJsonFieldKey),
      '{"entries":{"1":{"uid":1,"comment":"test-entry"}}}',
    );

    await apiService.saveWorldBookCatalog(const <ManagedOption>[]);
    final cleared = await apiService.loadWorldBookCatalog();
    expect(cleared, isNotNull);
    expect(cleared, isEmpty);
  });
}
