import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/document.dart';
import 'package:frontend/models/patient.dart';
import 'package:frontend/models/saved_report.dart';
import 'package:frontend/providers/app_providers.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  bool _isLoading = false;
  List<ClinicalDocument> _documents = [];
  List<SavedReport> _savedReports = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrievePatientReports();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _retrievePatientReports({bool showFeedback = false}) async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final docs = await api.getPatientDocuments(widget.patientId);
      final reports = await api.getSavedReports(patientId: widget.patientId);

      if (mounted) {
        setState(() {
          _documents = docs;
          _savedReports = reports;
          _isLoading = false;
        });

        if (showFeedback) {
          final totalCount = docs.length + reports.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                totalCount > 0
                    ? "Successfully retrieved $totalCount reports and records for this patient."
                    : "No uploaded reports found for this patient yet.",
              ),
              backgroundColor: AppTheme.primaryNavy,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error retrieving reports: $e"),
              backgroundColor: AppTheme.dangerRose,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUploadReportDialog(BuildContext context, Patient patient) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: "Discharge Summary");
    final providerCtrl = TextEditingController(
      text: ref.read(currentUserProvider)?.fullName ?? "Clinician Reviewer",
    );
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final textContentCtrl = TextEditingController();

    String selectedDocType = "Discharge Summary";
    String? pickedFileName;
    Uint8List? pickedFileBytes;
    bool isDirectTextMode = false;
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 580,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.upload_file, color: AppTheme.accentTeal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Upload Patient Report",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              Text(
                                "For ${patient.fullName} (${patient.id})",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: isUploading ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Report Type Toggle: File Picker vs Direct Text Entry
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => isDirectTextMode = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isDirectTextMode
                                    ? AppTheme.accentTeal.withOpacity(0.12)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !isDirectTextMode ? AppTheme.accentTeal : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    size: 16,
                                    color: !isDirectTextMode ? AppTheme.accentTeal : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Attach PDF / TXT",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: !isDirectTextMode ? AppTheme.accentTeal : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => isDirectTextMode = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isDirectTextMode
                                    ? AppTheme.accentTeal.withOpacity(0.12)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDirectTextMode ? AppTheme.accentTeal : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    size: 18,
                                    color: isDirectTextMode ? AppTheme.accentTeal : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Enter Clinical Text",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDirectTextMode ? AppTheme.accentTeal : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // File selection container (if in file mode)
                    if (!isDirectTextMode) ...[
                      InkWell(
                        onTap: () async {
                          try {
                            final List<PlatformFile> files = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'txt'],
                            );
                            if (files.isNotEmpty) {
                              final file = files.first;
                              final bytes = await file.readAsBytes();
                              setDialogState(() {
                                pickedFileName = file.name;
                                pickedFileBytes = bytes;
                                if (titleCtrl.text.isEmpty || titleCtrl.text == "Discharge Summary") {
                                  titleCtrl.text = file.name.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
                                }
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error selecting file: $e")),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: pickedFileName != null ? AppTheme.accentTeal : const Color(0xFFCBD5E1),
                              width: pickedFileName != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                pickedFileName != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                                size: 36,
                                color: pickedFileName != null ? AppTheme.accentTeal : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pickedFileName ?? "Click to browse and upload medical document",
                                style: TextStyle(
                                  fontWeight: pickedFileName != null ? FontWeight.w700 : FontWeight.w600,
                                  color: pickedFileName != null ? AppTheme.primaryNavy : const Color(0xFF475569),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickedFileName != null
                                    ? "${(pickedFileBytes?.length ?? 0) ~/ 1024} KB • Ready to submit"
                                    : "Supports PDF and TXT EHR clinical notes (Max 25MB)",
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Report Title
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Report Title / Description *",
                        hintText: "e.g., Inpatient Discharge Summary, Echo Lab Report...",
                        prefixIcon: Icon(Icons.title, size: 18),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 12),

                    // Document Type & Date Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDocType,
                            decoration: const InputDecoration(
                              labelText: "Document Type",
                              prefixIcon: Icon(Icons.category_outlined, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(value: "Discharge Summary", child: Text("Discharge Summary")),
                              DropdownMenuItem(value: "Clinical Consultation", child: Text("Consultation Note")),
                              DropdownMenuItem(value: "Lab / Pathology Report", child: Text("Lab / Pathology")),
                              DropdownMenuItem(value: "Radiology / Imaging", child: Text("Radiology / Imaging")),
                              DropdownMenuItem(value: "Medication Reconciliation", child: Text("Medication Recon")),
                              DropdownMenuItem(value: "Progress Note", child: Text("Progress Note")),
                              DropdownMenuItem(value: "Emergency Intake", child: Text("Emergency Intake")),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedDocType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: dateCtrl,
                            decoration: const InputDecoration(
                              labelText: "Date (YYYY-MM-DD)",
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Author / Clinician Provider
                    TextFormField(
                      controller: providerCtrl,
                      decoration: const InputDecoration(
                        labelText: "Attending / Reporting Clinician",
                        prefixIcon: Icon(Icons.person_pin_outlined, size: 18),
                      ),
                    ),

                    // Text Content if Direct Text Mode
                    if (isDirectTextMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: textContentCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: "Clinical Report Text / Observations *",
                          hintText: "Paste or type patient clinical findings, discharge medications, allergies, or lab values...",
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (isDirectTextMode && (val == null || val.trim().isEmpty)) {
                            return "Report text content is required";
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isUploading ? null : () => Navigator.pop(dialogCtx),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (!isDirectTextMode && pickedFileBytes == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Please select a PDF or TXT file to upload, or switch to 'Enter Clinical Text'."),
                                        backgroundColor: AppTheme.dangerRose,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isUploading = true);
                                  try {
                                    final api = ref.read(apiServiceProvider);
                                    final title = titleCtrl.text.trim();
                                    final provider = providerCtrl.text.trim().isNotEmpty
                                        ? providerCtrl.text.trim()
                                        : "Attending Physician";
                                    final date = dateCtrl.text.trim();

                                    if (!isDirectTextMode && pickedFileBytes != null) {
                                      // File upload via multipart
                                      await api.uploadDocument(
                                        patientId: patient.id,
                                        providerName: provider,
                                        specialty: "Clinical Medicine",
                                        documentType: selectedDocType,
                                        documentDate: date,
                                        filename: pickedFileName ?? "$title.pdf",
                                        bytes: pickedFileBytes!,
                                      );
                                    } else {
                                      // Direct text upload
                                      final rawBytes = Uint8List.fromList(utf8.encode(textContentCtrl.text.trim()));
                                      await api.uploadDocument(
                                        patientId: patient.id,
                                        providerName: provider,
                                        specialty: "Clinical Medicine",
                                        documentType: selectedDocType,
                                        documentDate: date,
                                        filename: "${title.replaceAll(' ', '_')}.txt",
                                        bytes: rawBytes,
                                      );

                                      // Also save to structured reports
                                      await api.saveReport(
                                        patientId: patient.id,
                                        patientName: patient.fullName,
                                        reportTitle: title,
                                        reportType: selectedDocType,
                                        summary: "Clinical report uploaded directly for ${patient.fullName}.",
                                        reportData: textContentCtrl.text.trim(),
                                        fileFormat: "TXT",
                                      );
                                    }

                                    ref.read(refreshTriggerProvider.notifier).trigger();
                                    await _retrievePatientReports();

                                    if (context.mounted) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Report '$title' uploaded successfully for ${patient.fullName}!"),
                                          backgroundColor: AppTheme.successGreen,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Failed to upload report: $e"),
                                          backgroundColor: AppTheme.dangerRose,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload, size: 16),
                          label: Text(isUploading ? "Uploading..." : "Upload & Save Report"),
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
    );
  }

  Future<void> _viewDocumentDetails(ClinicalDocument doc) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiServiceProvider).getDocumentRaw(doc.id),
        builder: (ctx, snapshot) {
          final rawText = snapshot.data?['raw_text'] ?? "Loading document raw text...";
          final isReady = snapshot.connectionState == ConnectionState.done;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              width: 650,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description, color: AppTheme.primaryNavy, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.originalName.isNotEmpty ? doc.originalName : doc.filename,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            Text(
                              "${doc.documentType} • ${doc.providerName} • ${doc.documentDate ?? 'Recorded'}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildChip(Icons.folder_zip, "${doc.fileType} Format", const Color(0xFFF1F5F9), const Color(0xFF475569)),
                      _buildChip(Icons.data_usage, "${(doc.fileSizeBytes / 1024).toStringAsFixed(1)} KB", const Color(0xFFEFF6FF), const Color(0xFF1E40AF)),
                      _buildChip(Icons.auto_stories, "${doc.totalPages} Page(s)", const Color(0xFFF0FDF4), const Color(0xFF166534)),
                      if (doc.ocrApplied)
                        _buildChip(Icons.document_scanner, "OCR Processed", const Color(0xFFFEF3C7), const Color(0xFFB45309)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Extracted Clinical Text & Provenance Evidence:",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: !isReady
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: SelectableText(
                                rawText.isNotEmpty ? rawText : "No extracted content available for this record.",
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rawText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Document text copied to clipboard!"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text("Copy Text"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _viewSavedReportDetails(SavedReport report) async {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: AppTheme.accentTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reportTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          "Author: ${report.userName} • Date: ${report.createdAt.substring(0, 10)}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (report.summary != null && report.summary!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Text(
                    "Clinical Summary: ${report.summary}",
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                "Full Report Body & Observations:",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      report.reportData ?? "No text content recorded for this report.",
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: report.reportData ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Report text copied to clipboard!")),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text("Copy Text"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
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

  Future<void> _handleDeleteDocument(ClinicalDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient Document?"),
        content: Text("Are you sure you want to remove '${doc.originalName}' from this patient's records?"),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(apiServiceProvider).deleteDocument(doc.id);
        ref.read(refreshTriggerProvider.notifier).trigger();
        await _retrievePatientReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Document deleted successfully.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete document: $e")),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteReport(SavedReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Saved Report?"),
        content: Text("Are you sure you want to delete '${report.reportTitle}'?"),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(apiServiceProvider).deleteReport(report.id);
        ref.read(refreshTriggerProvider.notifier).trigger();
        await _retrievePatientReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Report deleted successfully.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete report: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(selectedPatientProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: patientAsync.when(
          data: (patient) {
            if (patient == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Patient record not found."),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/patients'),
                      child: const Text("Return to Patients"),
                    ),
                  ],
                ),
              );
            }

            final filteredDocs = _documents.where((d) {
              if (_searchQuery.isEmpty) return true;
              return d.originalName.toLowerCase().contains(_searchQuery) ||
                  d.documentType.toLowerCase().contains(_searchQuery) ||
                  d.providerName.toLowerCase().contains(_searchQuery);
            }).toList();

            final filteredReports = _savedReports.where((r) {
              if (_searchQuery.isEmpty) return true;
              return r.reportTitle.toLowerCase().contains(_searchQuery) ||
                  r.reportType.toLowerCase().contains(_searchQuery) ||
                  r.userName.toLowerCase().contains(_searchQuery);
            }).toList();

            final totalRecordsCount = _documents.length + _savedReports.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation & Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/patients'),
                        ),
                        const SizedBox(width: 4),
                        const Text("Patients / ", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        Text(
                          patient.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryNavy, fontSize: 14),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showUploadReportDialog(context, patient),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text("Upload Report"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _retrievePatientReports(showFeedback: true),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: const Text("Retrieve Reports"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Patient Profile Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.accentTeal.withOpacity(0.12),
                            child: Text(
                              patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : "P",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentTeal,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryNavy,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        patient.id,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "MRN: ${patient.mrn}",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.accentTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _buildTextPill(Icons.cake_outlined, "DOB: ${patient.birthDate ?? 'N/A'}"),
                                    _buildTextPill(Icons.person_outline, "Gender: ${patient.gender ?? 'N/A'}"),
                                    _buildChip(
                                      Icons.folder_shared,
                                      "$totalRecordsCount Reports on File",
                                      const Color(0xFFEFF6FF),
                                      const Color(0xFF1E40AF),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (patient.notes != null && patient.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppTheme.accentTeal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Clinical Context: ${patient.notes}",
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Reports Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Patient Reports & Clinical Documents",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Uploaded clinical archives, lab records, and discharge summaries for ${patient.fullName}.",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showUploadReportDialog(context, patient),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Add Report"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Filter Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search patient's reports by title, type, or clinician...",
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),

                // Reports List or Empty State
                if (_isLoading && totalRecordsCount == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filteredDocs.isEmpty && filteredReports.isEmpty)
                  Container(
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
                          Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            "No reports found for this patient.",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Upload a clinical summary, lab record, or discharge note to start building this patient's archive.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showUploadReportDialog(context, patient),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text("Upload First Report"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // List of Documents
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length + filteredReports.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      if (idx < filteredDocs.length) {
                        final doc = filteredDocs[idx];
                        return _buildDocumentTile(doc);
                      } else {
                        final report = filteredReports[idx - filteredDocs.length];
                        return _buildSavedReportTile(report);
                      }
                    },
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text("Failed to load patient: $e")),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(ClinicalDocument doc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Color(0xFF1E40AF), size: 22),
          ),
          const SizedBox(width: 14),
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
                      doc.originalName.isNotEmpty ? doc.originalName : doc.filename,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    _buildChip(
                      Icons.label_outline,
                      doc.documentType,
                      const Color(0xFFF1F5F9),
                      const Color(0xFF475569),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildTextPill(Icons.person_outline, "Provider: ${doc.providerName}"),
                    _buildTextPill(Icons.calendar_today_outlined, doc.documentDate ?? "Recorded"),
                    _buildTextPill(Icons.data_usage, "${(doc.fileSizeBytes / 1024).toStringAsFixed(1)} KB"),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.accentTeal),
                tooltip: "View / Retrieve Full Report",
                onPressed: () => _viewDocumentDetails(doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
                tooltip: "Delete Document",
                onPressed: () => _handleDeleteDocument(doc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedReportTile(SavedReport report) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_turned_in, color: Color(0xFF166534), size: 22),
          ),
          const SizedBox(width: 14),
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
                      report.reportTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    _buildChip(
                      Icons.verified_outlined,
                      report.reportType.isNotEmpty ? report.reportType : "Clinical Report",
                      const Color(0xFFF0FDF4),
                      const Color(0xFF166534),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildTextPill(Icons.person_outline, "Author: ${report.userName}"),
                    _buildTextPill(Icons.calendar_today_outlined, report.createdAt.substring(0, 10)),
                    if (report.summary != null)
                      _buildTextPill(Icons.notes, report.summary!.length > 40 ? "${report.summary!.substring(0, 40)}..." : report.summary!),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.accentTeal),
                tooltip: "View / Retrieve Full Report",
                onPressed: () => _viewSavedReportDetails(report),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
                tooltip: "Delete Report",
                onPressed: () => _handleDeleteReport(report),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}
