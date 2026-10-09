class SystemHealth {
  final String status;
  final String version;
  final String environment;
  final String database;
  final bool ocrAvailable;
  final bool modelAvailable;
  final bool demoMode;

  SystemHealth({
    required this.status,
    required this.version,
    required this.environment,
    required this.database,
    required this.ocrAvailable,
    required this.modelAvailable,
    required this.demoMode,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      status: json['status'] ?? 'unknown',
      version: json['version'] ?? '1.0.0',
      environment: json['environment'] ?? 'development',
      database: json['database'] ?? 'unknown',
      ocrAvailable: json['ocr_available'] ?? false,
      modelAvailable: json['model_available'] ?? false,
      demoMode: json['demo_mode'] ?? true,
    );
  }
}

class ModelMetrics {
  final String modelType;
  final String modelVersion;
  final String trainedAt;
  final int datasetSize;
  final int trainSize;
  final int valSize;
  final int testSize;
  final Map<String, dynamic> classDistribution;
  final double accuracy;
  final double macroF1;
  final Map<String, dynamic> perClassMetrics;
  final Map<String, dynamic> confusionMatrix;
  final List<String> limitations;
  final String disclosure;

  ModelMetrics({
    required this.modelType,
    required this.modelVersion,
    required this.trainedAt,
    required this.datasetSize,
    required this.trainSize,
    required this.valSize,
    required this.testSize,
    required this.classDistribution,
    required this.accuracy,
    required this.macroF1,
    required this.perClassMetrics,
    required this.confusionMatrix,
    required this.limitations,
    required this.disclosure,
  });

  factory ModelMetrics.fromJson(Map<String, dynamic> json) {
    var rawLimits = json['limitations'] as List? ?? [];
    List<String> limits = rawLimits.map((e) => e.toString()).toList();

    return ModelMetrics(
      modelType: json['model_type'] ?? '',
      modelVersion: json['model_version'] ?? '1.0.0',
      trainedAt: json['trained_at'] ?? '',
      datasetSize: json['dataset_size'] ?? 0,
      trainSize: json['train_size'] ?? 0,
      valSize: json['val_size'] ?? 0,
      testSize: json['test_size'] ?? 0,
      classDistribution: json['class_distribution'] ?? {},
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      macroF1: (json['macro_f1'] as num?)?.toDouble() ?? 0.0,
      perClassMetrics: json['per_class_metrics'] ?? {},
      confusionMatrix: json['confusion_matrix'] ?? {},
      limitations: limits,
      disclosure: json['disclosure'] ?? '',
    );
  }
}
