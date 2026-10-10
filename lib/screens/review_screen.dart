import 'package:flutter/material.dart';
import '../models/item.dart';

// ReviewScreen — allows the user to give a star rating and feedback.

class ReviewScreen extends StatefulWidget {
  final Item item;
  const ReviewScreen({super.key, required this.item});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final TextEditingController _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  void _submit() {
    if (_feedback.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some feedback')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thanks for your review!'),
        content: Text(
            'You rated ${widget.item.sellerName} $_rating stars.\nFeedback: ${_feedback.text}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Pop back to the previous screen (item details or home).
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: const Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}