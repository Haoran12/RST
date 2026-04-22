import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rst/core/providers/app_state.dart';

void main() {
  test('includes built-in light appearance option', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final options = container.read(appearanceOptionsProvider);
    final lightOption = options.firstWhere(
      (option) => option.id == 'appearance-default-light',
    );

    expect(lightOption.name, '默认浅色');
    expect(lightOption.fieldValue('theme_mode'), 'light');
  });
}
