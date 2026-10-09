import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants.dart';
import 'package:frontend/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    final api = ref.read(apiServiceProvider);
    _urlController = TextEditingController(text: api.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyApiUrl, newUrl);
    ref.read(apiServiceProvider).updateBaseUrl(newUrl);
    ref.read(refreshTriggerProvider.notifier).trigger();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backend API URL updated successfully.")),
      );
    }
  }

  Future<void> _confirmResetDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Reset Demonstration Database?"),
        content: const Text(
          "This will re-initialize the SQLite database with the standard 5 clinical scenarios (Allergy conflict, Medication discontinuation, Serial labs, Missing allergy record, and Dosage equivalence). Any custom reviews will be reset to default.",
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
            ),
            child: const Text("Reset Database"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isResetting = true);
      try {
        final api = ref.read(apiServiceProvider);
        await api.resetDemo();
        ref.read(refreshTriggerProvider.notifier).trigger();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Demonstration data re-initialized successfully!"),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to reset: $e"),
              backgroundColor: AppTheme.dangerRose,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(systemHealthProvider);

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
                  child: Icon(Icons.settings, color: AppTheme.accentTeal, size: 24),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "System Health & Application Settings",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Subsystem connectivity, OCR engine readiness, and environment configuration.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Diagnostics Card
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
                    "SUBSYSTEM DIAGNOSTICS & ENGINE READINESS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  healthAsync.when(
                    data: (h) => Column(
                      children: [
                        _buildHealthRow(
                          "FastAPI Core Service",
                          h.status == 'healthy'
                              ? "Operational (Healthy)"
                              : "Error",
                          h.status == 'healthy',
                        ),
                        _buildHealthRow(
                          "SQLite Database",
                          "Connected & Persistent",
                          h.database.contains('connected'),
                        ),
                        _buildHealthRow(
                          "ML Contradiction Classifier",
                          h.modelAvailable
                              ? "Trained & Loaded in Memory"
                              : "Unavailable",
                          h.modelAvailable,
                        ),
                        _buildHealthRow(
                          "Tesseract OCR Subsystem",
                          h.ocrAvailable
                              ? "Tesseract Detected on PATH"
                              : "Graceful Fallback Mode (OCR Binary Not Found)",
                          h.ocrAvailable,
                          isWarning: !h.ocrAvailable,
                        ),
                        _buildHealthRow(
                          "Demonstration Mode",
                          h.demoMode
                              ? "Active (Synthetic PHI Guard Enabled)"
                              : "Disabled",
                          true,
                        ),
                        _buildHealthRow(
                          "Application Version",
                          "${AppConstants.appName} v${h.version}",
                          true,
                        ),
                      ],
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Text(
                      "Failed to query health check: $e",
                      style: const TextStyle(color: AppTheme.dangerRose),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // API Endpoint Settings
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
                    "BACKEND API CONNECTIVITY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Configure the REST API endpoint used for backend communication. Supports Windows desktop, Android emulator (10.0.2.2:8000), or physical IP.",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wifi, size: 14),
                        label: const Text("Host PC Wi-Fi (192.168.10.22)", style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = "http://192.168.10.22:8000/api";
                          _saveBaseUrl();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.phone_android, size: 14),
                        label: const Text("Emulator (10.0.2.2)", style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = "http://10.0.2.2:8000/api";
                          _saveBaseUrl();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 14),
                        label: const Text("Localhost (127.0.0.1)", style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _urlController.text = "http://127.0.0.1:8000/api";
                          _saveBaseUrl();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: "API Base URL",
                            prefixIcon: Icon(Icons.link, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _saveBaseUrl,
                        icon: const Icon(Icons.save, size: 15),
                        label: const Text("Save"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Demonstration Re-seeding Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DEMONSTRATION SCENARIOS RESET",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Re-ingest all 5 synthetic clinical test scenarios and restore clean review states for live presentation.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isResetting ? null : _confirmResetDemoData,
                    icon: _isResetting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      _isResetting ? "Re-seeding..." : "Load Demo Records",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthRow(
    String label,
    String value,
    bool isOk, {
    bool isWarning = false,
  }) {
    Color indicatorColor = isOk
        ? AppTheme.successGreen
        : (isWarning ? AppTheme.warningAmber : AppTheme.dangerRose);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.primaryNavy,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: indicatorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
