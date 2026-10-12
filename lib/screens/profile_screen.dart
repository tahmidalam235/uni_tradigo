import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/busy_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_pill.dart';
import '../widgets/user_avatar.dart';
import 'my_listings_screen.dart';
import 'wishlist_screen.dart';
import 'admin_dashboard_screen.dart';
import 'transaction_screen.dart';
import '../widgets/custom_text_field.dart';

/// ProfileScreen — student profile + navigation to sub-screens.
/// Reads the profile from Firestore in real time, lets the user edit
/// their name and department, and exposes logout, My Listings,
/// Wishlist, Transactions, and (for admins) the admin dashboard.
class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Not signed in',
        subtitle: 'Please log in to view your profile.',
      );
    }
    final userService = UserService();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: userService.streamProfile(user.uid),
      builder: (context, snap) {
        final data = snap.data ?? const {};
        final name = (data['name'] ?? '').toString();
        final studentId = (data['studentId'] ?? '').toString();
        final dept = (data['department'] ?? '').toString();
        final email = (data['email'] ?? user.email ?? '').toString();
        return _buildBody(context, name, studentId, dept, email);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    String name,
    String studentId,
    String dept,
    String email,
  ) {
    final body = ListView(
      children: [
        // Hero header with brand gradient + bottom-rounded shape
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: UserAvatar(
                  name: name,
                  radius: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                name.isEmpty ? 'Student' : name,
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Student ID: ${studentId.isEmpty ? '—' : studentId}',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Student',
                      style: AppTypography.labelMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  title: Text('Department', style: AppTypography.bodySmall),
                  subtitle: Text(
                    dept.isEmpty ? '—' : dept,
                    style: AppTypography.titleSmall,
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.alternate_email_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  title: Text('University Email',
                      style: AppTypography.bodySmall),
                  subtitle: Text(
                    email,
                    style: AppTypography.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              children: [
                _navTile(
                  context,
                  icon: Icons.list_alt_rounded,
                  title: 'My Listings',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const MyListingsScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                _navTile(
                  context,
                  icon: Icons.swap_horiz_rounded,
                  title: 'My Transactions',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _TransactionsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 0),
                _navTile(
                  context,
                  icon: Icons.favorite_border_rounded,
                  title: 'Wishlist',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const WishlistScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                _navTile(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: () => _openEditProfile(context, name, dept, studentId),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Admin dashboard link — only shown if the user has the admin
        // custom claim. We check this with a one-shot async call because
        // the StreamBuilder above only watches the profile doc.
        FutureBuilder<bool>(
          future: AuthService().isCurrentUserAdmin(),
          builder: (context, snap) {
            if (snap.data != true) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.dangerContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.danger,
                    ),
                  ),
                  title: const Text('Admin Dashboard',
                      style: AppTypography.titleSmall),
                  subtitle: const Text(
                    'Manage listings, reports, users',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              // The auth-state listener in MaterialApp will rebuild the
              // tree to LoginScreen as soon as signOut() flips the auth
              // state.
              await AuthService().logout();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Logout'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: body);
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary),
      ),
      title: Text(title, style: AppTypography.titleSmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _openEditProfile(BuildContext context, String currentName,
      String currentDept, String currentStudentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EditProfileScreen(
          currentName: currentName,
          currentDepartment: currentDept,
          currentStudentId: currentStudentId,
        ),
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentDepartment;
  final String currentStudentId;
  const _EditProfileScreen({
    required this.currentName,
    required this.currentDepartment,
    required this.currentStudentId,
  });

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dept;
  late final TextEditingController _studentId;
  final _userService = UserService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.currentName);
    _dept = TextEditingController(text: widget.currentDepartment);
    _studentId = TextEditingController(text: widget.currentStudentId);
  }

  @override
  void dispose() {
    _name.dispose();
    _dept.dispose();
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await _userService.updateProfile(
        uid: user.uid,
        name: _name.text.trim(),
        department: _dept.text.trim(),
        studentId: _studentId.text.trim(),
        // Pass the Firebase Auth email so the create-on-missing path
        // can write the correct `email` field that the security rules
        // require to remain immutable.
        fallbackEmail: user.email,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              CustomTextField(
                label: 'Full Name',
                controller: _name,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomTextField(
                label: 'Department',
                controller: _dept,
                prefixIcon: Icons.school_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomTextField(
                label: 'Student ID',
                controller: _studentId,
                prefixIcon: Icons.badge_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
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
                        'Your email and admin status cannot be changed from the app.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              BusyButton(
                onPressed: _save,
                busy: _busy,
                label: 'Save Changes',
                icon: Icons.save_rounded,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// My Transactions screen — backed by TransactionService.
class _TransactionsScreen extends StatelessWidget {
  const _TransactionsScreen();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = TransactionService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Transactions')),
      body: uid.isEmpty
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Please log in',
              subtitle: 'Sign in to view your transactions.',
            )
          : StreamBuilder<List<Transaction>>(
              stream: service.streamMyTransactions(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: 'Details: ${snapshot.error}',
                    onRetry: () => (context as Element).markNeedsBuild(),
                  );
                }
                final items = snapshot.data ?? const <Transaction>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions yet',
                    subtitle:
                        'Open a listing and tap "Buy" to start a deal.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = items[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(t.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: _statusColor(t.status),
                          ),
                        ),
                        title: Text(
                          t.listingTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${t.tradeType} • ${t.price <= 0 ? 'Free' : '৳${t.price.toStringAsFixed(0)}'}\n'
                            '${t.buyerId == uid ? "You bought from ${t.sellerName}" : "You sold to ${t.buyerName}"}',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: StatusPill(
                          label: t.status,
                          tone: _statusTone(t.status),
                          fontSize: 10,
                        ),
                        onTap: () => _openDetails(context, t),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.danger;
      case 'Confirmed':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  StatusTone _statusTone(String status) {
    switch (status) {
      case 'Completed':
        return StatusTone.success;
      case 'Cancelled':
        return StatusTone.danger;
      case 'Confirmed':
        return StatusTone.info;
      default:
        return StatusTone.warning;
    }
  }

  void _openDetails(BuildContext context, Transaction t) {
    // We need an Item-like wrapper for TransactionScreen which expects
    // an Item. Pass an Item constructed from the transaction fields.
    final fakeItem = Item(
      id: t.listingId,
      title: t.listingTitle,
      description: '',
      price: t.price,
      category: '',
      condition: '',
      tradeType: t.tradeType,
      imageUrl: '',
      sellerName: t.sellerName,
      sellerEmail: '',
      sellerId: t.sellerId,
      pickupLocation: t.pickupLocation,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionScreen(
          item: fakeItem,
          transactionId: t.id,
          initialStatus: t.status,
        ),
      ),
    );
  }
}