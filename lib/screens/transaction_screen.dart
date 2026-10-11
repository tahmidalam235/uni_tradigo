import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';
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

  Future<void> _confirmDeal() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
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
          TextButton(
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.item.priceLabel,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Status: $_status',
                      style: TextStyle(
                        color: _status == 'Cancelled'
                            ? Colors.red
                            : (_status == 'Completed'
                                ? Colors.green
                                : Colors.orange.shade800),
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(
                      'Buyer',
                      isBuyer
                          ? 'You'
                          : (widget.item.sellerName.isEmpty
                              ? 'You'
                              : widget.item.sellerName)),
                  const Divider(),
                  _row(
                      'Seller',
                      widget.item.sellerName.isEmpty
                          ? 'You'
                          : widget.item.sellerName),
                  const Divider(),
                  _row('Trade type', widget.item.tradeType),
                  const Divider(),
                  _row('Price', widget.item.priceLabel),
                  const Divider(),
                  _row('Pickup location', widget.item.pickupLocation),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_txId == null && isBuyer)
            ElevatedButton.icon(
              onPressed: _busy ? null : _confirmDeal,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Deal'),
            )
          else if (_status == 'Confirmed')
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _completeDeal,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Mark as Completed'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Deal'),
                ),
              ],
            )
          else if (_status == 'Completed')
            ElevatedButton.icon(
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
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Leave Review'),
            )
          else if (_status == 'Pending' && _txId != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel Deal'),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}