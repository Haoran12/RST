import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rst/app.dart';

void main() {
  testWidgets('renders app shell tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RstApp()));

    expect(find.text('聊天'), findsWidgets);
    expect(find.text('Lore'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('日志'), findsWidgets);
  });
}
