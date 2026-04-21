// 验证严重程度
enum ValidationSeverity {
  info('info', '信息'),
  warning('warning', '警告'),
  error('error', '错误');

  const ValidationSeverity(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

ValidationSeverity validationSeverityFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'info' => ValidationSeverity.info,
    'warning' => ValidationSeverity.warning,
    'error' => ValidationSeverity.error,
    _ => ValidationSeverity.info,
  };
}

// 验证结果
class ValidationResult {
  const ValidationResult({
    required this.ruleId,
    required this.severity,
    required this.message,
    this.details,
    this.context,
  });

  final String ruleId;
  final ValidationSeverity severity;
  final String message;
  final String? details;
  final Map<String, dynamic>? context;

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;
  bool get isInfo => severity == ValidationSeverity.info;

  ValidationResult copyWith({
    String? ruleId,
    ValidationSeverity? severity,
    String? message,
    String? details,
    bool clearDetails = false,
    Map<String, dynamic>? context,
    bool clearContext = false,
  }) {
    return ValidationResult(
      ruleId: ruleId ?? this.ruleId,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      details: clearDetails ? null : (details ?? this.details),
      context: clearContext ? null : (context ?? this.context),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ruleId': ruleId,
      'severity': severity.wireValue,
      'message': message,
      'details': details,
      'context': context,
    };
  }

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      ruleId: '${json['ruleId'] ?? ''}',
      severity: validationSeverityFromWire(json['severity']),
      message: '${json['message'] ?? ''}',
      details: _normalizeOptional(json['details']),
      context: json['context'] != null
          ? Map<String, dynamic>.from(json['context'])
          : null,
    );
  }
}

String? _normalizeOptional(Object? raw) {
  final normalized = '$raw'.trim();
  if (normalized.isEmpty || normalized == 'null') return null;
  return normalized;
}
