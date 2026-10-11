import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../models/item.dart';
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
      return const Center(child: Text('Not signed in.'));
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isEmpty ? 'Student' : name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Student ID: ${studentId.isEmpty ? '-' : studentId}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Student',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Department'),
                subtitle: Text(dept.isEmpty ? '-' : dept),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('University Email'),
                subtitle: Text(email),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('My Listings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MyListingsScreen()),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('My Transactions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _TransactionsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Wishlist'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const WishlistScreen()),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openEditProfile(context, name, dept, studentId),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Admin dashboard link — only shown if the user has the admin
        // custom claim. We check this with a one-shot async call because
        // the StreamBuilder above only watches the profile doc.
        FutureBuilder<bool>(
          future: AuthService().isCurrentUserAdmin(),
          builder: (context, snap) {
            if (snap.data != true) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.shield, color: Colors.red),
                title: const Text('Admin Dashboard'),
                subtitle: const Text('Manage listings, reports, users'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              // The auth-state listener in MaterialApp will rebuild the
              // tree to LoginScreen as soon as signOut() flips the auth
              // state.
              await AuthService().logout();
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout',
                style: TextStyle(color: Colors.red)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: body);
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
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Department',
                controller: _dept,
                prefixIcon: Icons.school_outlined,
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
              const SizedBox(height: 8),
              const Text(
                'Note: Your email and admin status cannot be changed from the app.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
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
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<List<Transaction>>(
              stream: service.streamMyTransactions(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Transaction>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No transactions yet.\n'
                        'Open a listing and tap "Buy" to start a deal.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final t = items[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(t.status)
                              .withOpacity(0.15),
                          child: Icon(
                            Icons.receipt_long,
                            color: _statusColor(t.status),
                          ),
                        ),
                        title: Text(t.listingTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${t.tradeType} • ${t.price <= 0 ? 'Free' : '৳${t.price.toStringAsFixed(0)}'}\n'
                          '${t.buyerId == uid ? "You bought from ${t.sellerName}" : "You sold to ${t.buyerName}"}',
                        ),
                        isThreeLine: true,
                        trailing: _statusChip(t.status),
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
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red.shade700;
      case 'Confirmed':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(
              color: _statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
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