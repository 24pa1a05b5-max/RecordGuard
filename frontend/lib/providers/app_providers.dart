import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/models/patient.dart';
import 'package:frontend/models/finding.dart';
import 'package:frontend/models/model_metrics.dart';
import 'package:frontend/models/saved_report.dart';

// SharedPreferences Provider (injected at app start)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

// API Service Singleton Provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Trigger provider to force refresh of lists
class RefreshTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

final refreshTriggerProvider = NotifierProvider<RefreshTriggerNotifier, int>(
  RefreshTriggerNotifier.new,
);

// Current User State
class CurrentUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final bool isDemo;

  CurrentUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.isDemo = false,
  });

  bool get isAdmin => role.toLowerCase().contains('admin');
}

class CurrentUserNotifier extends Notifier<CurrentUser?> {
  @override
  CurrentUser? build() {
    // 1. Check SharedPreferences if injected
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final userId = prefs.getString('auth_user_id');
      final fullName = prefs.getString('auth_user_fullname');
      if (userId != null && fullName != null && fullName.isNotEmpty) {
        final token = prefs.getString('auth_user_token');
        if (token != null && token.isNotEmpty) {
          ref.read(apiServiceProvider).setAuthToken(token);
        }
        return CurrentUser(
          id: userId,
          username: prefs.getString('auth_user_username') ?? userId,
          fullName: fullName,
          role: prefs.getString('auth_user_role') ?? "Clinical Reviewer",
          isDemo: prefs.getBool('auth_user_is_demo') ?? false,
        );
      }
    }

    // 2. Fallback to Firebase currentUser
    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        Future.microtask(() => _checkExistingSession(fbUser));
        return CurrentUser(
          id: fbUser.uid,
          username: fbUser.email ?? fbUser.uid,
          fullName: fbUser.displayName ?? "Clinician Reviewer",
          role: "Clinical Reviewer",
          isDemo: false,
        );
      }
    } catch (_) {}

    // 3. Fallback async check
    Future.microtask(() => _loadPersistedSession());
    return null;
  }

  Future<void> _loadPersistedSession() async {
    if (state != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('auth_user_id');
      final fullName = prefs.getString('auth_user_fullname');
      if (userId != null && fullName != null && fullName.isNotEmpty) {
        final token = prefs.getString('auth_user_token');
        if (token != null && token.isNotEmpty) {
          ref.read(apiServiceProvider).setAuthToken(token);
        }
        state = CurrentUser(
          id: userId,
          username: prefs.getString('auth_user_username') ?? userId,
          fullName: fullName,
          role: prefs.getString('auth_user_role') ?? "Clinical Reviewer",
          isDemo: prefs.getBool('auth_user_is_demo') ?? false,
        );
      }
    } catch (_) {}
  }

  Future<void> _checkExistingSession([fb.User? existingUser]) async {
    try {
      final fbUser = existingUser ?? fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        final token = await fbUser.getIdToken();
        ref.read(apiServiceProvider).setAuthToken(token);
        final prefs = await SharedPreferences.getInstance();
        final savedName = prefs.getString('auth_user_fullname');

        final effectiveName = (savedName != null && savedName.isNotEmpty)
            ? savedName
            : (fbUser.displayName ?? "Clinician Reviewer");

        final user = CurrentUser(
          id: fbUser.uid,
          username: fbUser.email ?? fbUser.uid,
          fullName: effectiveName,
          role: prefs.getString('auth_user_role') ?? "Clinical Reviewer",
          isDemo: false,
        );
        state = user;
        await setUser(user, token: token);
      }
    } catch (_) {}
  }

  Future<void> setUser(CurrentUser? user, {String? token}) async {
    state = user;
    try {
      final prefs = ref.read(sharedPreferencesProvider) ?? await SharedPreferences.getInstance();
      if (user != null) {
        await prefs.setString('auth_user_id', user.id);
        await prefs.setString('auth_user_username', user.username);
        await prefs.setString('auth_user_fullname', user.fullName);
        await prefs.setString('auth_user_role', user.role);
        await prefs.setBool('auth_user_is_demo', user.isDemo);
        if (token != null) {
          await prefs.setString('auth_user_token', token);
          ref.read(apiServiceProvider).setAuthToken(token);
        }
      } else {
        await prefs.remove('auth_user_id');
        await prefs.remove('auth_user_username');
        await prefs.remove('auth_user_fullname');
        await prefs.remove('auth_user_role');
        await prefs.remove('auth_user_is_demo');
        await prefs.remove('auth_user_token');
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
    ref.read(apiServiceProvider).setAuthToken(null);
    await setUser(null);
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, CurrentUser?>(
  CurrentUserNotifier.new,
);

// Patients Provider
final patientsProvider = FutureProvider<List<Patient>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final api = ref.watch(apiServiceProvider);
  return await api.getPatients();
});

// Selected Patient for Detail / Workspace
class SelectedPatientIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setSelected(String? id) => state = id;
}

