import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RstApp()));

  doWhenWindowReady(() {
    const initialSize = Size(1440, 900);
    const minSize = Size(800, 600);
    appWindow.minSize = minSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}
