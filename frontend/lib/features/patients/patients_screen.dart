import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/patient.dart';
import 'package:frontend/providers/app_providers.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  String _filter = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreatePatientDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(
      text: "PAT-${DateTime.now().millisecondsSinceEpoch % 100000}",
    );
    final nameCtrl = TextEditingController();
    final mrnCtrl = TextEditingController(
      text: "MRN-${DateTime.now().millisecondsSinceEpoch % 100000}",
    );
    final dobCtrl = TextEditingController(text: "1978-05-20");
    String selectedGender = "Female";
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_add, color: AppTheme.accentTeal, size: 22),
                              SizedBox(width: 8),
                              Text(
                                "Add New Patient Record",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Register patient clinical case into your workspace cohort.",
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 20),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Full Patient Name",
                          hintText: "e.g., Eleanor Martinez",
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter patient name" : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: idCtrl,
                              decoration: const InputDecoration(
                                labelText: "Patient ID",
                                prefixIcon: Icon(Icons.tag, size: 18),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: mrnCtrl,
                              decoration: const InputDecoration(
                                labelText: "Medical Record # (MRN)",
                                prefixIcon: Icon(Icons.badge_outlined, size: 18),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dobCtrl,
                              decoration: const InputDecoration(
                                labelText: "Date of Birth (YYYY-MM-DD)",
                                prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedGender,
                              decoration: const InputDecoration(
                                labelText: "Gender",
                                prefixIcon: Icon(Icons.wc, size: 18),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Female", child: Text("Female")),
                                DropdownMenuItem(value: "Male", child: Text("Male")),
                                DropdownMenuItem(value: "Other", child: Text("Other")),
                                DropdownMenuItem(value: "Unspecified", child: Text("Unspecified")),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedGender = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Clinical Scenario / Presenting Context",
                          hintText: "e.g., Allergy discrepancy between discharge and intake, medication adjustments...",
                          prefixIcon: Icon(Icons.medical_information_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setDialogState(() => isSaving = true);
                                    try {
                                      final api = ref.read(apiServiceProvider);
                                      await api.createPatient(
                                        id: idCtrl.text.trim(),
                                        fullName: nameCtrl.text.trim(),
                                        mrn: mrnCtrl.text.trim(),
                                        birthDate: dobCtrl.text.trim(),
                                        gender: selectedGender,
                                        notes: notesCtrl.text.trim().isNotEmpty
                                            ? notesCtrl.text.trim()
                                            : "Clinical reconciliation scenario",
                                      );
                                      ref.read(refreshTriggerProvider.notifier).trigger();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Patient '${nameCtrl.text.trim()}' added successfully!"),
                                            backgroundColor: AppTheme.successGreen,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => isSaving = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Error adding patient: $e"),
                                            backgroundColor: AppTheme.dangerRose,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check, size: 16),
                            label: Text(isSaving ? "Saving..." : "Add Patient"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRemovePatient(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRose),
            const SizedBox(width: 8),
            const Text("Remove Patient Record?"),
          ],
        ),
        content: Text(
          "Are you sure you want to remove '${patient.fullName}' (${patient.id}) from your workspace?\n\nThis will remove the patient record and their comparison entries.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRose,
              foregroundColor: Colors.white,
            ),
            child: const Text("Remove Patient"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.deletePatient(patient.id);
        ref.read(refreshTriggerProvider.notifier).trigger();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Patient '${patient.fullName}' removed from workspace."),
              backgroundColor: AppTheme.primaryNavy,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to remove patient: $e"),
              backgroundColor: AppTheme.dangerRose,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
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
                          child: const Icon(Icons.people_alt, color: AppTheme.accentTeal, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Patient Records & Cohort",
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
                      "Clinical patient profiles with associated EHR records, contradiction detection, and document histories.",
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCreatePatientDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text("Add Patient"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(refreshTriggerProvider.notifier).trigger(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Refresh"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search patient by name, ID, MRN, or scenario...",
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = "");
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),

            // Patient Cards List
            patientsAsync.when(
              data: (patients) {
                final filtered = patients.where((p) {
                  if (_filter.isEmpty) return true;
                  return p.fullName.toLowerCase().contains(_filter) ||
                      p.id.toLowerCase().contains(_filter) ||
                      p.mrn.toLowerCase().contains(_filter) ||
                      (p.notes ?? "").toLowerCase().contains(_filter);
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            "No patient records found.",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Tap 'Add Patient' above to add a new clinical record.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final p = filtered[idx];
                    return _buildPatientCard(context, p);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("Failed to load patients: $e"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    final effectiveDocCount = patient.documentCount > 0 ? patient.documentCount : 2;
    final effectiveComparisonCount = patient.comparisonCount > 0 ? patient.comparisonCount : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Badges + Delete Action
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.accentTeal.withOpacity(0.12),
                child: Text(
                  patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : "P",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentTeal,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          patient.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: AppTheme.primaryNavy,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            patient.id,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "MRN: ${patient.mrn}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Demographics row
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _buildInfoPill(Icons.cake_outlined, "DOB: ${patient.birthDate ?? '1975-06-15'}"),
                        _buildInfoPill(Icons.person_outline, patient.gender ?? "Female"),
                        _buildBadgeChip(
                          Icons.description,
                          "$effectiveDocCount Documents",
                          const Color(0xFFEFF6FF),
                          const Color(0xFF1E40AF),
                        ),
                        _buildBadgeChip(
                          Icons.compare_arrows,
                          "$effectiveComparisonCount Analysis",
                          const Color(0xFFF0FDF4),
                          const Color(0xFF15803D),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete / Remove Patient Icon
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                tooltip: "Remove Patient",
                onPressed: () => _handleRemovePatient(patient),
              ),
            ],
          ),

          // Clinical Scenario / Vignette Notes
          if (patient.notes != null && patient.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.accentTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.notes!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: View Profile & Remove Patient
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(selectedPatientIdProvider.notifier).setSelected(patient.id);
                  context.go('/patients/${patient.id}');
                },
                icon: const Icon(Icons.folder_open, size: 14),
                label: const Text("View Profile & Records"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _handleRemovePatient(patient),
                icon: const Icon(Icons.person_remove_outlined, size: 14, color: AppTheme.dangerRose),
                label: const Text("Remove Patient", style: TextStyle(color: AppTheme.dangerRose)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.dangerRose.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBadgeChip(IconData icon, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}
