import 'package:flutter/material.dart';
import '../data/dummy_data.dart';

// AdminDashboardScreen — demo-only admin view for the viva.
// Includes stats, manage listings, reported listings, manage users, analytics.

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Local copies so admin actions feel real.
  late List<Map<String, String>> _reports = List.from(DummyData.reportedListings);
  late List<Map<String, String>> _users = List.from(DummyData.adminUsers);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: [
          // Stats grid.
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: const [
                _StatTile(
                    icon: Icons.people,
                    label: 'Total Users',
                    value: '120',
                    color: Colors.blue),
                _StatTile(
                    icon: Icons.list_alt,
                    label: 'Total Listings',
                    value: '86',
                    color: Colors.green),
                _StatTile(
                    icon: Icons.swap_horiz,
                    label: 'Active Deals',
                    value: '24',
                    color: Colors.orange),
                _StatTile(
                    icon: Icons.flag,
                    label: 'Reports',
                    value: '5',
                    color: Colors.red),
              ],
            ),
          ),
          // Sections.
          _Section(
            title: 'Manage Listings',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('All Listings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _snack('All listings — demo only'),
                ),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Reported Listings'),
                  trailing: Text('${_reports.length}'),
                  onTap: _showReports,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Manage Users',
            child: Column(
              children: _users
                  .map(
                    (u) => ListTile(
                      leading: CircleAvatar(
                        child: Text(u['name']![0].toUpperCase()),
                      ),
                      title: Text(u['name']!),
                      subtitle: Text('${u['email']}\nID: ${u['id']}'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => _snack('Viewing ${u['name']}'),
                            child: const Text('View'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                u['status'] =
                                    u['status'] == 'Active' ? 'Suspended' : 'Active';
                              });
                            },
                            child: Text(
                              u['status'] == 'Active' ? 'Suspend' : 'Reactivate',
                              style: TextStyle(
                                  color: u['status'] == 'Active'
                                      ? Colors.red
                                      : Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          _Section(
            title: 'Analytics',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _Bar(label: 'Books', value: 0.7),
                  _Bar(label: 'Electronics', value: 0.5),
                  _Bar(label: 'Furniture', value: 0.3),
                  _Bar(label: 'Others', value: 0.4),
                  const SizedBox(height: 8),
                  Text(
                    'Most active categories on Uni-Tradigo (last 30 days)',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showReports() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          if (_reports.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No reports.'),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Reported Listings',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              for (final r in _reports)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.red),
                  title: Text(r['title']!),
                  subtitle: Text('Reason: ${r['reason']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheet(() => _reports.remove(r));
                          setState(() {});
                          Navigator.pop(ctx);
                          _snack('Approved: ${r['title']}');
                        },
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheet(() => _reports.remove(r));
                          setState(() {});
                          Navigator.pop(ctx);
                          _snack('Removed: ${r['title']}');
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
        });
      },
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
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  const _Bar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}