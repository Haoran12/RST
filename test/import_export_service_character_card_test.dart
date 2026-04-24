import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/bridge/rust_bridge.dart';
import 'package:rst/core/providers/app_state.dart';
import 'package:rst/core/services/api_service.dart';
import 'package:rst/core/services/chat_service.dart';
import 'package:rst/core/services/import_export_service.dart';
import 'package:rst/core/services/provider_spec_service.dart';
import 'package:rst/core/services/runtime_log_service.dart';
import 'package:rst/core/services/world_book_injection.dart';

void main() {
  late ImportExportService service;

  setUp(() {
    service = ImportExportService(
      apiService: const ApiService(),
      chatService: ChatService(
        const RustBridge(),
        const ProviderSpecService(),
        RuntimeLogService.instance,
      ),
    );
  });

  test('imports ST character card json into world book', () async {
    final file = File(
      '${Directory.systemTemp.path}/rst-character-card-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    await file.writeAsString(
      jsonEncode(<String, dynamic>{
        'spec': 'chara_card_v2',
        'data': <String, dynamic>{
          'name': 'Alice',
          'description': 'A wandering mage.',
          'personality': 'Calm and precise.',
          'scenario': 'On the road.',
          'first_mes': 'Hello there.',
          'mes_example': 'Alice nods.',
          'character_book': <String, dynamic>{
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 0,
                'comment': '角色外貌',
                'content': '银发，蓝眼，法袍。',
                'keys': <String>['Alice'],
              },
              <String, dynamic>{
                'id': 1,
                'comment': '王国历史',
                'content': '王国已经延续数百年。',
                'keys': <String>['王国'],
              },
            ],
          },
        },
      }),
    );

    final result = await service.importWorldBookFromFile(
      filePath: file.path,
      existingOptions: const <ManagedOption>[],
    );
    final worldBook = result.value;
    final entries = parseWorldBookEntries(worldBook);
    final categoryMap =
        jsonDecode(worldBook.fieldValue(worldBookCategoryFieldKey) as String)
            as Map<String, dynamic>;

    expect(entries, hasLength(3));
    final main = entries.firstWhere((entry) => entry['comment'] == 'Alice');
    expect(main['constant'], isTrue);
    expect(main['position'], 0);
    expect('${main['content']}', contains('description:\nA wandering mage.'));

    final characterLore = entries.firstWhere(
      (entry) => entry['comment'] == '角色外貌',
    );
    expect(categoryMap['${characterLore['uid']}'], 'character');

    final settingLore = entries.firstWhere(
      (entry) => entry['comment'] == '王国历史',
    );
    expect(categoryMap['${settingLore['uid']}'], 'setting');

    expect(
      worldBook.fieldValue(worldBookCharacterCardJsonFieldKey),
      isA<String>(),
    );
  });

  test('imports ST character card png and preserves image path', () async {
    final file = File(
      '${Directory.systemTemp.path}/rst-character-card-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    final cardJson = jsonEncode(<String, dynamic>{
      'spec': 'chara_card_v2',
      'data': <String, dynamic>{'name': 'Bob', 'description': 'A knight.'},
    });
    final pngBytes = _buildPngWithTextChunk(
      'chara',
      base64.encode(utf8.encode(cardJson)),
    );
    await file.writeAsBytes(pngBytes, flush: true);

    final result = await service.importWorldBookFromFile(
      filePath: file.path,
      existingOptions: const <ManagedOption>[],
    );
    final worldBook = result.value;
    final imagePath =
        worldBook.fieldValue(worldBookCharacterCardImagePathFieldKey)
            as String?;
    expect(imagePath, isNotNull);
    expect(await File(imagePath!).exists(), isTrue);
    expect(
      worldBook.fieldValue(worldBookImportSourceFieldKey),
      'st_character_card_png',
    );
  });

  test(
    'imports ST world info and falls back to name when comment is empty',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/rst-st-worldbook-${DateTime.now().microsecondsSinceEpoch}.json',
      );
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'name': 'demo-worldbook',
          'entries': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'entry-a',
              'name': '主设定',
              'comment': '',
              'content': '设定内容 A',
              'key': <String>['主设定'],
            },
            <String, dynamic>{
              'id': 'entry-b',
              'name': '角色设定',
              'comment': '角色设定-comment',
              'content': '设定内容 B',
              'key': <String>['角色设定'],
            },
          ],
        }),
      );

      final result = await service.importWorldBookFromFile(
        filePath: file.path,
        existingOptions: const <ManagedOption>[],
      );
      final entries = parseWorldBookEntries(result.value);

      final fallbackEntry = entries.firstWhere(
        (entry) => '${entry['content']}' == '设定内容 A',
      );
      expect(fallbackEntry['comment'], '主设定');

      final explicitCommentEntry = entries.firstWhere(
        (entry) => '${entry['content']}' == '设定内容 B',
      );
      expect(explicitCommentEntry['comment'], '角色设定-comment');
    },
  );
}

List<int> _buildPngWithTextChunk(String key, String value) {
  final bytes = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  List<int> chunk(String type, List<int> data) {
    final length = ByteData(4)..setUint32(0, data.length, Endian.big);
    return <int>[
      ...length.buffer.asUint8List(),
      ...ascii.encode(type),
      ...data,
      0,
      0,
      0,
      0,
    ];
  }

  bytes.addAll(chunk('IHDR', Uint8List(13)));
  bytes.addAll(chunk('tEXt', latin1.encode('$key\u0000$value')));
  bytes.addAll(chunk('IEND', const <int>[]));
  return bytes;
}
