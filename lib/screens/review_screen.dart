import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../services/review_service.dart';
import '../services/transaction_service.dart';

/// ReviewScreen — submit a 1–5 star rating and written feedback for the
/// other party on a completed deal. One review per transaction per user
/// is allowed (enforced by ReviewService + Firestore rules).
class ReviewScreen extends StatefulWidget {
  final Item item;
  final String transactionId;
  const ReviewScreen({
    super.key,
    required this.item,
    required this.transactionId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final TextEditingController _feedback = TextEditingController();
  final _reviewService = ReviewService();
  bool _busy = false;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_feedback.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some feedback')),
      );
      return;
    }
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Resolve reviewer name and the user being reviewed.
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final reviewerName =
          (profileSnap.data()?['name'] ?? '').toString();

      // The reviewedId is the other party in the transaction.
      // Transactions are now stored on the participant's user doc
      // (see TransactionService), so we use fetchById instead of
      // reading from the legacy `transactions` collection.
      final tx = await TransactionService().fetchById(widget.transactionId);
      if (tx == null) {
        throw StateError('Transaction not found.');
      }
      final sellerId = tx.sellerId;
      final buyerId = tx.buyerId;
      final reviewedId =
          user.uid == sellerId ? buyerId : sellerId;

      await _reviewService.create(
        transactionId: widget.transactionId,
        listingId: widget.item.id,
        reviewerId: user.uid,
        reviewerName: reviewerName,
        reviewedId: reviewedId,
        rating: _rating,
        feedback: _feedback.text.trim(),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Thanks for your review!'),
          content: Text(
              'You rated ${widget.item.sellerName} $_rating stars.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate & Review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Rate your experience with ${widget.item.sellerName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                iconSize: 36,
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Write your feedback...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.send),
            label: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}