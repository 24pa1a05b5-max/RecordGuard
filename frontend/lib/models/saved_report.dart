class SavedReport {
  final String id;
  final String? userId;
  final String userName;
  final String? patientId;
  final String patientName;
  final String reportTitle;
  final String reportType;
  final String? summary;
  final int totalFindings;
  final int contradictionsCount;
  final int verifiedCount;
  final String? reportData;
  final String fileFormat;
  final String createdAt;

  SavedReport({
    required this.id,
    this.userId,
    required this.userName,
    this.patientId,
    required this.patientName,
    required this.reportTitle,
    this.reportType = "CLINICAL_RECONCILIATION",
    this.summary,
    this.totalFindings = 0,
    this.contradictionsCount = 0,
    this.verifiedCount = 0,
    this.reportData,
    this.fileFormat = "PDF",
    required this.createdAt,
  });

  factory SavedReport.fromJson(Map<String, dynamic> json) {
    return SavedReport(
      id: json['id'] ?? '',
      userId: json['user_id'],
      userName: json['user_name'] ?? 'Clinician Reviewer',
      patientId: json['patient_id'],
      patientName: json['patient_name'] ?? 'General Clinical Case',
      reportTitle: json['report_title'] ?? 'Clinical Reconciliation Report',
      reportType: json['report_type'] ?? 'CLINICAL_RECONCILIATION',
      summary: json['summary'],
      totalFindings: (json['total_findings'] as num?)?.toInt() ?? 0,
      contradictionsCount: (json['contradictions_count'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      reportData: json['report_data'],
      fileFormat: json['file_format'] ?? 'PDF',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'patient_id': patientId,
      'patient_name': patientName,
      'report_title': reportTitle,
      'report_type': reportType,
      'summary': summary,
      'total_findings': totalFindings,
      'contradictions_count': contradictionsCount,
      'verified_count': verifiedCount,
      'report_data': reportData,
      'file_format': fileFormat,
      'created_at': createdAt,
    };
  }
}
