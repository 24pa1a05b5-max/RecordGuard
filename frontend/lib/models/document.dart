class ClinicalDocument {
  final String id;
  final String patientId;
  final String filename;
  final String originalName;
  final String fileType;
  final int fileSizeBytes;
  final String providerName;
  final String providerSpecialty;
  final String documentType;
  final String? documentDate;
  final int totalPages;
  final bool ocrApplied;
  final String createdAt;

  ClinicalDocument({
    required this.id,
    required this.patientId,
    required this.filename,
    required this.originalName,
    required this.fileType,
    required this.fileSizeBytes,
    required this.providerName,
    required this.providerSpecialty,
    required this.documentType,
    this.documentDate,
    required this.totalPages,
    required this.ocrApplied,
    required this.createdAt,
  });

  factory ClinicalDocument.fromJson(Map<String, dynamic> json) {
    return ClinicalDocument(
      id: json['id'] ?? '',
      patientId: json['patient_id'] ?? '',
      filename: json['filename'] ?? '',
      originalName: json['original_name'] ?? '',
      fileType: json['file_type'] ?? '',
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      providerName: json['provider_name'] ?? '',
      providerSpecialty: json['provider_specialty'] ?? '',
      documentType: json['document_type'] ?? '',
      documentDate: json['document_date'],
      totalPages: json['total_pages'] ?? 1,
      ocrApplied: json['ocr_applied'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
