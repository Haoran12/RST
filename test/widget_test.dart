import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rst/app.dart';

void main() {
  testWidgets('renders drawer navigation items', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RstApp()));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('会话管理'), findsOneWidget);
    expect(find.text('世界书'), findsOneWidget);
    expect(find.text('预设'), findsOneWidget);
    expect(find.text('API配置'), findsOneWidget);

    final drawerList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('外观'),
      200,
      scrollable: drawerList,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('外观'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Agent'),
      200,
      scrollable: drawerList,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Agent'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('日志'),
      200,
      scrollable: drawerList,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('日志'), findsWidgets);
  });
}
