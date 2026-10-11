import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart';
import '../services/listing_service.dart';
import '../models/item.dart';

/// AdminDashboardScreen — admin-only view for managing the marketplace.
///
/// Access is gated by the `admin` custom claim (set via Firebase
/// Auth / Admin SDK). The screen reads:
///   - listing count
///   - active user count
///   - pending reports
///   - open transactions
///   - listings (for removal)
///   - users (for suspension)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _reportService = ReportService();
  final _userService = UserService();
  final _listingService = ListingService();
  bool _isAdmin = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    AuthService().isCurrentUserAdmin().then((isAdmin) {
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _checked = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'You do not have permission to view this page.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return _buildAdmin(context);
  }

  Widget _buildAdmin(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: [
          // Live stats from Firestore.
          _StatsRow(),
          _Section(
            title: 'Manage Listings',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('All Listings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showListings(context),
                ),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Reported Listings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showReports(context),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Manage Users',
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userService.streamAllUsers(),
              builder: (context, snapshot) {
                final users =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No users yet.'),
                  );
                }
                return Column(
                  children: users.map((u) {
                    final suspended = u['suspended'] == true;
                    final uid = (u['uid'] ?? '').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                            ((u['name'] ?? '?') as String).isNotEmpty
                                ? (u['name'] as String)[0].toUpperCase()
                                : '?'),
                      ),
                      title: Text((u['name'] ?? '').toString()),
                      subtitle: Text(
                          '${u['email']}\nID: ${u['studentId'] ?? ''}'),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await _userService.setSuspended(
                                uid, !suspended);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(suspended
                                    ? 'User reactivated'
                                    : 'User suspended'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Update failed: $e'),
                              ),
                            );
                          }
                        },
                        child: Text(
                          suspended ? 'Reactivate' : 'Suspend',
                          style: TextStyle(
                              color: suspended
                                  ? Colors.green
                                  : Colors.red),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showListings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          builder: (_, controller) {
            return StreamBuilder<List<Item>>(
              stream: _listingService.streamAllListings(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <Item>[];
                if (items.isEmpty) {
                  return const Center(child: Text('No listings.'));
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      leading: const Icon(Icons.shopping_bag),
                      title: Text(item.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${item.sellerName} • ${item.tradeType}'),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await _listingService.deleteListing(item.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Removed ${item.title}')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        },
                        child: const Text('Remove',
                            style: TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showReports(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          builder: (_, controller) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reportService.streamPending(),
              builder: (context, snapshot) {
                final reports =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No pending reports.')),
                  );
                }
                return ListView(
                  controller: controller,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Reported Listings',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    for (final r in reports)
                      ListTile(
                        leading: const Icon(Icons.flag, color: Colors.red),
                        title: Text((r['listingTitle'] ?? '').toString()),
                        subtitle: Text(
                          'Reason: ${r['reason']}\nBy: ${r['reporterName']}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _reportService.resolve(
                                    reportId: (r['id'] ?? '').toString(),
                                    resolution: 'Approved',
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              },
                              child: const Text('Approve'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  final listingId =
                                      (r['listingId'] ?? '').toString();
                                  await _reportService.resolve(
                                    reportId: (r['id'] ?? '').toString(),
                                    resolution: 'Removed',
                                  );
                                  if (listingId.isNotEmpty) {
                                    await _listingService
                                        .deleteListing(listingId);
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              },
                              child: const Text('Remove',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Live stats tiles backed by Firestore counts.
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: StreamBuilder<QuerySnapshot>(
        stream: db.collection('listings').snapshots(),
        builder: (context, listingSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: db.collection('users').snapshots(),
            builder: (context, usersSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('reports')
                    .where('status', isEqualTo: 'Pending')
                    .snapshots(),
                builder: (context, reportsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: db
                        .collection('transactions')
                        .where('status',
                            whereIn: ['Pending', 'Confirmed'])
                        .snapshots(),
                    builder: (context, txSnap) {
                      final listingsCount =
                          listingSnap.data?.docs.length ?? 0;
                      final usersCount = usersSnap.data?.docs.length ?? 0;
                      final reportsCount =
                          reportsSnap.data?.docs.length ?? 0;
                      final txCount = txSnap.data?.docs.length ?? 0;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _StatTile(
                              icon: Icons.people,
                              label: 'Total Users',
                              value: usersCount.toString(),
                              color: Colors.blue),
                          _StatTile(
                              icon: Icons.list_alt,
                              label: 'Total Listings',
                              value: listingsCount.toString(),
                              color: Colors.green),
                          _StatTile(
                              icon: Icons.swap_horiz,
                              label: 'Active Deals',
                              value: txCount.toString(),
                              color: Colors.orange),
                          _StatTile(
                              icon: Icons.flag,
                              label: 'Pending Reports',
                              value: reportsCount.toString(),
                              color: Colors.red),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}