import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/shared/widgets/stat_card.dart';
import 'package:frontend/shared/widgets/finding_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final queueAsync = ref.watch(reviewQueueProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header with Quick Actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Clinical Reconciliation Overview",
                        style: TextStyle(
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Real-time surveillance of cross-provider electronic health record discrepancies.",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/patients'),
                      icon: const Icon(Icons.people_alt_outlined, size: 15),
                      label: const Text("Patients"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/compare'),
                      icon: const Icon(Icons.compare_arrows, size: 15),
                      label: const Text("Analyze & Compare"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Persistent KPI Metrics Row
            statsAsync.when(
              data: (stats) => LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final cards = [
                    StatCard(
                      title: "Patient Profiles",
                      value: stats.totalPatients.toString(),
                      subtitle: "Fictional cohorts registered",
                      icon: Icons.personal_injury_outlined,
                      accentColor: AppTheme.accentTeal,
                      onTap: () => context.go('/patients'),
                    ),
                    StatCard(
                      title: "Ingested Documents",
                      value: stats.totalDocuments.toString(),
                      subtitle: "EHR summaries & lab panels",
                      icon: Icons.description_outlined,
                      accentColor: AppTheme.accentBlue,
                      onTap: () => context.go('/patients'),
                    ),
                    StatCard(
                      title: "Pending Discrepancies",
                      value: stats.pendingDiscrepancies.toString(),
                      subtitle: "Cross-record conflicts",
                      icon: Icons.warning_amber_rounded,
                      accentColor: stats.pendingDiscrepancies > 0
                          ? AppTheme.dangerRose
                          : AppTheme.successGreen,
                      onTap: () => context.go('/workspace'),
                    ),
                    StatCard(
                      title: "Verified & Resolved",
                      value: stats.resolvedFindings.toString(),
                      subtitle: "Audited resolutions",
                      icon: Icons.check_circle_outline,
                      accentColor: AppTheme.successGreen,
                      onTap: () => context.go('/workspace'),
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards
                          .map(
                            (c) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: c,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  } else {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                      children: cards,
                    );
                  }
                },
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Failed to load dashboard metrics: $e",
                  style: const TextStyle(color: AppTheme.dangerRose),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // High Priority Review Queue Section
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_late,
                      color: AppTheme.dangerRose,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Priority Review Queue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/queue'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View All in Queue",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            queueAsync.when(
              data: (findings) {
                if (findings.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 36,
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "All Cross-Record Discrepancies Addressed",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "No pending discrepancies currently require authorized review.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/compare'),
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text("Compare New Documents"),
                        ),
                      ],
                    ),
                  );
                }

                // Show top 3 pending findings
                final previewList = findings.take(3).toList();
                return Column(
                  children: previewList
                      .map(
                        (f) => FindingCard(
                          finding: f,
                          onReviewed: () => ref
                              .read(refreshTriggerProvider.notifier)
                              .trigger(),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text("Error loading queue: $e"),
            ),
          ],
        ),
      ),
    );
  }
}
