import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/workspace_config.dart';

void main() {
  test('normalize adds interactive_input builtin when missing', () {
    final normalized = normalizeStoredPresetEntries(<StoredPresetEntry>[
      const StoredPresetEntry(
        entryId: 'custom-1',
        title: 'Custom',
        role: StoredPresetEntryRole.system,
        content: 'custom content',
      ),
    ], legacyMainPrompt: 'main prompt');

    final interactive = normalized.firstWhere(
      (entry) => entry.builtinKey == PresetBuiltinEntryKeys.interactiveInput,
    );
    expect(interactive.title, 'Interactive Input');
    expect(interactive.role, StoredPresetEntryRole.user);
    expect(interactive.enabled, isTrue);
    expect(interactive.content, isEmpty);
  });

  test('normalize enforces interactive_input builtin invariants', () {
    final normalized = normalizeStoredPresetEntries(<StoredPresetEntry>[
      const StoredPresetEntry(
        entryId: 'builtin-interactive_input',
        title: 'Changed Title',
        role: StoredPresetEntryRole.system,
        content: 'should be removed',
        enabled: false,
        builtinKey: PresetBuiltinEntryKeys.interactiveInput,
      ),
    ]);

    final interactive = normalized.firstWhere(
      (entry) => entry.builtinKey == PresetBuiltinEntryKeys.interactiveInput,
    );
    expect(interactive.title, 'Interactive Input');
    expect(interactive.role, StoredPresetEntryRole.user);
    expect(interactive.enabled, isTrue);
    expect(interactive.content, isEmpty);
  });

  test('toJson exports interactive_input builtin as interactiveInput', () {
    final now = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final config = StoredPresetConfig(
      presetId: 'preset-1',
      name: 'Preset',
      entries: buildDefaultPresetEntries(mainPromptContent: 'main prompt'),
      createdAt: now,
      updatedAt: now,
    );

    final prompts = (config.toJson()['prompts'] as List)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final interactive = prompts.firstWhere(
      (item) => item['identifier'] == 'interactiveInput',
    );
    expect(interactive['role'], 'user');
    expect(interactive['enabled'], isTrue);
  });
}
