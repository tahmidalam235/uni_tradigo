import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/busy_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../data/approved_emails.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// RegisterScreen — creates a Firebase Auth account and writes the
/// matching profile document to Firestore at users/{uid}.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _department = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _authService = AuthService();
  final _userService = UserService();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _studentId, _email, _department, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;

    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (password != confirm) {
      _toast('Passwords do not match');
      return;
    }

    if (!isApprovedEmail(email)) {
      _toast('This email is not authorized to use Uni-Tradigo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final cred = await _authService.register(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw AuthException('Could not create account. Please try again.');
      }
      await _userService.saveProfile(
        uid: uid,
        name: _name.text.trim(),
        studentId: _studentId.text.trim(),
        department: _department.text.trim(),
        email: email,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Join the campus marketplace',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Only verified university students can register.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 22),
                CustomTextField(
                  label: 'Full Name',
                  controller: _name,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Student ID',
                  controller: _studentId,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'University Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Department',
                  controller: _department,
                  prefixIcon: Icons.school_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Password',
                  controller: _password,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Confirm Password',
                  controller: _confirm,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 24),
                BusyButton(
                  onPressed: _submit,
                  busy: _busy,
                  label: 'Create Account',
                  icon: Icons.person_add_alt_1_rounded,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineSoft),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'University email verification is planned for the real backend version.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
