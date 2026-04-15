import 'package:flutter_test/flutter_test.dart';
import 'package:rst/shared/utils/reasoning_markup.dart';

void main() {
  test('compose embeds reasoning block', () {
    final content = ReasoningMarkup.compose(
      content: 'final answer',
      reasoning: 'step 1\nstep 2',
    );
    expect(
      content,
      'final answer\n\n<reasoning>\nstep 1\nstep 2\n</reasoning>',
    );
  });

  test('parse separates visible content and reasoning', () {
    final parsed = ReasoningMarkup.parse(
      'final answer\n\n<reasoning>\nA\nB\n</reasoning>',
    );
    expect(parsed.content, 'final answer');
    expect(parsed.reasoning, 'A\nB');
  });

  test('stripReasoning removes all reasoning blocks', () {
    final stripped = ReasoningMarkup.stripReasoning(
      'A<reasoning>r1</reasoning>\nB<reasoning>r2</reasoning>',
    );
    expect(stripped, 'A\nB');
  });
}
