import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rst/shared/widgets/structured_text_editor.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StructuredTextEditor(
            initialText: '',
            initialFormat: StructuredTextFormat.yaml,
            height: 320,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  TextEditingController controllerOf(WidgetTester tester, Finder finder) {
    return tester.widget<TextField>(finder).controller!;
  }

  testWidgets(
    'yaml newline indents child blocks and keeps sibling indentation',
    (WidgetTester tester) async {
      await pumpEditor(tester);

      final editor = find.byType(TextField).first;

      await tester.enterText(editor, 'profile:');
      await tester.pump();
      await tester.enterText(editor, 'profile:\n');
      await tester.pump();
      expect(controllerOf(tester, editor).text, 'profile:\n  ');

      await tester.enterText(editor, 'profile:\n  name: Alice');
      await tester.pump();
      await tester.enterText(editor, 'profile:\n  name: Alice\n');
      await tester.pump();
      expect(controllerOf(tester, editor).text, 'profile:\n  name: Alice\n  ');
    },
  );

  testWidgets('fullscreen editor uses the same yaml indentation rules', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.byTooltip('全屏编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final fullscreenEditor = find.byType(TextField).last;
    await tester.enterText(fullscreenEditor, 'profile:');
    await tester.pump();
    await tester.enterText(fullscreenEditor, 'profile:\n');
    await tester.pump();

    expect(controllerOf(tester, fullscreenEditor).text, 'profile:\n  ');
  });

  testWidgets(
    'fullscreen editor uses overlay dialog on windows desktop',
    (WidgetTester tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.byTooltip('全屏编辑'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{TargetPlatform.windows}),
  );

  testWidgets('yaml list item continues with same indent and dash on newline', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    final editor = find.byType(TextField).first;

    // Simple list item
    await tester.enterText(editor, '- item1');
    await tester.pump();
    await tester.enterText(editor, '- item1\n');
    await tester.pump();
    expect(controllerOf(tester, editor).text, '- item1\n- ');

    // List item with value after newline should continue list
    await tester.enterText(editor, '- item1\n- item2');
    await tester.pump();
    await tester.enterText(editor, '- item1\n- item2\n');
    await tester.pump();
    expect(controllerOf(tester, editor).text, '- item1\n- item2\n- ');

    // Indented list item
    await tester.enterText(editor, 'list:\n  - item1');
    await tester.pump();
    await tester.enterText(editor, 'list:\n  - item1\n');
    await tester.pump();
    expect(controllerOf(tester, editor).text, 'list:\n  - item1\n  - ');
  });

  testWidgets('fullscreen editor confirms before discarding unsaved changes', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.byTooltip('全屏编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final fullscreenEditor = find.byType(TextField).last;
    await tester.enterText(fullscreenEditor, 'draft');
    await tester.pump();

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
