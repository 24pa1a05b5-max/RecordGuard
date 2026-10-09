import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/finding.dart';
import 'package:frontend/shared/widgets/priority_badge.dart';
import 'package:frontend/shared/widgets/evidence_modal.dart';
import 'package:frontend/shared/widgets/review_modal.dart';

class FindingCard extends StatelessWidget {
  final Finding finding;
  final VoidCallback? onReviewed;

  const FindingCard({super.key, required this.finding, this.onReviewed});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: finding.classification == 'POTENTIAL_CONTRADICTION'
              ? AppTheme.dangerRose.withOpacity(0.3)
              : AppTheme.borderSubtle,
          width: finding.classification == 'POTENTIAL_CONTRADICTION'
              ? 1.5
              : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Wrap: Category, Classification Badge, Priority, Status
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "#${finding.id.length >= 8 ? finding.id.substring(0, 8) : finding.id}",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        finding.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: finding.classificationDisplay,
                      color: finding.classificationColor,
                      icon: Icons.shield_outlined,
                    ),
                    StatusBadge(
                      label: finding.priorityLevel.replaceAll('_', ' '),
                      color: finding.priorityColor,
                    ),
                    if (finding.clinicallyVerified)
                      const StatusBadge(
                        label: "Clinician Verified",
                        color: AppTheme.successGreen,
                        icon: Icons.verified,
                      ),
                    if (finding.modelConfidence != null)
                      StatusBadge(
                        label:
                            "AI Conf: ${(finding.modelConfidence! * 100).toStringAsFixed(0)}%",
                        color: AppTheme.accentBlue,
                        icon: Icons.psychology,
                      ),
                  ],
                ),
                _buildStatusIndicator(finding.currentStatus),
              ],
            ),
            const SizedBox(height: 12),

            // Field Compared Title
            Text(
              finding.fieldCompared,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),

            // Clinically Verified Conclusion
            if (finding.clinicallyVerified && finding.verifiedConclusion != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CLINICALLY VERIFIED CONCLUSION",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            finding.verifiedConclusion!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Uncertainty or Limitations Note
            if (finding.uncertaintyNotes != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Limitation / Uncertainty: ${finding.uncertaintyNotes}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Side-by-side statements preview (Responsive: Column on Mobile, Row on Desktop)
            if (isMobile)
              Column(
                children: [
                  _buildSnippetBox(
                    "DOC A: ${finding.docAName}",
                    finding.snippetA,
                    finding.dateA,
                    finding.pageA,
                  ),
                  const SizedBox(height: 8),
                  _buildSnippetBox(
                    "DOC B: ${finding.docBName}",
                    finding.snippetB,
                    finding.dateB,
                    finding.pageB,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSnippetBox(
                      "DOC A: ${finding.docAName}",
                      finding.snippetA,
                      finding.dateA,
                      finding.pageA,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSnippetBox(
                      "DOC B: ${finding.docBName}",
                      finding.snippetB,
                      finding.dateB,
                      finding.pageB,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.accentTeal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      finding.explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryNavy,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bottom Actions (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 14,
                      color: AppTheme.successGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Evidence Verified (${(finding.traceabilityScore * 100).toInt()}% Traceable)",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => EvidenceModal.show(context, finding),
                      icon: const Icon(Icons.find_in_page_outlined, size: 14),
                      label: const Text("Show Evidence"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => ReviewModal.show(context, finding),
                      icon: const Icon(Icons.rate_review_outlined, size: 14),
                      label: Text(
                        finding.currentStatus == 'PENDING_REVIEW'
                            ? "Verify & Resolve"
                            : "Edit Decision",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            finding.currentStatus == 'PENDING_REVIEW'
                            ? AppTheme.accentTeal
                            : AppTheme.secondaryNavy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippetBox(
    String header,
    String snippet,
    String? date,
    int? page,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  header,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                page != null ? "p.$page" : "Page unavailable",
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                  fontStyle: page == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
              date,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '"$snippet"',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'CONFIRMED':
        color = AppTheme.dangerRose;
        icon = Icons.warning;
        text = "Confirmed Contradiction";
        break;
      case 'DISMISSED':
      case 'RESOLVED':
        color = AppTheme.successGreen;
        icon = Icons.check_circle;
        text = "Dismissed / Resolved";
        break;
      case 'REVIEWED':
        color = AppTheme.accentTeal;
        icon = Icons.verified_user_outlined;
        text = "Human Reviewed";
        break;
      case 'REQUIRES_MORE_INFO':
      case 'REQUESTED_DOCS':
        color = AppTheme.warningAmber;
        icon = Icons.assignment_late_outlined;
        text = "Requires More Info";
        break;
      case 'UNRESOLVED':
      case 'PENDING_REVIEW':
      case 'PENDING':
      default:
        color = const Color(0xFF64748B);
        icon = Icons.hourglass_top;
        text = "Pending Review";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
