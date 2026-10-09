import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/shared/widgets/finding_card.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(reviewQueueProvider);

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
                  child: Icon(
                    Icons.assignment_late,
                    color: AppTheme.dangerRose,
                    size: 24,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Risk-Aware Clinical Review Queue",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Deterministic triaging routes acute safety conflicts (e.g., allergy discrepancies) for urgent verification.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Prioritization Policy Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TRANSPARENT TRIAGING CRITERIA",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Findings are ranked strictly by deterministic clinical impact rules, not speculative AI risk scores:\n"
                    "• Priority Review: Direct allergy conflicts (risk of anaphylaxis) or concurrent contradictory dosages.\n"
                    "• Standard Review: Documented chronological discontinuations and serial lab value variations.\n"
                    "• Awaiting Evidence: Unmentioned sections (omissions are not proof of absence).",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.secondaryNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            queueAsync.when(
              data: (findings) {
                if (findings.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.done_all,
                          color: AppTheme.successGreen,
                          size: 40,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Queue is Clear",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "All flagged clinical discrepancies have been reviewed and audited.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: findings.length,
                  itemBuilder: (ctx, idx) {
                    final f = findings[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (f.priorityReason != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: f.priorityColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Triage Rationale: ${f.priorityReason}",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: f.priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        FindingCard(
                          finding: f,
                          onReviewed: () => ref
                              .read(refreshTriggerProvider.notifier)
                              .trigger(),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text("Failed to load queue: $e"),
            ),
          ],
        ),
      ),
    );
  }
}
