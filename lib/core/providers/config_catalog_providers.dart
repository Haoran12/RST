import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workspace_config.dart';
import '../services/api_service.dart';
import 'app_state.dart';
import 'service_providers.dart';

final presetCatalogProvider =
    AsyncNotifierProvider<PresetCatalogNotifier, List<StoredPresetConfig>>(
      PresetCatalogNotifier.new,
    );

final apiConfigCatalogProvider =
    AsyncNotifierProvider<ApiConfigCatalogNotifier, List<StoredApiConfig>>(
      ApiConfigCatalogNotifier.new,
    );

class PresetCatalogNotifier extends AsyncNotifier<List<StoredPresetConfig>> {
  ApiService get _service => ref.read(apiServiceProvider);

  @override
  Future<List<StoredPresetConfig>> build() async {
    return _service.listPresets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.listPresets);
  }

  Future<StoredPresetConfig> save(StoredPresetConfig config) async {
    final saved = await _service.savePreset(config);
    await refresh();
    ref.read(workspaceReloadTickProvider.notifier).state++;
    return saved;
  }

  Future<void> delete(String presetId) async {
    await _service.deletePreset(presetId);
    await refresh();
    ref.read(workspaceReloadTickProvider.notifier).state++;
  }
}

class ApiConfigCatalogNotifier extends AsyncNotifier<List<StoredApiConfig>> {
  ApiService get _service => ref.read(apiServiceProvider);

  @override
  Future<List<StoredApiConfig>> build() async {
    return _service.listApiConfigs();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.listApiConfigs);
  }

  Future<StoredApiConfig> save(StoredApiConfig config) async {
    final saved = await _service.saveApiConfig(config);
    await refresh();
    ref.read(workspaceReloadTickProvider.notifier).state++;
    return saved;
  }

  Future<void> delete(String apiId) async {
    await _service.deleteApiConfig(apiId);
    await refresh();
    ref.read(workspaceReloadTickProvider.notifier).state++;
  }
}
