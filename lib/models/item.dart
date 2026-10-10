// Item model — represents a single listing in the marketplace.
// Kept deliberately simple so it can later be mapped to a Firestore document.
// TODO: Replace with Firestore model when backend is integrated.

class Item {
  final String id;
  final String title;
  final String description;
  final double price; // 0.0 means Free (used for Donations)
  final String category;
  final String condition; // e.g. "Used", "Like New", "Good"
  final String tradeType; // "Sale", "Rent", "Exchange", "Donation"
  final String imageUrl; // placeholder/network
  final String sellerName;
  final String sellerEmail;
  final String sellerId;
  final String pickupLocation;
  final bool isAvailable;
  final DateTime postedAt;

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.tradeType,
    required this.imageUrl,
    required this.sellerName,
    required this.sellerEmail,
    required this.sellerId,
    required this.pickupLocation,
    this.isAvailable = true,
    DateTime? postedAt,
  }) : postedAt = postedAt ?? DateTime.now();

  // Display price in Taka. Returns "Free" for 0 price.
  String get priceLabel => price <= 0 ? 'Free' : '৳${price.toStringAsFixed(0)}';

  // Trade type tag color (used in cards).
  // We keep this simple to avoid an external dependency.
}

// Simple model for a chat message (used in the local chat demo).
class ChatMessage {
  final String sender; // "me" or "them"
  final String text;
  final DateTime time;

  ChatMessage({
    required this.sender,
    required this.text,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// Model for a wanted post.
class WantedPost {
  final String id;
  final String title;
  final String description;
  final String postedBy;
  final String department;
  final DateTime postedAt;

  WantedPost({
    required this.id,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.department,
    DateTime? postedAt,
  }) : postedAt = postedAt ?? DateTime.now();
}

// Model for a chat conversation shown on the Messages screen.
class Conversation {
  final String id;
  final String otherUserName;
  final String otherUserEmail;
  final String lastMessage;
  final DateTime lastTime;

  Conversation({
    required this.id,
    required this.otherUserName,
    required this.otherUserEmail,
    required this.lastMessage,
    DateTime? lastTime,
  }) : lastTime = lastTime ?? DateTime.now();
}