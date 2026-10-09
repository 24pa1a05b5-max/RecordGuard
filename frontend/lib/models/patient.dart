class Patient {
  final String id;
  final String fullName;
  final String? birthDate;
  final String? gender;
  final String mrn;
  final bool isSynthetic;
  final String? notes;
  final int documentCount;
  final int comparisonCount;
  final String createdAt;

  Patient({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.gender,
    required this.mrn,
    this.isSynthetic = true,
    this.notes,
    this.documentCount = 0,
    this.comparisonCount = 0,
    required this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      birthDate: json['birth_date'],
      gender: json['gender'],
      mrn: json['mrn'] ?? '',
      isSynthetic: json['is_synthetic'] ?? true,
      notes: json['notes'],
      documentCount: json['document_count'] ?? 0,
      comparisonCount: json['comparison_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
