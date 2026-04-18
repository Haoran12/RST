import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/bridge/frb_api.dart' as frb;
import 'package:rst/core/providers/app_state.dart';
import 'package:rst/core/services/world_book_injection.dart';

void main() {
  group('parseWorldBookEntries', () {
    test('uses map key as fallback uid when entry uid is missing', () {
      final worldBook = _buildWorldBookFromRawJson(<String, dynamic>{
        'entries': <String, dynamic>{
          '12': <String, dynamic>{
            'key': <String>['alpha'],
            'content': 'alpha',
          },
          '40': <String, dynamic>{
            'key': <String>['beta'],
            'content': 'beta',
          },
        },
      });

      final parsed = parseWorldBookEntries(worldBook);
      final uids = parsed.map((item) => item['uid']).toList(growable: false);
      final serialized = <String, dynamic>{
        for (final entry in parsed) '${entry['uid']}': entry,
      };

      expect(uids, containsAll(<int>[12, 40]));
      expect(serialized.length, 2);
    });

    test('normalizes duplicate uid values to keep entries saveable', () {
      final worldBook = _buildWorldBookFromRawJson(<String, dynamic>{
        'entries': <String, dynamic>{
          '0': <String, dynamic>{
            'uid': 7,
            'key': <String>['alpha'],
            'content': 'alpha',
          },
          '1': <String, dynamic>{
            'uid': 7,
            'key': <String>['beta'],
            'content': 'beta',
          },
        },
      });

      final parsed = parseWorldBookEntries(worldBook);
      final uids = parsed.map((item) => item['uid'] as int).toList();
      final serialized = <String, dynamic>{
        for (final entry in parsed) '${entry['uid']}': entry,
      };

      expect(parsed, hasLength(2));
      expect(uids.toSet(), hasLength(2));
      expect(serialized.length, 2);
    });
  });

  group('world book editor save compatibility', () {
    test('editor-like save map keeps all parsed entries', () {
      final worldBook = _buildWorldBookFromRawJson(<String, dynamic>{
        'entries': <String, dynamic>{
          '12': <String, dynamic>{
            'key': <String>['alpha'],
            'content': 'alpha',
          },
          '13': <String, dynamic>{
            'uid': 7,
            'key': <String>['beta'],
            'content': 'beta',
          },
          '14': <String, dynamic>{
            'uid': 7,
            'key': <String>['gamma'],
            'content': 'gamma',
          },
        },
      });

      final parsed = parseWorldBookEntries(worldBook);
      final editorEntries = _serializeEntriesLikeWorldBookEditor(parsed);

      expect(parsed, hasLength(3));
      expect(editorEntries.length, 3);
      expect(editorEntries.keys.toSet().length, 3);
    });
  });

  group('WorldBookInjection.buildStModeLore', () {
    test('injects lore into before and after blocks', () {
      final worldBook = _buildWorldBook(<Map<String, dynamic>>[
        _entry(
          uid: 1,
          key: <String>['cat'],
          content: 'before lore',
          position: 0,
        ),
        _entry(
          uid: 2,
          key: <String>['cat'],
          content: 'after lore',
          position: 1,
        ),
      ]);

      final result = WorldBookInjection.buildStModeLore(
        sessionId: 's-before-after',
        userInput: 'A cat appears.',
        visibleMessages: const <frb.MessageRecord>[],
        baseLores: 'base lore',
        userDescription: '',
        scene: '',
        worldBook: worldBook,
      );

      expect(result.before, 'before lore\n\nbase lore');
      expect(result.after, 'after lore');
      expect(result.activatedEntryUids, containsAll(<int>[1, 2]));
    });

    test('respects trigger gating', () {
      final worldBook = _buildWorldBook(<Map<String, dynamic>>[
        _entry(
          uid: 10,
          key: <String>['event'],
          content: 'triggered lore',
          triggers: <String>['event_trigger'],
        ),
      ]);

      final skipped = WorldBookInjection.buildStModeLore(
        sessionId: 's-trigger-skip',
        userInput: 'event',
        visibleMessages: const <frb.MessageRecord>[],
        baseLores: 'base',
        userDescription: '',
        scene: '',
        worldBook: worldBook,
        trigger: 'chat',
      );
      expect(skipped.before, 'base');
      expect(skipped.after, isEmpty);

      final hit = WorldBookInjection.buildStModeLore(
        sessionId: 's-trigger-hit',
        userInput: 'event',
        visibleMessages: const <frb.MessageRecord>[],
        baseLores: 'base',
        userDescription: '',
        scene: '',
        worldBook: worldBook,
        trigger: 'event_trigger',
      );
      expect(hit.before, 'triggered lore\n\nbase');
      expect(hit.after, isEmpty);
    });

    test('supports selectiveLogic AND_ALL', () {
      final worldBook = _buildWorldBook(<Map<String, dynamic>>[
        _entry(
          uid: 20,
          key: <String>['hero'],
          keysecondary: <String>['sword', 'shield'],
          selective: true,
          selectiveLogic: 3,
          content: 'and-all lore',
        ),
      ]);

      final miss = WorldBookInjection.buildStModeLore(
        sessionId: 's-and-all-miss',
        userInput: 'hero with sword only',
        visibleMessages: const <frb.MessageRecord>[],
        baseLores: '',
        userDescription: '',
        scene: '',
        worldBook: worldBook,
      );
      expect(miss.before, isEmpty);

      final hit = WorldBookInjection.buildStModeLore(
        sessionId: 's-and-all-hit',
        userInput: 'hero with sword and shield',
        visibleMessages: const <frb.MessageRecord>[],
        baseLores: '',
        userDescription: '',
        scene: '',
        worldBook: worldBook,
      );
      expect(hit.before, 'and-all lore');
    });
  });
}

