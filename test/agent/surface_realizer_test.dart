import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/cognitive_pass_io.dart';
import 'package:rst/core/services/agent/action_arbitration.dart';
import 'package:rst/core/services/agent/surface_realizer.dart';

void main() {
  group('SurfaceRealizer', () {
    const service = SurfaceRealizer();

    test('renders actions and dialogue from execution order', () {
      final input = SurfaceRealizerInput(
        sceneTurnId: 'turn_1',
        arbitrationResult: _sampleArbitrationResult(),
        visibleSceneChanges: const ['风从门缝灌入。'],
      );

      final output = service.render(input);

      expect(output.visibleActionDescriptions.length, equals(2));
      expect(output.visibleActionDescriptions.first, startsWith('char_a:'));
      expect(output.dialogueBlocks.length, equals(1));
      expect(output.dialogueBlocks.first.characterId, equals('char_a'));
      expect(output.renderedText, contains('char_a：「先把刀放下。」'));
      expect(output.renderedText, contains('风从门缝灌入。'));
    });

    test('does not emit dialogue for silent reveal level', () {
      final result = ActionArbitrationResult(
        turnId: 'turn_2',
        executionOrder: const [
          ExecutionOrderEntry(
            characterId: 'silent_char',
            reason: 'test',
            priorityScore: 0.9,
          ),
        ],
        renderedActions: const [
          ArbitratedAction(
            characterId: 'silent_char',
            outwardAction: '盯住对方',
            dialogue: '你听我解释',
            visibleBehavior: ['沉默'],
            hiddenBehavior: ['压制情绪'],
            priorityScore: 0.9,
            revealLevel: RevealLevel.silent,
          ),
        ],
        suppressedActions: const [],
        conflicts: const [],
      );

      final output = service.render(
        SurfaceRealizerInput(sceneTurnId: 'turn_2', arbitrationResult: result),
      );

      expect(output.dialogueBlocks, isEmpty);
      expect(output.renderedText, isNot(contains('你听我解释')));
    });

    test('applies speaker order override', () {
      final output = service.render(
        SurfaceRealizerInput(
          sceneTurnId: 'turn_3',
          arbitrationResult: _sampleArbitrationResult(),
          speakerOrder: const ['char_b', 'char_a'],
        ),
      );

      expect(output.visibleActionDescriptions.first, startsWith('char_b:'));
      expect(output.visibleActionDescriptions.last, startsWith('char_a:'));
    });
  });
}

ActionArbitrationResult _sampleArbitrationResult() {
  return const ActionArbitrationResult(
    turnId: 'turn_1',
    executionOrder: [
      ExecutionOrderEntry(
        characterId: 'char_a',
        reason: 'score=0.92',
        priorityScore: 0.92,
      ),
      ExecutionOrderEntry(
        characterId: 'char_b',
        reason: 'score=0.73',
        priorityScore: 0.73,
      ),
    ],
    renderedActions: [
      ArbitratedAction(
        characterId: 'char_a',
        outwardAction: '向前半步逼近',
        dialogue: '先把刀放下。',
        visibleBehavior: ['逼近', '抬手示意'],
        hiddenBehavior: ['保持警惕'],
        priorityScore: 0.92,
        revealLevel: RevealLevel.direct,
      ),
      ArbitratedAction(
        characterId: 'char_b',
        outwardAction: '后撤并压低重心',
        dialogue: '',
        visibleBehavior: ['后撤'],
        hiddenBehavior: ['准备反击'],
        priorityScore: 0.73,
        revealLevel: RevealLevel.guarded,
      ),
    ],
    suppressedActions: [],
    conflicts: [],
  );
}
