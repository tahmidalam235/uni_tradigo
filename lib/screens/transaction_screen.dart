import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_background.dart';
import '../widgets/busy_button.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/info_pill.dart';
import '../services/transaction_service.dart';
import 'review_screen.dart';

/// TransactionScreen — drives a deal through its lifecycle.
///
/// Two modes:
///   - listing only: shown right after tapping "Buy" on a listing. The
///     screen reserves the listing and creates the order in `Pending`.
///   - existing transaction: shown when opening an entry from "My
///     Transactions" — the order already exists.
///
/// The status is read live from Firestore, so both the buyer and the
/// seller see accept / reject / complete / cancel happen in real time
/// without either side having to refresh.
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
  StreamSubscription<Transaction?>? _txSub;
  String? _txId;
  String _status = 'Pending';
  bool _busy = false;

  /// True once we have an order for this listing.
  bool get _hasOrder => _txId != null;

  bool get _isSeller {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && widget.item.sellerId == uid;
  }

  bool get _isBuyer {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && widget.item.sellerId != uid;
  }

  @override
  void initState() {
    super.initState();
    _txId = widget.transactionId;
    if (widget.initialStatus != null) _status = widget.initialStatus!;
    _subscribe();
  }

  @override
  void dispose() {
    _txSub?.cancel();
    super.dispose();
  }

  /// Watches the order so status changes made by the other party appear
  /// here immediately.
  void _subscribe() {
    final id = _txId;
    if (id == null) return;
    _txSub?.cancel();
    _txSub = _txService.watchTransaction(id).listen((tx) {
      if (!mounted) return;
      if (tx == null) return;
      setState(() => _status = tx.status);
    });
  }

  StatusTone _toneForStatus(String status) {
    switch (status) {
      case 'Completed':
        return StatusTone.success;
      case 'Accepted':
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
      case 'Accepted':
      case 'Confirmed':
        return Icons.handshake_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  /// Places the order: reserves the listing and creates a `Pending`
  /// transaction in one atomic step.
  Future<void> _buyNow() async {
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
      // Read the buyer's display name.
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final buyerName =
          (profileSnap.data()?['name'] ?? '').toString();
      final id = await _txService.placeOrder(
        listing: widget.item,
        buyerId: user.uid,
        buyerName: buyerName,
      );
      if (!mounted) return;
      setState(() {
        _txId = id;
        _status = 'Pending';
      });
      _subscribe();
      _showSuccess();
    } on ListingUnavailableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place the order: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Seller accepts the order. The listing stays reserved.
  Future<void> _accept() async {
    if (_busy || _txId == null) return;
    setState(() => _busy = true);
    try {
      await _txService.acceptOrder(
        _txId!,
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (!mounted) return;
      setState(() => _status = 'Accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Seller marks the order as delivered and complete.
  Future<void> _completeDeal() async {
    if (_busy || _txId == null) return;
    setState(() => _busy = true);
    try {
      await _txService.completeOrder(
        id: _txId!,
        listingId: widget.item.id,
        actedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
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

  /// Either party cancels the order. The listing returns to `Available`.
  Future<void> _cancel() async {
    if (_busy || _txId == null) return;
    setState(() => _busy = true);
    try {
      await _txService.cancelOrder(
        id: _txId!,
        listingId: widget.item.id,
        actedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (!mounted) return;
      setState(() => _status = 'Cancelled');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
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
        title: const Text('Order placed'),
        content: const Text(
            'The seller has been notified. Coordinate pickup to complete the deal.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Pop everything above the home screen so the user lands
              // back on the home page after placing the order.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openReview() {
    if (_txId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          item: widget.item,
          transactionId: _txId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = _isBuyer;
    final isSeller = _isSeller;
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: AppBackground(
        child: ListView(
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
                    value: isSeller
                        ? (widget.item.sellerName.isEmpty
                            ? 'You'
                            : widget.item.sellerName)
                        : 'You',
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
          ..._buildActions(isBuyer: isBuyer, isSeller: isSeller),
          if (_status == 'Accepted' || _status == 'Pending') ...[
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
      ),
    );
  }

  /// Role-aware action buttons for the current status.
  ///
  /// - No order yet (buyer)  -> Buy Now
  /// - Pending   (seller)    -> Accept / Reject
  /// - Pending   (buyer)     -> Cancel Order
  /// - Accepted  (seller)    -> Mark as Completed / Cancel Order
  /// - Accepted  (buyer)     -> Cancel Order
  /// - Completed (both)      -> Leave Review
  /// - Cancelled (both)      -> nothing
  List<Widget> _buildActions({
    required bool isBuyer,
    required bool isSeller,
  }) {
    if (!_hasOrder) {
      if (!isBuyer) return const [];
      return [
        BusyButton(
          onPressed: _buyNow,
          busy: _busy,
          label: 'Buy Now',
          icon: Icons.shopping_cart_checkout_rounded,
          expand: true,
        ),
      ];
    }

    switch (_status) {
      case 'Pending':
        if (isSeller) {
          return [
            BusyButton(
              onPressed: _accept,
              busy: _busy,
              label: 'Accept Order',
              icon: Icons.check_circle_outline_rounded,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Reject Order'),
            ),
          ];
        }
        return [
          OutlinedButton.icon(
            onPressed: _busy ? null : _cancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel Order'),
          ),
        ];

      case 'Accepted':
      case 'Confirmed':
        if (isSeller) {
          return [
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
              label: const Text('Cancel Order'),
            ),
          ];
        }
        return [
          OutlinedButton.icon(
            onPressed: _busy ? null : _cancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel Order'),
          ),
        ];

      case 'Completed':
        // Reviews are only possible once the deal is done.
        return [
          BusyButton(
            onPressed: _openReview,
            busy: false,
            label: 'Leave Review',
            icon: Icons.rate_review_outlined,
            expand: true,
          ),
        ];

      case 'Cancelled':
      default:
        return const [];
    }
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
