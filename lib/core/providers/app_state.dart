import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { chat, lore, settings, log }

final appTabProvider = StateProvider<AppTab>((_) => AppTab.chat);
