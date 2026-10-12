import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/busy_button.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/info_pill.dart';
import '../services/transaction_service.dart';
import 'review_screen.dart';

/// TransactionScreen — confirms a deal between buyer and seller and
/// drives the transaction through its lifecycle states.
///
/// Two modes:
///   - listing only: shown right after tapping "Buy" on a listing; the
///     screen creates the deal in Firestore in `Pending` status.
///   - existing transaction: shown when opening an entry from "My
///     Transactions" — the deal already exists, so we let the buyer/
///     seller confirm or cancel it.
class TransactionScreen extends StatefulWidget {
  final Item item;
  final String? transactionId;
  final String? initialStatus;

  const TransactionScreen({
    super.key,
    required this.item,
    this.transactionId,
    this.initialStatus,
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _txService = TransactionService();
  String? _txId;
  String _status = 'Pending';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _txId = widget.transactionId;
    if (widget.initialStatus != null) _status = widget.initialStatus!;
  }

  StatusTone _toneForStatus(String status) {
    switch (status) {
      case 'Completed':
        return StatusTone.success;
      case 'Confirmed':
        return StatusTone.info;
      case 'Cancelled':
        return StatusTone.danger;
      default:
        return StatusTone.warning;
    }
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_outline_rounded;
      case 'Confirmed':
        return Icons.handshake_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  Future<void> _confirmDeal() async {
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (widget.item.sellerId.isNotEmpty &&
        widget.item.sellerId == user.uid) {
      // Sellers can't buy their own listing.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot buy your own listing.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (_txId == null) {
        // Read the buyer's display name.
        final profileSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final buyerName =
            (profileSnap.data()?['name'] ?? '').toString();
        final id = await _txService.createDeal(
          listing: widget.item,
          buyerId: user.uid,
          buyerName: buyerName,
        );
        _txId = id;
      }
      await _txService.updateStatus(_txId!, 'Confirmed');
      if (!mounted) return;
      setState(() => _status = 'Confirmed');
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeDeal() async {
    if (_busy || _txId == null) return;
    setState(() => _busy = true);
    try {
      await _txService.updateStatus(_txId!, 'Completed');
      if (!mounted) return;
      setState(() => _status = 'Completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal marked complete.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy || _txId == null) return;
    setState(() => _busy = true);
    try {
      await _txService.updateStatus(_txId!, 'Cancelled');
      if (!mounted) return;
      setState(() => _status = 'Cancelled');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.successContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.success,
            size: 36,
          ),
        ),
        title: const Text('Deal Confirmed'),
        content: const Text(
            'The seller has been notified. Coordinate pickup to complete the deal.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    item: widget.item,
                    transactionId: _txId!,
                  ),
                ),
              );
            },
            child: const Text('Leave Review'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Pop everything above the home screen so the user lands
              // back on the home page after confirming the deal.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isBuyer = user != null && user.uid != widget.item.sellerId;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Deal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.item.priceLabel,
                    style: AppTypography.headlineSmall.copyWith(
                      color: widget.item.price <= 0
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  StatusPill(
                    label: _status,
                    tone: _toneForStatus(_status),
                    icon: _iconForStatus(_status),
                    fontSize: 12,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(
            title: 'Deal details',
            padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _row(
                    label: 'Buyer',
                    value: isBuyer
                        ? 'You'
                        : (widget.item.sellerName.isEmpty
                            ? 'You'
                            : widget.item.sellerName),
                  ),
                  const Divider(),
                  _row(
                    label: 'Seller',
                    value: widget.item.sellerName.isEmpty
                        ? 'You'
                        : widget.item.sellerName,
                  ),
                  const Divider(),
                  _row(
                    label: 'Trade type',
                    value: widget.item.tradeType,
                  ),
                  const Divider(),
                  _row(
                    label: 'Price',
                    value: widget.item.priceLabel,
                  ),
                  const Divider(),
                  _row(
                    label: 'Pickup',
                    value: widget.item.pickupLocation,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_txId == null && isBuyer)
            BusyButton(
              onPressed: _confirmDeal,
              busy: _busy,
              label: 'Confirm Deal',
              icon: Icons.check_circle_outline_rounded,
              expand: true,
            )
          else if (_status == 'Confirmed')
            Column(
              children: [
                BusyButton(
                  onPressed: _completeDeal,
                  busy: _busy,
                  label: 'Mark as Completed',
                  icon: Icons.task_alt_rounded,
                  expand: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel Deal'),
                ),
              ],
            )
          else if (_status == 'Completed')
            BusyButton(
              onPressed: () {
                if (_txId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      item: widget.item,
                      transactionId: _txId!,
                    ),
                  ),
                );
              },
              busy: _busy,
              label: 'Leave Review',
              icon: Icons.rate_review_outlined,
              expand: true,
            )
          else if (_status == 'Pending' && _txId != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel Deal'),
            ),
          if (_status == 'Confirmed' || _status == 'Pending') ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: InfoPill(
                icon: Icons.info_outline_rounded,
                label: 'Coordinate pickup via Messages',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}