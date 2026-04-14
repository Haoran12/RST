import 'common.dart';

enum ApiParameterKey {
  stream,
  temperature,
  topP,
  topK,
  presencePenalty,
  frequencyPenalty,
  maxCompletionTokens,
  stopSequences,
  reasoningEffort,
  verbosity,
}

extension ApiParameterKeyX on ApiParameterKey {
  String get wireValue {
    return switch (this) {
      ApiParameterKey.temperature => 'temperature',
      ApiParameterKey.stream => 'stream',
      ApiParameterKey.topP => 'topP',
      ApiParameterKey.topK => 'topK',
      ApiParameterKey.presencePenalty => 'presencePenalty',
      ApiParameterKey.frequencyPenalty => 'frequencyPenalty',
      ApiParameterKey.maxCompletionTokens => 'maxCompletionTokens',
      ApiParameterKey.stopSequences => 'stopSequences',
      ApiParameterKey.reasoningEffort => 'reasoningEffort',
      ApiParameterKey.verbosity => 'verbosity',
    };
  }
}

ApiParameterKey apiParameterKeyFromWire(Object? raw) {
  final value = '$raw'.trim();
  return switch (value) {
    'temperature' => ApiParameterKey.temperature,
    'stream' => ApiParameterKey.stream,
    'topP' => ApiParameterKey.topP,
    'topK' => ApiParameterKey.topK,
    'presencePenalty' => ApiParameterKey.presencePenalty,
    'frequencyPenalty' => ApiParameterKey.frequencyPenalty,
    'maxCompletionTokens' => ApiParameterKey.maxCompletionTokens,
    'stopSequences' => ApiParameterKey.stopSequences,
    'reasoningEffort' => ApiParameterKey.reasoningEffort,
    'verbosity' => ApiParameterKey.verbosity,
    _ => throw StateError('unknown_api_parameter_key: $raw'),
  };
}

enum ApiParameterValueType { boolean, number, integer, text, stringList }

ApiParameterValueType apiParameterValueTypeFromWire(Object? raw) {
  final value = '$raw'.trim();
  return switch (value) {
    'boolean' => ApiParameterValueType.boolean,
    'number' => ApiParameterValueType.number,
    'integer' => ApiParameterValueType.integer,
    'text' => ApiParameterValueType.text,
    'stringList' => ApiParameterValueType.stringList,
    _ => throw StateError('unknown_api_parameter_value_type: $raw'),
  };
}

class ProviderParameterSpec {
  const ProviderParameterSpec({
    required this.key,
    required this.label,
    required this.valueType,
    required this.requestField,
    this.required = false,
    this.defaultValueLabel,
    this.defaultSource,
    this.description,
    this.placeholder,
    this.appFallbackValue,
  });

  final ApiParameterKey key;
  final String label;
  final ApiParameterValueType valueType;
  final String requestField;
  final bool required;
  final String? defaultValueLabel;
  final String? defaultSource;
  final String? description;
  final String? placeholder;
  final Object? appFallbackValue;

  factory ProviderParameterSpec.fromJson(Map<String, dynamic> json) {
    return ProviderParameterSpec(
      key: apiParameterKeyFromWire(json['key']),
      label: '${json['label'] ?? ''}'.trim(),
      valueType: apiParameterValueTypeFromWire(json['valueType']),
      requestField: '${json['requestField'] ?? ''}'.trim(),
      required: json['required'] == true,
      defaultValueLabel: _normalizeOptional(json['defaultValueLabel']),
      defaultSource: _normalizeOptional(json['defaultSource']),
      description: _normalizeOptional(json['description']),
      placeholder: _normalizeOptional(json['placeholder']),
      appFallbackValue: json['appFallbackValue'],
    );
  }

  String buildHelperText() {
    final parts = <String>[];
    parts.add(required ? 'Required' : 'Optional');
    if (defaultValueLabel != null && defaultValueLabel!.isNotEmpty) {
      parts.add('Default: $defaultValueLabel');
    } else if (defaultSource != null && defaultSource!.isNotEmpty) {
      parts.add('Default: $defaultSource');
    }
    if (description != null && description!.isNotEmpty) {
      parts.add(description!);
    }
    if (required && appFallbackValue != null) {
      parts.add('If unset, app fallback will be used.');
    }
    return parts.join('  ');
  }
}

class ProviderSpec {
  const ProviderSpec({
    required this.providerType,
    required this.label,
    required this.shortDescription,
    required this.defaultBaseUrl,
    required this.defaultRequestPath,
    required this.defaultModel,
    required this.documentationUrl,
    this.notes = const <String>[],
    this.parameters = const <ProviderParameterSpec>[],
  });

  final ProviderType providerType;
  final String label;
  final String shortDescription;
  final String defaultBaseUrl;
  final String defaultRequestPath;
  final String defaultModel;
  final String documentationUrl;
  final List<String> notes;
  final List<ProviderParameterSpec> parameters;

  ProviderParameterSpec? parameterFor(ApiParameterKey key) {
    for (final parameter in parameters) {
      if (parameter.key == key) {
        return parameter;
      }
    }
    return null;
  }

  bool supports(ApiParameterKey key) => parameterFor(key) != null;

  factory ProviderSpec.fromJson(Map<String, dynamic> json) {
    return ProviderSpec(
      providerType: providerTypeFromWire(json['providerType']),
      label: '${json['label'] ?? ''}'.trim(),
      shortDescription: '${json['shortDescription'] ?? ''}'.trim(),
      defaultBaseUrl: '${json['defaultBaseUrl'] ?? ''}'.trim(),
      defaultRequestPath: '${json['defaultRequestPath'] ?? ''}'.trim(),
      defaultModel: '${json['defaultModel'] ?? ''}'.trim(),
      documentationUrl: '${json['documentationUrl'] ?? ''}'.trim(),
      notes: _parseStringList(json['notes']),
      parameters: _parseParameterSpecs(json['parameters']),
    );
  }
}

class ProviderSpecCatalog {
  const ProviderSpecCatalog({required this.version, required this.providers});

  final int version;
  final List<ProviderSpec> providers;

  ProviderSpec specFor(ProviderType providerType) {
    for (final provider in providers) {
      if (provider.providerType == providerType) {
        return provider;
      }
    }
    throw StateError('provider_spec_not_found: ${providerType.wireValue}');
  }

  factory ProviderSpecCatalog.fromJson(Map<String, dynamic> json) {
    final providersRaw = json['providers'];
    final providers = <ProviderSpec>[];
    if (providersRaw is List) {
      for (final item in providersRaw) {
        if (item is Map<String, dynamic>) {
          providers.add(ProviderSpec.fromJson(item));
        } else if (item is Map) {
          providers.add(ProviderSpec.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return ProviderSpecCatalog(
      version: _parseInt(json['version']) ?? 1,
      providers: providers,
    );
  }
}

List<ProviderParameterSpec> _parseParameterSpecs(Object? raw) {
  if (raw is! List) {
    return const <ProviderParameterSpec>[];
  }
  final items = <ProviderParameterSpec>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      items.add(ProviderParameterSpec.fromJson(item));
    } else if (item is Map) {
      items.add(ProviderParameterSpec.fromJson(item.cast<String, dynamic>()));
    }
  }
  return items;
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _normalizeOptional(Object? value) {
  final normalized = '$value'.trim();
  return normalized.isEmpty || normalized == 'null' ? null : normalized;
}

int? _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value'.trim());
}
