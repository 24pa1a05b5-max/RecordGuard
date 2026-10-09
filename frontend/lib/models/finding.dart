import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class ReviewDecision {
  final String id;
  final String findingId;
  final String reviewerName;
  final String previousStatus;
  final String newStatus;
  final String decisionReason;
  final String? clinicalNotes;
  final String createdAt;

  ReviewDecision({
    required this.id,
    required this.findingId,
    required this.reviewerName,
    required this.previousStatus,
    required this.newStatus,
    required this.decisionReason,
    this.clinicalNotes,
    required this.createdAt,
  });

  factory ReviewDecision.fromJson(Map<String, dynamic> json) {
    return ReviewDecision(
      id: json['id'] ?? '',
      findingId: json['finding_id'] ?? '',
      reviewerName: json['reviewer_name'] ?? '',
      previousStatus: json['previous_status'] ?? '',
      newStatus: json['new_status'] ?? '',
      decisionReason: json['decision_reason'] ?? '',
      clinicalNotes: json['clinical_notes'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Finding {
  final String id;
  final String comparisonId;
  final String patientId;
  final String? documentAId;
  final String? documentBId;
  final String? statementAId;
  final String? statementBId;
  final String category;
  final String fieldCompared;
  final String statementAText;
  final String statementBText;
  final String docAName;
  final String docBName;
  final String providerA;
  final String providerB;
  final String? dateA;
  final String? dateB;
  final int? pageA;
  final int? pageB;
  final String? unitA;
  final String? unitB;
  final String? statusA;
  final String? statusB;
  final String snippetA;
  final String snippetB;
  final String classification;
  final String priorityLevel;
  final String? priorityReason;
  final String? ruleTriggered;
  final double? modelConfidence;
  final double evidenceCompleteness;
  final double traceabilityScore;
  final String? temporalContext;
  final String? uncertaintyNotes;
  final String explanation;
  final String recommendation;
  final String currentStatus;
  final String? lastReviewedBy;
  final String? lastReviewedAt;
  final bool clinicallyVerified;
  final String? verifiedConclusion;
  final String createdAt;
  final List<ReviewDecision> reviews;

  Finding({
    required this.id,
    required this.comparisonId,
    required this.patientId,
    this.documentAId,
    this.documentBId,
    this.statementAId,
    this.statementBId,
    required this.category,
    required this.fieldCompared,
    required this.statementAText,
    required this.statementBText,
    required this.docAName,
    required this.docBName,
    required this.providerA,
    required this.providerB,
    this.dateA,
    this.dateB,
    this.pageA,
    this.pageB,
    this.unitA,
    this.unitB,
    this.statusA,
    this.statusB,
    required this.snippetA,
    required this.snippetB,
    required this.classification,
    required this.priorityLevel,
    this.priorityReason,
    this.ruleTriggered,
    this.modelConfidence,
    this.evidenceCompleteness = 1.0,
    this.traceabilityScore = 1.0,
    this.temporalContext,
    this.uncertaintyNotes,
    required this.explanation,
    required this.recommendation,
    required this.currentStatus,
    this.lastReviewedBy,
    this.lastReviewedAt,
    this.clinicallyVerified = false,
    this.verifiedConclusion,
    required this.createdAt,
    this.reviews = const [],
  });

  factory Finding.fromJson(Map<String, dynamic> json) {
    var rawReviews = json['reviews'] as List? ?? [];
    List<ReviewDecision> revList = rawReviews
        .map((r) => ReviewDecision.fromJson(r))
        .toList();

    return Finding(
      id: json['id'] ?? '',
      comparisonId: json['comparison_id'] ?? '',
      patientId: json['patient_id'] ?? '',
      documentAId: json['document_a_id'] ?? json['doc_a_id'],
      documentBId: json['document_b_id'] ?? json['doc_b_id'],
      statementAId: json['statement_a_id'],
      statementBId: json['statement_b_id'],
      category: json['category'] ?? '',
      fieldCompared: json['field_compared'] ?? '',
      statementAText: json['statement_a_text'] ?? '',
      statementBText: json['statement_b_text'] ?? '',
      docAName: json['doc_a_name'] ?? '',
      docBName: json['doc_b_name'] ?? '',
      providerA: json['provider_a'] ?? '',
      providerB: json['provider_b'] ?? '',
      dateA: json['date_a'],
      dateB: json['date_b'],
      pageA: json['page_a'],
      pageB: json['page_b'],
      unitA: json['unit_a'],
      unitB: json['unit_b'],
      statusA: json['status_a'],
      statusB: json['status_b'],
      snippetA: json['snippet_a'] ?? '',
      snippetB: json['snippet_b'] ?? '',
      classification: json['classification'] ?? '',
      priorityLevel: json['priority_level'] ?? 'STANDARD_REVIEW',
      priorityReason: json['priority_reason'],
      ruleTriggered: json['rule_triggered'],
      modelConfidence: json['model_confidence'] != null
          ? (json['model_confidence'] as num).toDouble()
          : null,
      evidenceCompleteness:
          (json['evidence_completeness'] as num?)?.toDouble() ?? 1.0,
      traceabilityScore:
          (json['traceability_score'] as num?)?.toDouble() ?? 1.0,
      temporalContext: json['temporal_context'],
      uncertaintyNotes: json['uncertainty_notes'],
      explanation: json['explanation'] ?? '',
      recommendation: json['recommendation'] ?? '',
      currentStatus: json['current_status'] ?? 'PENDING_REVIEW',
      lastReviewedBy: json['last_reviewed_by'],
      lastReviewedAt: json['last_reviewed_at'],
      clinicallyVerified: json['clinically_verified'] == true,
      verifiedConclusion: json['verified_conclusion'],
      createdAt: json['created_at'] ?? '',
      reviews: revList,
    );
  }

  String get classificationDisplay {
    switch (classification) {
      case 'POTENTIAL_CONTRADICTION':
        return 'Potential Contradiction';
      case 'TEMPORAL_CHANGE':
        return 'Possible Temporal Change';
      case 'INCONSISTENT_REPRESENTATION':
        return 'Inconsistent Representation';
      case 'INSUFFICIENT_EVIDENCE':
        return 'Insufficient Evidence';
      case 'CONSISTENT':
      case 'NO_CONTRADICTION':
        return 'Consistent / No Contradiction';
      case 'REQUIRES_REVIEW':
        return 'Requires Professional Review';
      default:
        return classification.replaceAll('_', ' ');
    }
  }

  Color get classificationColor {
    switch (classification) {
      case 'POTENTIAL_CONTRADICTION':
        return AppTheme.dangerRose;
      case 'TEMPORAL_CHANGE':
        return AppTheme.accentBlue;
      case 'INCONSISTENT_REPRESENTATION':
        return AppTheme.warningAmber;
      case 'INSUFFICIENT_EVIDENCE':
        return const Color(0xFF6366F1);
      case 'CONSISTENT':
      case 'NO_CONTRADICTION':
        return AppTheme.successGreen;
      default:
        return AppTheme.secondaryNavy;
    }
  }

  Color get priorityColor {
    switch (priorityLevel) {
      case 'PRIORITY_REVIEW':
        return AppTheme.dangerRose;
      case 'STANDARD_REVIEW':
        return AppTheme.warningAmber;
      case 'LOW_PRIORITY':
        return AppTheme.successGreen;
      case 'AWAITING_EVIDENCE':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF64748B);
    }
  }
}
