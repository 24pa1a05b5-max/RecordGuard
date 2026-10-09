import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/finding.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/shared/widgets/priority_badge.dart';

class EvidenceModal extends ConsumerWidget {
  final Finding finding;

  const EvidenceModal({super.key, required this.finding});

  static void show(BuildContext context, Finding finding) {
    showDialog(
      context: context,
      builder: (ctx) => EvidenceModal(finding: finding),
    );
  }

  void _showFullDocumentDialog(
    BuildContext context,
    WidgetRef ref,
    String? docId,
    String docName,
  ) {
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document identifier is unavailable.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiServiceProvider).getDocumentRaw(docId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text("Document Load Error"),
              content: Text("Failed to retrieve document: ${snapshot.error}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          }
          final doc = snapshot.data!;
          final rawText = doc["raw_text"] ?? "No text content available.";
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc["original_name"] ?? docName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Provider: ${doc['provider_name']} | Type: ${doc['file_type']} | Date: ${doc['document_date'] ?? 'N/A'}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      "FULL EXTRACTED DOCUMENT TEXT (VERBATIM PROVENANCE):",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            rawText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              color: Color(0xFF0F172A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 980 : 720,
          maxHeight: size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                "ID: #${finding.id.length >= 8 ? finding.id.substring(0, 8) : finding.id}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: finding.classificationDisplay,
                              color: finding.classificationColor,
                              icon: Icons.shield_outlined,
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: finding.priorityLevel.replaceAll('_', ' '),
                              color: finding.priorityColor,
                            ),
                            if (finding.clinicallyVerified) ...[
                              const SizedBox(width: 8),
                              const StatusBadge(
                                label: "Clinician Verified",
                                color: AppTheme.successGreen,
                                icon: Icons.verified,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Side-by-Side Evidence Provenance: ${finding.fieldCompared}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Body (Scrollable)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clinically Verified Banner if present
                      if (finding.clinicallyVerified &&
                          finding.verifiedConclusion != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF16A34A),
                                size: 18,
                              ),
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
                                        fontSize: 13,
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

                      // Limitations & Uncertainty Banner
                      if (finding.uncertaintyNotes != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "EVIDENCE LIMITATION & UNCERTAINTY",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      finding.uncertaintyNotes!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Side by Side Evidence Cards
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSourcePanel(
                                context,
                                ref,
                                "DOCUMENT A",
                                finding.documentAId,
                                finding.docAName,
                                finding.providerA,
                                finding.dateA,
                                finding.pageA,
                                finding.unitA,
                                finding.statusA,
                                finding.snippetA,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSourcePanel(
                                context,
                                ref,
                                "DOCUMENT B",
                                finding.documentBId,
                                finding.docBName,
                                finding.providerB,
                                finding.dateB,
                                finding.pageB,
                                finding.unitB,
                                finding.statusB,
                                finding.snippetB,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildSourcePanel(
                          context,
                          ref,
                          "DOCUMENT A",
                          finding.documentAId,
                          finding.docAName,
                          finding.providerA,
                          finding.dateA,
                          finding.pageA,
                          finding.unitA,
                          finding.statusA,
                          finding.snippetA,
                        ),
                        const SizedBox(height: 16),
                        _buildSourcePanel(
                          context,
                          ref,
                          "DOCUMENT B",
                          finding.documentBId,
                          finding.docBName,
                          finding.providerB,
                          finding.dateB,
                          finding.pageB,
                          finding.unitB,
                          finding.statusB,
                          finding.snippetB,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Clinical Reasoning Panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: AppTheme.accentTeal,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Clinical Reasoning & Rule Traceability",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              finding.explanation,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppTheme.secondaryNavy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Recommendation: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    finding.recommendation,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Evidence Quality Metrics
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "EVIDENCE QUALITY ASSESSMENT",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 20,
                              runSpacing: 10,
                              children: [
                                _buildMetricItem(
                                  "Completeness",
                                  "${(finding.evidenceCompleteness * 100).toInt()}%",
                                  Icons.check_circle_outline,
                                  AppTheme.successGreen,
                                ),
                                _buildMetricItem(
                                  "Traceability",
                                  "${(finding.traceabilityScore * 100).toInt()}%",
                                  Icons.find_in_page_outlined,
                                  AppTheme.accentTeal,
                                ),
                                if (finding.modelConfidence != null)
                                  _buildMetricItem(
                                    "AI Confidence",
                                    "${(finding.modelConfidence! * 100).toStringAsFixed(1)}%",
                                    Icons.psychology_outlined,
                                    AppTheme.accentBlue,
                                  ),
                                _buildMetricItem(
                                  "Review Status",
                                  finding.currentStatus.replaceAll('_', ' '),
                                  Icons.flag_outlined,
                                  AppTheme.warningAmber,
                                ),
                              ],
                            ),
                            if (finding.temporalContext != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                "Temporal Context: ${finding.temporalContext}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourcePanel(
    BuildContext context,
    WidgetRef ref,
    String tag,
    String? docId,
    String docName,
    String provider,
    String? date,
    int? page,
    String? unit,
    String? status,
    String snippet,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentTeal,
                  ),
                ),
              ),
              Text(
                page != null ? "Page $page" : "Page unavailable",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  fontStyle: page == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            docName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.primaryNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (docId != null) ...[
            const SizedBox(height: 2),
            Text(
              "Doc ID: #${docId.length >= 8 ? docId.substring(0, 8) : docId}",
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_pin, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  provider,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
          if (unit != null || status != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (unit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Unit: $unit",
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Status: $status",
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            "VERIFIED EXTRACTED TEXT:",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '"$snippet"',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  _showFullDocumentDialog(context, ref, docId, docName),
              icon: const Icon(Icons.source_outlined, size: 14),
              label: const Text(
                "Inspect Full Document",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppTheme.accentTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
