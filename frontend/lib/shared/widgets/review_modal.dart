import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/models/finding.dart';
import 'package:frontend/providers/app_providers.dart';

class ReviewModal extends ConsumerStatefulWidget {
  final Finding finding;

  const ReviewModal({super.key, required this.finding});

  static void show(BuildContext context, Finding finding) {
    showDialog(
      context: context,
      builder: (ctx) => ReviewModal(finding: finding),
    );
  }

  @override
  ConsumerState<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends ConsumerState<ReviewModal> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _conclusionController = TextEditingController();

  String _selectedAction = 'CONFIRMED';
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _auditEvents = [];
  bool _loadingAudit = true;

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    try {
      final api = ref.read(apiServiceProvider);
      final events = await api.getFindingAudit(widget.finding.id);
      if (mounted) {
        setState(() {
          _auditEvents = events;
          _loadingAudit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAudit = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _conclusionController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      final isVerifiedConclusion =
          (_selectedAction == 'CONFIRMED' || _selectedAction == 'DISMISSED');

      await api.reviewFinding(
        findingId: widget.finding.id,
        reviewerId: currentUser?.id ?? "USR-DEMO-01",
        reviewerName: currentUser?.fullName ?? "Dr. Alex Rivera, MD",
        newStatus: _selectedAction,
        reason: _reasonController.text.trim(),
        clinicalNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        verifiedConclusion: _conclusionController.text.trim().isNotEmpty
            ? _conclusionController.text.trim()
            : null,
        clinicallyVerified: isVerifiedConclusion,
      );

      // Trigger global refresh
      ref.read(refreshTriggerProvider.notifier).trigger();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Review recorded successfully: ${_selectedAction.replaceAll('_', ' ')}",
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 800 : 600,
          maxHeight: size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Clinical Verification & Audit Log",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Finding: ${widget.finding.fieldCompared} (${widget.finding.classificationDisplay})",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Form & Audit Trail (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.dangerRose),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.dangerRose,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.dangerRose,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Review Action Selection
                        const Text(
                          "SELECT VERIFICATION ACTION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildActionRadio(
                              "CONFIRMED",
                              "Confirm Contradiction",
                              AppTheme.dangerRose,
                            ),
                            _buildActionRadio(
                              "DISMISSED",
                              "Dismiss Contradiction",
                              AppTheme.successGreen,
                            ),
                            _buildActionRadio(
                              "REVIEWED",
                              "Mark as Reviewed",
                              AppTheme.accentTeal,
                            ),
                            _buildActionRadio(
                              "REQUIRES_MORE_INFO",
                              "Requires More Info",
                              AppTheme.warningAmber,
                            ),
                            _buildActionRadio(
                              "PENDING_REVIEW",
                              "Reopen / Pending",
                              const Color(0xFF64748B),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Mandatory Reason Field
                        const Text(
                          "MANDATORY DECISION REASON",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                "State the clinical rationale for this decision (required for audit trail)...",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 3) {
                              return "Please provide a substantive rationale (min 3 characters).";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Clinically Verified Conclusion (Authorized Verdict)
                        const Text(
                          "CLINICALLY VERIFIED CONCLUSION (AUTHORIZED CLINICIAN VERDICT)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "An AI result alone is never a clinician conclusion. Record a binding clinical conclusion here when confirming or dismissing.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _conclusionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                "e.g., Penicillin allergy confirmed by patient interview; documented in EHR allergy module...",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Optional Clinical Notes
                        const Text(
                          "OPTIONAL CLINICAL NOTES / CHART DIRECTIVE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                "e.g., Updated EHR allergy profile, contacted prescribing physician...",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Audit Trail History Section
                        const Text(
                          "PERSISTENT AUDIT TRAIL HISTORY",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_loadingAudit)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_auditEvents.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: const Text(
                              "No previous review decisions recorded for this finding. Currently awaiting primary human review.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _auditEvents.map((evt) {
                              final details =
                                  evt['details'] as Map<String, dynamic>? ?? {};
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.borderSubtle,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.history_toggle_off,
                                              size: 16,
                                              color: AppTheme.accentTeal,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${evt['actor']}  •  ${evt['action']}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: AppTheme.primaryNavy,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          evt['created_at']
                                              .toString()
                                              .split('T')
                                              .first,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (details['status'] != null ||
                                        details['new_status'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "Status Transition: ${details['previous_status'] ?? 'N/A'} ➔ ${details['new_status'] ?? details['status']}",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.secondaryNavy,
                                        ),
                                      ),
                                    ],
                                    if (details['reason'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Reason: "${details['reason']}"',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                    if (details['verified_conclusion'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Verified Conclusion: "${details['verified_conclusion']}"',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Footer Buttons
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    const Text(
                      "Reviewer: Dr. Alex Rivera, MD (Demo Mode)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitReview,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: Text(
                            _isSubmitting
                                ? "Recording..."
                                : "Save Verification",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRadio(String value, String label, Color color) {
    final isSelected = _selectedAction == value;
    return InkWell(
      onTap: () => setState(() => _selectedAction = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderSubtle,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? color : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppTheme.primaryNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
