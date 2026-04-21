import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rst/shared/widgets/floating_composer.dart';

void main() {
  testWidgets('ctrl+enter sends message when composer is focused', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });
    var sendCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingComposer(
            controller: controller,
            focusNode: focusNode,
            onSend: () {
              sendCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(sendCount, 1);
  });
}