final selectedPatientIdProvider =
    NotifierProvider<SelectedPatientIdNotifier, String?>(
      SelectedPatientIdNotifier.new,
    );

final selectedPatientProvider = FutureProvider<Patient?>((ref) async {
  final patientId = ref.watch(selectedPatientIdProvider);
  if (patientId == null) return null;
  final api = ref.watch(apiServiceProvider);
  return await api.getPatient(patientId);
});

// All Findings Provider
class FindingsFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFilter(String? status) => state = status;
}

final findingsFilterProvider =
    NotifierProvider<FindingsFilterNotifier, String?>(
      FindingsFilterNotifier.new,
    );

final findingsProvider = FutureProvider<List<Finding>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final filterStatus = ref.watch(findingsFilterProvider);
  final api = ref.watch(apiServiceProvider);
  return await api.getFindings(status: filterStatus);
});

// Review Queue Provider (Prioritized)
final reviewQueueProvider = Provider<AsyncValue<List<Finding>>>((ref) {
  final findingsAsync = ref.watch(findingsProvider);
  return findingsAsync.whenData((findings) {
    // Only pending review
    final pending = findings
        .where((f) => f.currentStatus == 'PENDING_REVIEW')
        .toList();

    // Sort by priority: PRIORITY_REVIEW -> STANDARD_REVIEW -> AWAITING_EVIDENCE -> LOW_PRIORITY
    final order = {
      'PRIORITY_REVIEW': 0,
      'STANDARD_REVIEW': 1,
      'AWAITING_EVIDENCE': 2,
      'LOW_PRIORITY': 3,
    };

    pending.sort((a, b) {
      int ordA = order[a.priorityLevel] ?? 99;
      int ordB = order[b.priorityLevel] ?? 99;
      return ordA.compareTo(ordB);
    });

    return pending;
  });
});

// System Health Provider
final systemHealthProvider = FutureProvider<SystemHealth>((ref) async {
  ref.watch(refreshTriggerProvider);
  final api = ref.watch(apiServiceProvider);
  return await api.getHealth();
});

// Model Metrics Provider
final modelMetricsProvider = FutureProvider<ModelMetrics>((ref) async {
  ref.watch(refreshTriggerProvider);
  final api = ref.watch(apiServiceProvider);
  return await api.getModelMetrics();
});

// Dashboard Statistics Provider
class DashboardStats {
  final int totalPatients;
  final int totalDocuments;
  final int pendingDiscrepancies;
  final int resolvedFindings;
  final int priorityReviewCount;

  DashboardStats({
    required this.totalPatients,
    required this.totalDocuments,
    required this.pendingDiscrepancies,
    required this.resolvedFindings,
    required this.priorityReviewCount,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  ref.watch(refreshTriggerProvider);
  final api = ref.watch(apiServiceProvider);

  final patients = await api.getPatients();
  final findings = await api.getFindings();

  int totalDocs = patients.fold(0, (sum, p) => sum + p.documentCount);
  int pending = findings
      .where((f) => f.currentStatus == 'PENDING_REVIEW')
      .length;
  int resolved = findings
      .where(
        (f) => f.currentStatus == 'RESOLVED' || f.currentStatus == 'CONFIRMED',
      )
      .length;
  int priority = findings
      .where(
        (f) =>
            f.currentStatus == 'PENDING_REVIEW' &&
            f.priorityLevel == 'PRIORITY_REVIEW',
      )
      .length;

  return DashboardStats(
    totalPatients: patients.length,
    totalDocuments: totalDocs,
    pendingDiscrepancies: pending,
    resolvedFindings: resolved,
    priorityReviewCount: priority,
  );
});

// Saved Reports Provider (Fast retrieval indexed on user's name)
final savedReportsProvider = FutureProvider<List<SavedReport>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final api = ref.watch(apiServiceProvider);
  final user = ref.watch(currentUserProvider);
  return await api.getSavedReports(userName: user?.fullName);
});

