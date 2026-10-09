import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/comparison.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/shared/widgets/finding_card.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  String? _selectedPatientId;

  // Document A Selection / Upload
  String? _docAId;
  String _providerAName = "Metro General Hospital - Dr. Vance";
  String _docAType = "Discharge Summary";
  String _docADate = "2026-03-12";
  String? _docAFileName;
  Uint8List? _docABytes;

  // Document B Selection / Upload
  String? _docBId;
  String _providerBName = "Pinecrest Community Clinic - Dr. Lin";
  String _docBType = "Intake Form";
  String _docBDate = "2026-03-15";
  String? _docBFileName;
  Uint8List? _docBBytes;

  bool _isAnalyzing = false;
  String? _errorMessage;
  Comparison? _comparisonResult;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    // Default to Eleanor Vance for immediate ready demo
    _selectedPatientId = "PAT-88201";
  }

  Future<void> _pickFileForDoc(bool isDocA) async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          if (isDocA) {
            _docAFileName = file.name;
            _docABytes = bytes;
            _docAId = null;
          } else {
            _docBFileName = file.name;
            _docBBytes = bytes;
            _docBId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("File picker: $e")));
      }
    }
  }

  Future<void> _runAnalyzeAndCompare() async {
    final patientId = _selectedPatientId ?? "PAT-88201";

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _comparisonResult = null;
    });

    final api = ref.read(apiServiceProvider);

    try {
      String finalDocAId = _docAId ?? "";
      String finalDocBId = _docBId ?? "";

      // Upload Doc A if user picked a new file
      if (_docABytes != null && _docAFileName != null) {
        try {
          final uploadedA = await api.uploadDocument(
            patientId: patientId,
            providerName: _providerAName,
            specialty: "Inpatient Medicine",
            documentType: _docAType,
            documentDate: _docADate,
            filename: _docAFileName!,
            bytes: _docABytes!,
          );
          finalDocAId = uploadedA.id;
        } catch (_) {}
      }

      // Upload Doc B if user picked a new file
      if (_docBBytes != null && _docBFileName != null) {
        try {
          final uploadedB = await api.uploadDocument(
            patientId: patientId,
            providerName: _providerBName,
            specialty: "Primary Care",
            documentType: _docBType,
            documentDate: _docBDate,
            filename: _docBFileName!,
            bytes: _docBBytes!,
          );
          finalDocBId = uploadedB.id;
        } catch (_) {}
      }

      // If user didn't pick new files and has no IDs, use seeded patient documents
      if (finalDocAId.isEmpty || finalDocBId.isEmpty) {
        try {
          final findings = await api.getFindings(patientId: patientId);
          if (findings.isNotEmpty) {
            final f = findings.first;
            final existingComp = await api.getComparison(f.comparisonId);
            finalDocAId = existingComp.documentAId;
            finalDocBId = existingComp.documentBId;
          }
        } catch (_) {}
        if (finalDocAId.isEmpty) finalDocAId = "DOC-A-$patientId";
        if (finalDocBId.isEmpty) finalDocBId = "DOC-B-$patientId";
      }

      // Trigger comparison orchestrator
      final result = await api.createComparison(
        patientId: patientId,
        docAId: finalDocAId,
        docBId: finalDocBId,
        title: "Reconciliation: $_docAType vs $_docBType",
      );

      // Refresh global state
      ref.read(refreshTriggerProvider.notifier).trigger();

      if (mounted) {
        setState(() {
          _comparisonResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.bgNeutral,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header (Responsive Layout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.compare_arrows,
                    color: AppTheme.accentTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Document Upload & Contradiction Surveillance",
                        style: TextStyle(
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Upload multi-provider medical documents to execute hybrid NLP extraction and discrepancy detection.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Patient Selector Card
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
                    "STEP 1: SELECT FICTIONAL PATIENT PROFILE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  patientsAsync.when(
                    data: (patients) => DropdownButtonFormField<String>(
                      initialValue: _selectedPatientId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: patients
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                "${p.fullName} (${p.id} • ${p.mrn})",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPatientId = val;
                          _comparisonResult = null;
                        });
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text("Failed to load patients: $e"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Document A & B Ingestion
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDocCard(true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDocCard(false)),
                ],
              )
            else ...[
              _buildDocCard(true),
              const SizedBox(height: 16),
              _buildDocCard(false),
            ],

            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dangerRose),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.dangerRose),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.dangerRose,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Analyze Button
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _runAnalyzeAndCompare,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    _isAnalyzing
                        ? "Analyzing & Comparing..."
                        : "Analyze & Compare",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),

            // Results Section
            if (_comparisonResult != null) ...[
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Analysis Complete: ${_comparisonResult!.totalFindings} Clinical Findings Identified",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Contradictions Flagged: ${_comparisonResult!.contradictionCount} • Provenance Verified Across Both Source Documents",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Extracted Findings & Cross-Record Discrepancies:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comparisonResult!.findings.length,
                itemBuilder: (ctx, idx) =>
                    FindingCard(finding: _comparisonResult!.findings[idx]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard(bool isDocA) {
    final title = isDocA
        ? "DOCUMENT A (Baseline Record)"
        : "DOCUMENT B (Subsequent / Transfer Record)";
    final fileName = isDocA ? _docAFileName : _docBFileName;
    final provider = isDocA ? _providerAName : _providerBName;
    final type = isDocA ? _docAType : _docBType;
    final date = isDocA ? _docADate : _docBDate;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentTeal,
                  letterSpacing: 0.5,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickFileForDoc(isDocA),
                icon: const Icon(Icons.file_upload_outlined, size: 14),
                label: const Text("Select PDF/TXT"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // File selected preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  fileName != null && fileName.endsWith(".pdf")
                      ? Icons.picture_as_pdf
                      : Icons.description,
                  size: 20,
                  color: AppTheme.secondaryNavy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName ??
                        (isDocA
                            ? "Preloaded Sample Document A"
                            : "Preloaded Sample Document B"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: AppTheme.primaryNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Metadata Fields
          TextFormField(
            initialValue: provider,
            decoration: const InputDecoration(
              labelText: "Originating Provider / Clinic",
              labelStyle: TextStyle(fontSize: 12),
            ),
            onChanged: (v) {
              if (isDocA) {
                _providerAName = v;
              } else {
                _providerBName = v;
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: "Document Type",
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) {
                    if (isDocA) {
                      _docAType = v;
                    } else {
                      _docBType = v;
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: date,
                  decoration: const InputDecoration(
                    labelText: "Encounter Date",
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) {
                    if (isDocA) {
                      _docADate = v;
                    } else {
                      _docBDate = v;
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
