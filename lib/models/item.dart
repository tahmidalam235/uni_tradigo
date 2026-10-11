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
  final String otherUserId; // Firebase Auth UID of the other participant
  final String lastMessage;
  final DateTime lastTime;

  Conversation({
    required this.id,
    required this.otherUserName,
    required this.otherUserEmail,
    required this.otherUserId,
    required this.lastMessage,
    DateTime? lastTime,
  }) : lastTime = lastTime ?? DateTime.now();
}

// A profile snapshot — used by screens that show a student's name,
// department, and average rating without re-querying Firestore everywhere.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String studentId;
  final String department;
  final bool suspended;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
    required this.department,
    this.suspended = false,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      suspended: data['suspended'] == true,
    );
  }
}

// A deal / transaction record.
class Transaction {
  final String id;
  final String listingId;
  final String listingTitle;
  final String sellerId;
  final String sellerName;
  final String buyerId;
  final String buyerName;
  final String tradeType;
  final double price;
  final String pickupLocation;
  final String status; // 'Pending' | 'Confirmed' | 'Completed' | 'Cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.buyerName,
    required this.tradeType,
    required this.price,
    required this.pickupLocation,
    required this.status,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

// A review / rating record.
class Review {
  final String id;
  final String transactionId;
  final String listingId;
  final String reviewerId;
  final String reviewerName;
  final String reviewedId;
  final int rating; // 1..5
  final String feedback;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.transactionId,
    required this.listingId,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewedId,
    required this.rating,
    required this.feedback,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}