import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../services/chat_service.dart';
import '../services/listing_service.dart';
import '../services/report_service.dart';
import '../services/wishlist_service.dart';
import 'chat_screen.dart';
import 'transaction_screen.dart';

// ItemDetailsScreen — the most important screen for matching the proposal UI.
// Shows full item details, seller info, action buttons.
// TODO: Replace static data with Firestore document by id:
//   await FirebaseFirestore.instance.collection('items').doc(itemId).get();

class ItemDetailsScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  Widget _buildImage(BuildContext context, Item item) {
    final url = item.imageUrl;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _errorIcon(context, item.category),
        );
      } catch (e) {
        return _errorIcon(context, item.category);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _errorIcon(context, item.category),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _errorIcon(BuildContext context, String category) {
    return Center(
      child: Icon(
        _categoryIcon(category),
        size: 100,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        final item = appState.itemById(itemId);
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Item')),
            body: const Center(child: Text('Item not found.')),
          );
        }
        final isWished = appState.isWishlisted(item.id);
        // Ownership check: when the current user IS the seller of this
        // listing, we hide the Chat and Buy buttons and show a single
        // "Update Status" button instead, so users cannot message or
        // purchase their own listings.
        final isOwner =
            currentUid.isNotEmpty && item.sellerId == currentUid;
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: isWished ? 'Remove from wishlist' : 'Add to wishlist',
                onPressed: () async => _toggleWishlist(context, appState, item.id),
                icon: Icon(
                  isWished ? Icons.favorite : Icons.favorite_border,
                  color: isWished ? Colors.red : Colors.white,
                ),
              ),
              if (_canReport(context, item))
                IconButton(
                  tooltip: 'Report this listing',
                  onPressed: () => _openReportDialog(context, item),
                  icon: const Icon(Icons.flag_outlined),
                ),
            ],
          ),
          body: ListView(
            children: [
              // Hero image area — shows the Firestore image if available,
              // otherwise falls back to a category-icon placeholder.
              Container(
                height: 220,
                width: double.infinity,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                child: item.imageUrl.isNotEmpty
                    ? _buildImage(context, item)
                    : Center(
                        child: Icon(
                          _categoryIcon(item.category),
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.isAvailable
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              color: item.isAvailable
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.priceLabel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoPill('Condition', item.condition),
                        _infoPill('Type', item.tradeType),
                        _infoPill('Category', item.category),
                        _infoPill('Pickup', item.pickupLocation),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Description',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Seller',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            item.sellerName.isNotEmpty
                                ? item.sellerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.sellerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified,
                                      color: Colors.green, size: 16),
                                ],
                              ),
                              Text(
                                'ID: ${item.sellerId}',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 12),
                              ),
                              Text(
                                item.sellerEmail,
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Posted: ${_formatTime(item.postedAt)}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              // When the current user is the seller, show Wishlist + a
              // single Update Status button (Available/Unavailable) and
              // hide Chat + Buy so they cannot message or buy themselves.
              // For other users, keep the original Wishlist + Chat + Buy
              // row unchanged.
              child: isOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleWishlist(
                                context, appState, item.id),
                            icon: Icon(
                              isWished
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            label: Text(
                                isWished ? 'Wishlisted' : 'Wishlist'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: item.isAvailable
                                ? () => _setAvailability(
                                      context, appState, item, false,
                                    )
                                : () => _setAvailability(
                                      context, appState, item, true,
                                    ),
                            icon: Icon(
                              item.isAvailable
                                  ? Icons.archive_outlined
                                  : Icons.unarchive_outlined,
                            ),
                            label: Text(
                              item.isAvailable
                                  ? 'Mark Unavailable'
                                  : 'Mark Available',
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleWishlist(
                                context, appState, item.id),
                            icon: Icon(
                              isWished
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            label: Text(
                                isWished ? 'Wishlisted' : 'Wishlist'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: item.sellerId.isEmpty
                                ? null
                                : () => _openChat(context, item),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Chat'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransactionScreen(item: item),
                                ),
                              );
                            },
                            icon:
                                const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Buy'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleWishlist(
      BuildContext context, AppState appState, String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isWished = appState.isWishlisted(itemId);
    appState.toggleWishlistLocal(itemId);
    try {
      final svc = WishlistService();
      if (isWished) {
        await svc.remove(user.uid, itemId);
      } else {
        await svc.add(user.uid, itemId);
      }
    } catch (e) {
      appState.toggleWishlistLocal(itemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update wishlist: $e')),
      );
    }
  }

  /// Toggles the listing's availability (Active <-> Archived) for the
  /// owner. Updates Firestore via [ListingService.setAvailability] and
  /// keeps the in-memory AppState cache in sync so the badge and the
  /// button label refresh immediately.
  Future<void> _setAvailability(
    BuildContext context,
    AppState appState,
    Item item,
    bool isAvailable,
  ) async {
    if (item.sellerId != FirebaseAuth.instance.currentUser?.uid) return;
    try {
      await ListingService().setAvailability(item.id, isAvailable);
      // Reflect the new state in the local cache so the badge/button
      // update on the next AnimatedBuilder tick.
      appState.replaceListings([
        for (final existing in appState.listings)
          if (existing.id == item.id)
            Item(
              id: existing.id,
              title: existing.title,
              description: existing.description,
              price: existing.price,
              category: existing.category,
              condition: existing.condition,
              tradeType: existing.tradeType,
              imageUrl: existing.imageUrl,
              sellerName: existing.sellerName,
              sellerEmail: existing.sellerEmail,
              sellerId: existing.sellerId,
              pickupLocation: existing.pickupLocation,
              isAvailable: isAvailable,
              postedAt: existing.postedAt,
            )
          else
            existing,
      ]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }

  Future<void> _openChat(BuildContext context, Item item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (item.sellerId.isEmpty || item.sellerId == user.uid) {
      // Can't chat with yourself.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself.')),
      );
      return;
    }
    // My display name.
    final profileSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final myName = (profileSnap.data()?['name'] ?? '').toString();
    final chat = ChatService();
    final convoId = await chat.ensureConversation(
      myUid: user.uid,
      myName: myName,
      otherUid: item.sellerId,
      otherName: item.sellerName,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerName: item.sellerName,
          peerEmail: item.sellerEmail,
          peerUid: item.sellerId,
          conversationId: convoId,
        ),
      ),
    );
  }

  bool _canReport(BuildContext context, Item item) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // You can only report listings that you don't own.
    return item.sellerId.isNotEmpty && item.sellerId != user.uid;
  }

  Future<void> _openReportDialog(BuildContext context, Item item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report listing'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Why is this listing inappropriate?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (snap.data()?['name'] ?? '').toString();
      await ReportService().createReport(
        listingId: item.id,
        listingTitle: item.title,
        reason: reason,
        reporterId: user.uid,
        reporterName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    }
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: TextStyle(
              color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Books':
        return Icons.menu_book;
      case 'Electronics':
        return Icons.devices;
      case 'Calculator':
        return Icons.calculate;
      case 'Accessories':
        return Icons.lightbulb_outline;
      case 'Furniture':
        return Icons.chair;
      default:
        return Icons.shopping_bag;
    }
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}