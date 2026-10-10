import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../services/auth_service.dart';
import 'my_listings_screen.dart';
import 'wishlist_screen.dart';
import 'transaction_screen.dart';
import '../models/item.dart';

// ProfileScreen — student profile + navigation to sub-screens.
// `embedded=true` means it's a tab in HomeScreen.

class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
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
                  DummyData.currentUserName.isNotEmpty
                      ? DummyData.currentUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                DummyData.currentUserName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Student ID: ${DummyData.currentUserId}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                subtitle: Text(DummyData.currentUserDepartment),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('University Email'),
                subtitle: Text(DummyData.currentUserEmail),
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
                  // For demo, show a simple list of dummy transactions.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _TransactionsDemoScreen(),
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Edit profile is planned for the real backend version.')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              // The main auth-state listener in MaterialApp will rebuild the
              // tree to LoginScreen as soon as signOut() flips the auth state.
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
}

// Small placeholder screen for "My Transactions" —
// just shows a couple of past items with their price.
class _TransactionsDemoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Reuse any items the current user has ever listed as "past transactions".
    final items = DummyData.listings
        .where((i) => i.sellerId == DummyData.currentUserId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My Transactions')),
      body: items.isEmpty
          ? const Center(child: Text('No transactions yet.'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final Item it = items[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(it.title),
                    subtitle: Text('${it.tradeType} • ${it.priceLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionScreen(item: it),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}