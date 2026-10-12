import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart';
import '../services/listing_service.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';

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
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'No access',
          subtitle: 'You do not have permission to view this page.',
          accent: AppColors.danger,
        ),
      );
    }
    return _buildAdmin(context);
  }

  Widget _buildAdmin(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          // Live stats from Firestore.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _StatsRow(),
          ),
          const SectionHeader(
            title: 'Manage Listings',
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          ),
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
                        color: AppColors.infoContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.list_alt_rounded,
                        color: AppColors.info,
                      ),
                    ),
                    title: Text(
                      'All Listings',
                      style: AppTypography.titleSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showListings(context),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.dangerContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.danger,
                      ),
                    ),
                    title: Text(
                      'Reported Listings',
                      style: AppTypography.titleSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showReports(context),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'Manage Users',
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _userService.streamAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Could not load users: ${snapshot.error}'),
                    );
                  }
                  final users =
                      snapshot.data ?? const <Map<String, dynamic>>[];
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
                      final name = (u['name'] ?? '').toString();
                      return Column(
                        children: [
                          ListTile(
                            leading: UserAvatar(name: name, radius: 18),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name.isEmpty ? 'Unnamed' : name,
                                    style: AppTypography.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const VerifiedBadge(size: 12),
                                if (suspended) ...[
                                  const SizedBox(width: 6),
                                  const StatusPill(
                                    label: 'Suspended',
                                    tone: StatusTone.danger,
                                    fontSize: 10,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${u['email'] ?? ''}\nID: ${u['studentId'] ?? ''}',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: suspended
                                ? FilledButton.tonal(
                                    onPressed: () async {
                                      await _toggleSuspend(
                                        context,
                                        uid,
                                        true,
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      foregroundColor: AppColors.success,
                                    ),
                                    child: const Text('Reactivate'),
                                  )
                                : OutlinedButton(
                                    onPressed: () async {
                                      await _toggleSuspend(
                                        context,
                                        uid,
                                        false,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(
                                          color: AppColors.danger),
                                    ),
                                    child: const Text('Suspend'),
                                  ),
                          ),
                          const Divider(height: 0),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSuspend(
      BuildContext context, String uid, bool currentlySuspended) async {
    try {
      await _userService.setSuspended(uid, !currentlySuspended);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlySuspended ? 'User reactivated' : 'User suspended'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  void _showListings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Text(
                            'All Listings',
                            style: AppTypography.titleLarge,
                          ),
                          const Spacer(),
                          StatusPill(
                            label: '${items.length} total',
                            tone: StatusTone.neutral,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0),
                    Expanded(
                      child: items.isEmpty
                          ? const EmptyState(
                              icon: Icons.shopping_bag_rounded,
                              title: 'No listings',
                              subtitle: 'The marketplace is empty.',
                            )
                          : ListView.builder(
                              controller: controller,
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final item = items[i];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleSmall,
                                  ),
                                  subtitle: Text(
                                    '${item.sellerName} • ${item.tradeType}',
                                    style: AppTypography.bodySmall,
                                  ),
                                  trailing: TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await _listingService
                                            .deleteListing(item.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Removed ${item.title}'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('Failed: $e')),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.danger,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Remove',
                                      style:
                                          TextStyle(color: AppColors.danger),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
                  return const EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No pending reports',
                    subtitle: 'All reports have been resolved.',
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                  itemCount: reports.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Reported Listings',
                          style: AppTypography.titleLarge,
                        ),
                      );
                    }
                    final r = reports[i - 1];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: AppColors.danger,
                        ),
                      ),
                      title: Text(
                        (r['listingTitle'] ?? '').toString(),
                        style: AppTypography.titleSmall,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Reason: ${r['reason']}\nBy: ${r['reporterName']}',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          FilledButton.tonal(
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
                          OutlinedButton(
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
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
}

/// Live stats tiles backed by Firestore counts.
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
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
                      childAspectRatio: 1.7,
                      children: [
                        _StatTile(
                            icon: Icons.people_alt_rounded,
                            label: 'Total Users',
                            value: usersCount.toString(),
                            accent: AppColors.info),
                        _StatTile(
                            icon: Icons.list_alt_rounded,
                            label: 'Total Listings',
                            value: listingsCount.toString(),
                            accent: AppColors.success),
                        _StatTile(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Active Deals',
                            value: txCount.toString(),
                            accent: AppColors.warning),
                        _StatTile(
                            icon: Icons.flag_rounded,
                            label: 'Pending Reports',
                            value: reportsCount.toString(),
                            accent: AppColors.danger),
                      ],
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
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: AppTypography.titleLarge),
                Text(
                  label,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}