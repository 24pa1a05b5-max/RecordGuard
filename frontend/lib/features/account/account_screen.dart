import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/patient.dart';
import 'package:frontend/models/saved_report.dart';
import 'package:frontend/providers/app_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSaving = false;
  String? _downloadingReportId;

  // Save Report Form State
  Patient? _selectedPatient;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _onPatientSelected(Patient? patient, String clinicianName) {
    setState(() {
      _selectedPatient = patient;
      if (patient != null) {
        _titleController.text = "Clinical Reconciliation - ${patient.fullName}";
        _summaryController.text = "Audit review of discrepancies and verified findings for ${patient.fullName} (${patient.mrn}).";
      } else {
        _titleController.text = "General Workspace Reconciliation Audit";
        _summaryController.text = "Cross-document contradiction reconciliation performed by $clinicianName.";
      }
    });
  }

  Future<void> _handleSaveReport(String clinicianName) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a report title."),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final findings = await api.getFindings(patientId: _selectedPatient?.id);

      final contradictionCount = findings
          .where((f) => f.classification.contains("CONTRADICTION"))
          .length;
      final verifiedCount = findings
          .where((f) => f.clinicallyVerified || f.currentStatus == "CONFIRMED" || f.currentStatus == "RESOLVED")
          .length;

      final structuredSummary = StringBuffer();
      structuredSummary.writeln("CLINICAL AUDIT RECONCILIATION - RECORDGUARD AI");
      structuredSummary.writeln("Author / Reviewer: $clinicianName");
      structuredSummary.writeln("Patient: ${_selectedPatient?.fullName ?? 'General Review'} (${_selectedPatient?.mrn ?? 'N/A'})");
      structuredSummary.writeln("Date: ${DateTime.now().toIso8601String()}");
      structuredSummary.writeln("Total Findings: ${findings.length}");
      structuredSummary.writeln("Identified Contradictions: $contradictionCount");
      structuredSummary.writeln("Verified Discrepancies: $verifiedCount");
      structuredSummary.writeln("\nEVIDENCE BREAKDOWN:");
      for (final f in findings) {
        structuredSummary.writeln("- [${f.category}] ${f.fieldCompared}: ${f.statementAText} vs ${f.statementBText}");
        structuredSummary.writeln("  Status: ${f.currentStatus} | Decision: ${f.verifiedConclusion ?? f.recommendation}");
      }

      await api.saveReport(
        patientId: _selectedPatient?.id,
        patientName: _selectedPatient?.fullName ?? "General Clinical Review",
        reportTitle: title,
        reportType: "CLINICAL_RECONCILIATION",
        summary: _summaryController.text.trim().isNotEmpty
            ? _summaryController.text.trim()
            : "Clinical reconciliation audit report generated and saved under $clinicianName.",
        totalFindings: findings.length,
        contradictionsCount: contradictionCount,
        verifiedCount: verifiedCount,
        reportData: structuredSummary.toString(),
        fileFormat: "TXT",
      );

      ref.read(refreshTriggerProvider.notifier).trigger();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Report successfully saved under '$clinicianName' in database!"),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _titleController.clear();
        _summaryController.clear();
        setState(() => _selectedPatient = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save report: $e"),
            backgroundColor: AppTheme.dangerRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDownloadReport(SavedReport report) async {
    setState(() => _downloadingReportId = report.id);
    try {
      final api = ref.read(apiServiceProvider);
      final content = await api.downloadReport(report.id);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.file_download_done, color: AppTheme.successGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Downloaded from Database: ${report.reportTitle}",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 650,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppTheme.successGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Fast retrieval completed! Report saved under '${report.userName}' retrieved from SQLite database.",
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavy, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "REPORT PAYLOAD:",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: Color(0xFF38BDF8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error downloading report: $e"),
            backgroundColor: AppTheme.dangerRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingReportId = null);
    }
  }

  void _showReportDetailsDialog(SavedReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment, color: AppTheme.accentTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                report.reportTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow("Saved On Clinician Name", report.userName, isHighlight: true),
                _buildInfoRow("Patient", "${report.patientName} (${report.patientId ?? 'N/A'})"),
                _buildInfoRow("Report Type", report.reportType),
                _buildInfoRow("Created Date", report.createdAt),
                _buildInfoRow("Findings Analyzed", "${report.totalFindings}"),
                _buildInfoRow("Contradictions", "${report.contradictionsCount}"),
                _buildInfoRow("Clinically Verified", "${report.verifiedCount}"),
                const SizedBox(height: 12),
                const Text(
                  "CLINICAL SUMMARY",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    report.summary ?? "No summary provided.",
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.primaryNavy),
                  ),
                ),
                if (report.reportData != null && report.reportData!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    "STRUCTURED PROVENANCE DATA",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: SelectableText(
                      report.reportData!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _handleDownloadReport(report);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text("Download"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? AppTheme.accentTeal : AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteReport(SavedReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Saved Report?"),
        content: Text("Are you sure you want to remove '${report.reportTitle}' from the database?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = ref.read(apiServiceProvider);
      await api.deleteReport(report.id);
      ref.read(refreshTriggerProvider.notifier).trigger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report deleted from database.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clinicianName = (user?.fullName != null && user!.fullName.isNotEmpty)
        ? user.fullName
        : (user?.username ?? "Clinician Reviewer");
    final savedReportsAsync = ref.watch(savedReportsProvider);
    final patientsAsync = ref.watch(patientsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_box, color: AppTheme.accentTeal, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Account & Saved Clinical Reports",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Clinical reports saved on your clinician name with indexed fast database retrieval & direct downloads.",
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.read(refreshTriggerProvider.notifier).trigger(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Refresh Reports"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Clinician Account Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accentTeal.withOpacity(0.2),
                    child: const Icon(Icons.medical_services_outlined, color: AppTheme.accentTeal, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              clinicianName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 12, color: AppTheme.successGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    "Verified Reviewer",
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.username ?? "clinician.demo@recordguard.ai",
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _buildAccountBadge(Icons.badge_outlined, user?.role ?? "Attending Physician / Clinical Reviewer"),
                            _buildAccountBadge(Icons.speed, "Fast Database Index Active"),
                            _buildAccountBadge(Icons.security, "PHI-Compliant Auditing"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Save New Report Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bookmark_add, size: 18, color: AppTheme.secondaryNavy),
                          const SizedBox(width: 8),
                          Text(
                            "SAVE NEW CLINICAL REPORT UNDER '$clinicianName'".toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Saved Author: $clinicianName",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentTeal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Patient Selector Dropdown
                  patientsAsync.when(
                    data: (patients) => Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Patient?>(
                            value: _selectedPatient,
                            decoration: const InputDecoration(
                              labelText: "Select Patient Case",
                              prefixIcon: Icon(Icons.person, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem<Patient?>(
                                value: null,
                                child: Text("All Clinical Scenarios / General Workspace"),
                              ),
                              ...patients.map(
                                (p) => DropdownMenuItem<Patient?>(
                                  value: p,
                                  child: Text("${p.fullName} (${p.mrn})"),
                                ),
                              ),
                            ],
                            onChanged: (p) => _onPatientSelected(p, clinicianName),
                          ),
                        ),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const SizedBox(),
                  ),
                  const SizedBox(height: 12),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "Report Title",
                      hintText: "e.g., Clinical Reconciliation - $clinicianName",
                      prefixIcon: const Icon(Icons.title, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Summary Field
                  TextField(
                    controller: _summaryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Clinical Summary & Attestation Notes",
                      hintText: "Summary of detected contradictions, resolved medications, and verified patient safety alerts...",
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _handleSaveReport(clinicianName),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(
                        _isSaving
                            ? "Saving to Database..."
                            : "Save Report on Name of '$clinicianName'",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Saved Reports List Section (Fast Database Retrieval)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_shared, color: AppTheme.primaryNavy, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Reports Saved on Your Name",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 13, color: AppTheme.accentTeal),
                          SizedBox(width: 2),
                          Text(
                            "Fast Database Retrieval",
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Search saved reports by title, patient, or date...",
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Reports Stream/Future Builder
            savedReportsAsync.when(
              data: (reports) {
                final query = _searchController.text.trim().toLowerCase();
                final filtered = reports.where((r) {
                  if (query.isEmpty) return true;
                  return r.reportTitle.toLowerCase().contains(query) ||
                      r.patientName.toLowerCase().contains(query) ||
                      r.userName.toLowerCase().contains(query) ||
                      (r.summary ?? "").toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.find_in_page_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            "No reports found matching your criteria.",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Save a report above to store it in the database under your clinician name.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: filtered.map((r) => _buildReportCard(r)).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("Failed to retrieve reports from database: $err"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(SavedReport report) {
    final isDownloading = _downloadingReportId == report.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: AppTheme.accentTeal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        report.reportTitle,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 12, color: AppTheme.secondaryNavy),
                          const SizedBox(width: 4),
                          Text(
                            "Saved on: ${report.userName}",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      "Patient: ${report.patientName}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    Text(
                      "• Date: ${report.createdAt.split('T').first}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      "• Contradictions: ${report.contradictionsCount}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dangerRose),
                    ),
                    Text(
                      "• Verified: ${report.verifiedCount}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.successGreen),
                    ),
                  ],
                ),
                if (report.summary != null && report.summary!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.summary!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isDownloading ? null : () => _handleDownloadReport(report),
                      icon: isDownloading
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 14),
                      label: Text(isDownloading ? "Downloading..." : "Fast Download"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showReportDetailsDialog(report),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text("View Report"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                      tooltip: "Delete Report",
                      onPressed: () => _handleDeleteReport(report),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