ManagedOption _buildWorldBookFromRawJson(Map<String, dynamic> rawJson) {
  final json = jsonEncode(rawJson);
  return ManagedOption(
    id: 'wb-test',
    name: 'wb-test',
    description: '',
    updatedAt: DateTime.utc(2026, 1, 1),
    type: ManagedOptionType.worldBook,
    sections: <ManagedOptionSection>[
      ManagedOptionSection(
        title: 'test',
        description: '',
        fields: <ManagedOptionField>[
          ManagedOptionField(
            key: worldBookJsonFieldKey,
            label: 'json',
            type: ManagedFieldType.multiline,
            value: json,
          ),
        ],
      ),
    ],
  );
}

ManagedOption _buildWorldBook(List<Map<String, dynamic>> entries) {
  return _buildWorldBookFromRawJson(<String, dynamic>{
    'entries': <String, dynamic>{
      for (final entry in entries) '${entry['uid']}': entry,
    },
  });
}

Map<String, dynamic> _entry({
  required int uid,
  required List<String> key,
  required String content,
  int position = 0,
  List<String> keysecondary = const <String>[],
  bool selective = true,
  int selectiveLogic = 0,
  List<String> triggers = const <String>[],
}) {
  return <String, dynamic>{
    'uid': uid,
    'key': key,
    'keysecondary': keysecondary,
    'comment': 'entry-$uid',
    'content': content,
    'constant': false,
    'vectorized': false,
    'selective': selective,
    'selectiveLogic': selectiveLogic,
    'addMemo': true,
    'order': 100,
    'position': position,
    'disable': false,
    'ignoreBudget': false,
    'excludeRecursion': false,
    'preventRecursion': false,
    'matchPersonaDescription': false,
    'matchCharacterDescription': false,
    'matchCharacterPersonality': false,
    'matchCharacterDepthPrompt': false,
    'matchScenario': false,
    'matchCreatorNotes': false,
    'delayUntilRecursion': false,
    'probability': 100,
    'useProbability': false,
    'depth': 4,
    'group': '',
    'groupOverride': false,
    'groupWeight': 100,
    'scanDepth': null,
    'caseSensitive': false,
    'matchWholeWords': false,
    'useGroupScoring': false,
    'automationId': '',
    'role': null,
    'sticky': 0,
    'cooldown': 0,
    'delay': 0,
    'triggers': triggers,
    'displayIndex': uid,
    'characterFilter': <String, dynamic>{
      'isExclude': false,
      'names': <String>[],
      'tags': <String>[],
    },
  };
}

Map<String, Map<String, dynamic>> _serializeEntriesLikeWorldBookEditor(
  List<Map<String, dynamic>> parsed,
) {
  final entries = <String, Map<String, dynamic>>{};
  for (var i = 0; i < parsed.length; i += 1) {
    final data = Map<String, dynamic>.from(parsed[i]);
    final uid = data['uid'] as int;
    data['displayIndex'] = i;
    entries['$uid'] = data;
  }
  return entries;
}
