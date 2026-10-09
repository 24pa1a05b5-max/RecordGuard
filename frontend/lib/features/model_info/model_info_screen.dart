import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';

class ModelInfoScreen extends ConsumerWidget {
  const ModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(modelMetricsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.psychology, color: AppTheme.accentTeal, size: 24),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Model Transparency & Evaluation Benchmark",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Held-out test set performance, class distributions, and responsible AI disclosures.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mandatory Clinical Safety Disclosure
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.dangerRose,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MANDATORY CLINICAL SAFETY DISCLOSURE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dangerRose,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Trained on synthetic demonstration data. Not clinically validated. Model predictions support record review and do not establish medical truth. Never use this prototype to independently render treatment decisions.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF991B1B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            metricsAsync.when(
              data: (m) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          "HELD-OUT TEST ACCURACY",
                          "${(m.accuracy * 100).toStringAsFixed(1)}%",
                          Icons.verified,
                          AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          "MACRO F1 SCORE",
                          "${(m.macroF1 * 100).toStringAsFixed(1)}%",
                          Icons.auto_graph,
                          AppTheme.accentTeal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          "TOTAL SYNTHETIC EXAMPLES",
                          "${m.datasetSize}",
                          Icons.dataset,
                          AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          "HELD-OUT TEST SET SIZE",
                          "${m.testSize}",
                          Icons.science,
                          const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Architecture & Dataset Specs
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "MODEL ARCHITECTURE & PIPELINE DETAILS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow("Classifier Pipeline", m.modelType),
                        _buildDetailRow("Model Version", m.modelVersion),
                        _buildDetailRow("Training Timestamp", m.trainedAt),
                        _buildDetailRow(
                          "Partition Split",
                          "${m.trainSize} Train (70%)  |  ${m.valSize} Validation (15%)  |  ${m.testSize} Test (15%)",
                        ),
                        _buildDetailRow(
                          "Feature Representation",
                          "TF-IDF Word + Char N-grams combined with dense clinical structured features (Category, Value Agreement, Date Delta, Negation Indicators)",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Per-class metrics table
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HELD-OUT TEST PERFORMANCE BY CLASS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Table(
                          border: TableBorder.all(
                            color: AppTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                              ),
                              children: [
                                _tableHeader("Classification Category"),
                                _tableHeader("Precision"),
                                _tableHeader("Recall"),
                                _tableHeader("F1-Score"),
                                _tableHeader("Test Support"),
                              ],
                            ),
                            ...m.perClassMetrics.entries.map((entry) {
                              final cat = entry.key;
                              final val = entry.value as Map<String, dynamic>;
                              return TableRow(
                                children: [
                                  _tableCell(
                                    cat.replaceAll('_', ' '),
                                    isBold: true,
                                  ),
                                  _tableCell(
                                    "${((val['precision'] as num) * 100).toStringAsFixed(1)}%",
                                  ),
                                  _tableCell(
                                    "${((val['recall'] as num) * 100).toStringAsFixed(1)}%",
                                  ),
                                  _tableCell(
                                    "${((val['f1_score'] as num) * 100).toStringAsFixed(1)}%",
                                  ),
                                  _tableCell("${val['support']}"),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Limitations & Responsible Use
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DOCUMENTED LIMITATIONS & RESPONSIBLE USE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...m.limitations.map(
                          (limit) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "• ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    limit,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.secondaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text("Failed to load model metrics: $e"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppTheme.primaryNavy,
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: AppTheme.secondaryNavy,
        ),
      ),
    );
  }
}
