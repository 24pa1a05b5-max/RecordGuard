import 'package:frontend/models/finding.dart';

class Comparison {
  final String id;
  final String patientId;
  final String documentAId;
  final String documentBId;
  final String? documentAName;
  final String? documentBName;
  final String title;
  final String status;
  final int totalFindings;
  final int contradictionCount;
  final String createdAt;
  final List<Finding> findings;

  Comparison({
    required this.id,
    required this.patientId,
    required this.documentAId,
    required this.documentBId,
    this.documentAName,
    this.documentBName,
    required this.title,
    required this.status,
    required this.totalFindings,
    required this.contradictionCount,
    required this.createdAt,
    this.findings = const [],
  });

  factory Comparison.fromJson(Map<String, dynamic> json) {
    var rawFindings = json['findings'] as List? ?? [];
    List<Finding> list = rawFindings.map((f) => Finding.fromJson(f)).toList();

    return Comparison(
      id: json['id'] ?? '',
      patientId: json['patient_id'] ?? '',
      documentAId: json['document_a_id'] ?? '',
      documentBId: json['document_b_id'] ?? '',
      documentAName: json['document_a_name'],
      documentBName: json['document_b_name'],
      title: json['title'] ?? '',
      status: json['status'] ?? '',
      totalFindings: json['total_findings'] ?? 0,
      contradictionCount: json['contradiction_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      findings: list,
    );
  }
}
