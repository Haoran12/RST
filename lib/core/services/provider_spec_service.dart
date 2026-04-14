import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/common.dart';
import '../models/provider_specs.dart';

class ProviderSpecService {
  const ProviderSpecService();

  static const String _assetPath = 'assets/config/provider_specs.json';
  static Future<ProviderSpecCatalog>? _catalogFuture;

  Future<ProviderSpecCatalog> loadCatalog() {
    return _catalogFuture ??= _loadCatalog();
  }

  Future<ProviderSpec> getSpec(ProviderType providerType) async {
    final catalog = await loadCatalog();
    return catalog.specFor(providerType);
  }

  Future<ProviderSpecCatalog> _loadCatalog() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('invalid_provider_specs_asset');
    }
    return ProviderSpecCatalog.fromJson(decoded);
  }
}
