import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';

enum AuthMode { signIn, register, resetPassword }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AuthMode _authMode = AuthMode.signIn;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: "clinician.demo@recordguard.ai");
  final _passwordController = TextEditingController(text: "ClinicPass2026!");
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController(text: "Dr. Alex Rivera");

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String _selectedRegisterRole = "Clinical Reviewer";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _authMode = mode;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No clinician account found for this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or credentials. Please check and try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in instead.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid clinical email address.';
      case 'user-disabled':
        return 'This clinician account has been disabled. Please contact administrator.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment or reset your password.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console. Please enable it in Auth Settings.';
      case 'network-request-failed':
        return 'Network connection failure. Check device internet connection or backend.';
      default:
        return e.message ?? 'Authentication error occurred (${e.code}).';
    }
  }

  Future<void> _handleFirebaseSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_authMode == AuthMode.resetPassword) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _successMessage = 'Password reset link sent to $email. Please check your inbox.';
          });
        }
        return;
      }

      UserCredential userCredential;
      if (_authMode == AuthMode.register) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final displayName = _nameController.text.trim();
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final fbUser = userCredential.user;
      if (fbUser != null) {
        // Retrieve fresh ID token
        final idToken = await fbUser.getIdToken();
        final api = ref.read(apiServiceProvider);
        api.setAuthToken(idToken);

        final enteredName = _nameController.text.trim();
        String resolvedName;
        if (_authMode == AuthMode.register && enteredName.isNotEmpty) {
          resolvedName = enteredName;
        } else if (fbUser.displayName != null && fbUser.displayName!.isNotEmpty) {
          resolvedName = fbUser.displayName!;
        } else if (enteredName.isNotEmpty) {
          resolvedName = enteredName;
        } else {
          resolvedName = "Clinician Reviewer";
        }

        final userRole = (_authMode == AuthMode.register)
            ? _selectedRegisterRole
            : (fbUser.email?.toLowerCase().contains('admin') == true ? "System Administrator" : "Clinical Reviewer");

        // Update profile on backend
        try {
          await api.updateProfile(fullName: resolvedName, role: userRole);
        } catch (_) {}

        final userObj = CurrentUser(
          id: fbUser.uid,
          username: fbUser.email ?? fbUser.uid,
          fullName: resolvedName,
          role: userRole,
          isDemo: false,
        );

        await ref.read(currentUserProvider.notifier).setUser(userObj, token: idToken);

        if (mounted) {
          if (userObj.isAdmin) {
            context.go('/admin');
          } else {
            context.go('/dashboard');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFirebaseError(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication failed: $e';
        });
      }
    }
  }

  Future<void> _handleDemoLogin({bool isAdmin = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final demoUsername = isAdmin ? "admin.demo" : "clinician.demo";
      final res = await api.demoLogin(demoUsername);

      final enteredName = _nameController.text.trim();
      final defaultName = isAdmin ? "Dr. Sarah Vance, CMIO (Admin)" : "Dr. Alex Rivera, MD";
      final resolvedName = enteredName.isNotEmpty
          ? enteredName
          : (res['full_name'] ?? defaultName);
      final role = isAdmin ? "System Administrator" : (res['role'] ?? "Attending Physician / Clinical Reviewer");

      final userObj = CurrentUser(
        id: res['id'] ?? (isAdmin ? "USR-ADMIN-01" : "USR-DEMO-01"),
        username: res['username'] ?? demoUsername,
        fullName: resolvedName,
        role: role,
        isDemo: true,
      );

      await ref.read(currentUserProvider.notifier).setUser(userObj);

      if (mounted) {
        if (isAdmin) {
          context.go('/admin');
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Offline demonstration bypass unavailable. Ensure backend is running or use Firebase sign-in.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Badge & Brand
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 40,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "RecordGuard AI",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Healthcare Record Contradiction Detector",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Segmented Mode Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModeTab(
                                label: "Sign In",
                                isSelected: _authMode == AuthMode.signIn,
                                onTap: () => _switchMode(AuthMode.signIn),
                              ),
                            ),
                            Expanded(
                              child: _buildModeTab(
                                label: "Register",
                                isSelected: _authMode == AuthMode.register,
                                onTap: () => _switchMode(AuthMode.register),
                              ),
                            ),
                            Expanded(
                              child: _buildModeTab(
                                label: "Reset PIN",
                                isSelected: _authMode == AuthMode.resetPassword,
                                onTap: () => _switchMode(AuthMode.resetPassword),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Success message banner
                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.successGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Error message banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.dangerRose.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: AppTheme.dangerRose),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.dangerRose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Register Name Field
                      if (_authMode == AuthMode.register) ...[
                        const Text(
                          "FULL CLINICAL NAME",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: "e.g., Dr. Alex Rivera, MD",
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your clinical name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      const Text(
                        "CLINICAL EMAIL ADDRESS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: "clinician@hospital.org",
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field (Hidden in reset password mode)
                      if (_authMode != AuthMode.resetPassword) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "PASSWORD",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_authMode == AuthMode.signIn)
                              GestureDetector(
                                onTap: () => _switchMode(AuthMode.resetPassword),
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "••••••••",
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Confirm Password (Registration only)
                      if (_authMode == AuthMode.register) ...[
                        const Text(
                          "CONFIRM PASSWORD",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: "••••••••",
                            prefixIcon: const Icon(Icons.lock_reset, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (_authMode == AuthMode.register) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "ASSIGNED ROLE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedRegisterRole,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: "Clinical Reviewer", child: Text("Clinical Reviewer (Doctor/Nurse)")),
                            DropdownMenuItem(value: "System Administrator", child: Text("System Administrator (Admin/IT)")),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRegisterRole = val);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 8),

                      // Primary Action Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleFirebaseSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _authMode == AuthMode.signIn
                                    ? "Sign In to Workspace"
                                    : _authMode == AuthMode.register
                                        ? (_selectedRegisterRole.contains("Admin")
                                            ? "Create Administrator Account"
                                            : "Create Clinician Account")
                                        : "Send Password Reset Link",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                      ),

                      // Dual Demo Portals for evaluation: Clinician & Administrator
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.medical_services_outlined, size: 15, color: AppTheme.accentTeal),
                              label: const Text(
                                "Clinician Demo",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentTeal),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppTheme.accentTeal.withOpacity(0.4)),
                                backgroundColor: AppTheme.accentTeal.withOpacity(0.08),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoading ? null : () => _handleDemoLogin(isAdmin: false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.admin_panel_settings, size: 16, color: Color(0xFFB45309)),
                              label: const Text(
                                "Admin Demo",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                backgroundColor: const Color(0xFFFEF3C7),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoading ? null : () => _handleDemoLogin(isAdmin: true),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Synthetic Data Disclaimer
                      const Text(
                        "RecordGuard AI strictly operates on synthetic clinical cases. Passwords are encrypted and verified exclusively via Google Firebase Authentication. No plain passwords or PHI are stored on backend databases.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
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

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
