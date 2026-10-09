import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/shared/widgets/finding_card.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';

  final List<String> _categories = [
    'ALL',
    'ALLERGY',
    'MEDICATION',
    'DIAGNOSIS',
    'LAB_RESULT',
  ];

  final List<String> _statuses = [
    'ALL',
    'PENDING_REVIEW',
    'CONFIRMED',
    'RESOLVED',
    'UNRESOLVED',
    'REQUESTED_DOCS',
  ];

  @override
  Widget build(BuildContext context) {
    final findingsAsync = ref.watch(findingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Contradiction Review Workspace",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Inspect evidence provenance, evaluate uncertainty, and record human clinical verifications.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.go('/account'),
                      icon: const Icon(Icons.bookmark_add, size: 15),
                      label: const Text("Save Report to Account"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(refreshTriggerProvider.notifier).trigger(),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text("Refresh"),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CLINICAL SURVEILLANCE FILTERS",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      // Category Filter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Category: ",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _selectedCategory,
                            underline: const SizedBox(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.accentTeal,
                              fontWeight: FontWeight.w700,
                            ),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c == 'ALL' ? 'All Categories' : c,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v!),
                          ),
                        ],
                      ),

                      // Status Filter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Status: ",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _selectedStatus,
                            underline: const SizedBox(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.accentTeal,
                              fontWeight: FontWeight.w700,
                            ),
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.replaceAll('_', ' ')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedStatus = v!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Findings List
            findingsAsync.when(
              data: (findings) {
                final filtered = findings.where((f) {
                  if (_selectedCategory != 'ALL' &&
                      f.category != _selectedCategory) {
                    return false;
                  }
                  if (_selectedStatus != 'ALL' &&
                      f.currentStatus != _selectedStatus) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Center(
                      child: Text(
                        "No clinical findings matching the selected filters.",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) => FindingCard(
                    finding: filtered[idx],
                    onReviewed: () =>
                        ref.read(refreshTriggerProvider.notifier).trigger(),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text("Failed to load findings: $e"),
            ),
          ],
        ),
      ),
    );
  }
}
