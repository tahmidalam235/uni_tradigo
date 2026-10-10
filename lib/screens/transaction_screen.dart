import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/dummy_data.dart';
import 'review_screen.dart';

// TransactionScreen — confirms a deal between buyer and seller.
// No real payment integration — demo only.

class TransactionScreen extends StatelessWidget {
  final Item item;

  const TransactionScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
                    item.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(item.priceLabel,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
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
                  _row('Buyer', DummyData.currentUserName),
                  const Divider(),
                  _row('Seller', item.sellerName),
                  const Divider(),
                  _row('Trade type', item.tradeType),
                  const Divider(),
                  _row('Price', item.priceLabel),
                  const Divider(),
                  _row('Pickup location', item.pickupLocation),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Deal Confirmed'),
                  content: const Text('Deal confirmed successfully!'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ReviewScreen(item: item),
                          ),
                        );
                      },
                      child: const Text('Leave Review'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm Deal'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
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