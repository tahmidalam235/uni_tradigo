import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/busy_button.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
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
          icon: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.warningContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.warning,
              size: 36,
            ),
          ),
          title: const Text('Thanks for your review!'),
          content: Text(
              'You rated ${widget.item.sellerName} $_rating star${_rating == 1 ? '' : 's'}.'),
          actions: [
            FilledButton(
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Seller card header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  UserAvatar(name: widget.item.sellerName, radius: 24),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.sellerName.isEmpty
                              ? 'Seller'
                              : widget.item.sellerName,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'How would you rate this deal?',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
          ),
          // Stars row
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.warning,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _feedback,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Write your feedback...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          BusyButton(
            onPressed: _submit,
            busy: _busy,
            label: 'Submit Review',
            icon: Icons.send_rounded,
            expand: true,
          ),
        ],
      ),
    );
  }
}