import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../data/approved_emails.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'home_screen.dart';

// RegisterScreen — creates a Firebase Auth account and writes the matching
// profile document to Firestore at users/{uid}.

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

    // Approved-email gate (exact match, trimmed, lowercased).
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
      if (!mounted) return;
      // Skip the success dialog and go straight to Home so the flow
      // matches LoginScreen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only verified university students can register.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Full Name',
                  controller: _name,
                  prefixIcon: Icons.person_outline,
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
                  prefixIcon: Icons.email_outlined,
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
                  prefixIcon: Icons.lock_outline,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Confirm Password',
                  controller: _confirm,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Note: University email verification is planned for the real backend version.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
