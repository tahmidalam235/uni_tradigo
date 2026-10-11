import '../models/item.dart';

// All in-memory dummy data lives here.
// This keeps screens clean and the data easy to swap with Firestore later.
// TODO: Replace with Firestore queries. For example:
//   final snap = await FirebaseFirestore.instance.collection('items').get();

class DummyData {
  // Currently logged-in "user" (for demo). Hard-coded for simplicity.
  static String currentUserName = 'Tahmid Alam';
  static String currentUserId = '23524202151';
  static String currentUserEmail = 'student@bup.edu.bd';
  static String currentUserDepartment = 'CSE';

  // Sample listings used in Home, Search, Wishlist, My Listings, etc.
  // Images use public placeholder URLs so the app works offline if they fail.
  // The cards also have a fallback icon so the UI never breaks.
  static final List<Item> listings = [
    Item(
      id: 'i1',
      title: 'Engineering Mathematics Book',
      description:
          'Engineering Mathematics by H. K. Dass. Used for one semester. All pages intact, no markings.',
      price: 450,
      category: 'Books',
      condition: 'Used',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Tahmid Alam',
      sellerEmail: 'student@bup.edu.bd',
      sellerId: '23524202151',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i2',
      title: 'Casio fx-991ES Scientific Calculator',
      description:
          'Casio fx-991ES Plus scientific calculator in good condition. Works perfectly, includes cover.',
      price: 900,
      category: 'Calculator',
      condition: 'Good',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Tahmid Alam',
      sellerEmail: 'student@bup.edu.bd',
      sellerId: '23524202151',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i3',
      title: 'Study Table',
      description:
          'Wooden study table, slightly used but very sturdy. Perfect for a dorm room.',
      price: 1500,
      category: 'Furniture',
      condition: 'Used',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Abdullah',
      sellerEmail: 'abdullah@bup.edu.bd',
      sellerId: '23524202002',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i4',
      title: 'Physics Textbook (Free)',
      description:
          'University Physics by Young & Freedman. Donating because I no longer need it.',
      price: 0,
      category: 'Books',
      condition: 'Good',
      tradeType: 'Donation',
      imageUrl: '',
      sellerName: 'Sadia',
      sellerEmail: 'sadia@bup.edu.bd',
      sellerId: '23524203003',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i5',
      title: 'Arduino Uno Starter Kit',
      description:
          'Arduino Uno R3 with breadboard, jumper wires, LEDs, resistors. Like new, only used twice.',
      price: 1200,
      category: 'Electronics',
      condition: 'Like New',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Tahmid Alam',
      sellerEmail: 'student@bup.edu.bd',
      sellerId: '23524202151',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i6',
      title: 'Desk Lamp',
      description:
          'LED desk lamp with adjustable brightness. USB powered. Perfect for late-night study.',
      price: 600,
      category: 'Accessories',
      condition: 'Like New',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Rifat',
      sellerEmail: 'rifat@bup.edu.bd',
      sellerId: '23524204004',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i7',
      title: 'Wireless Mouse (Logitech)',
      description:
          'Logitech M170 wireless mouse. Works with USB receiver. Good condition.',
      price: 350,
      category: 'Electronics',
      condition: 'Good',
      tradeType: 'Sale',
      imageUrl: '',
      sellerName: 'Tahmid Alam',
      sellerEmail: 'student@bup.edu.bd',
      sellerId: '23524202151',
      pickupLocation: 'BUP Campus',
    ),
    Item(
      id: 'i8',
      title: 'CSE Programming Book Bundle',
      description:
          'Let me exchange my CSE programming books (Let Us C, Java) for any calculus book.',
      price: 0,
      category: 'Books',
      condition: 'Good',
      tradeType: 'Exchange',
      imageUrl: '',
      sellerName: 'Nusrat',
      sellerEmail: 'nusrat@bup.edu.bd',
      sellerId: '23524205005',
      pickupLocation: 'BUP Campus',
    ),
  ];

  // Categories for the horizontal category bar on Home.
  static const List<String> categories = [
    'Books',
    'Electronics',
    'Calculator',
    'Accessories',
    'Furniture',
    'Others',
  ];

  // Trade types for filter chips and the Add Listing dropdown.
  static const List<String> tradeTypes = [
    'Sale',
    'Rent',
    'Exchange',
    'Donation',
  ];

  // Condition options used in Add Listing and filter.
  static const List<String> conditions = [
    'Like New',
    'Good',
    'Used',
  ];

  // Sample wanted posts.
  static final List<WantedPost> wantedPosts = [
    WantedPost(
      id: 'w1',
      title: 'Wanted: CSE Programming Book',
      description:
          'Looking for "Let Us C" by Yashavant Kanetkar. Used is fine.',
      postedBy: 'Rifat',
      department: 'CSE',
    ),
    WantedPost(
      id: 'w2',
      title: 'Wanted: Scientific Calculator',
      description: 'Need a Casio fx-991ES or similar for this semester.',
      postedBy: 'Sadia',
      department: 'EEE',
    ),
    WantedPost(
      id: 'w3',
      title: 'Wanted: Study Lamp',
      description: 'Looking for a working desk lamp, cheap is fine.',
      postedBy: 'Nusrat',
      department: 'BBA',
    ),
  ];

  // Sample conversations for the Messages screen.
  static final List<Conversation> conversations = [
    Conversation(
      id: 'c1',
      otherUserName: 'Abdullah',
      otherUserEmail: 'abdullah@bup.edu.bd',
      otherUserId: '23524202002',
      lastMessage: 'Is this calculator available?',
    ),
    Conversation(
      id: 'c2',
      otherUserName: 'Sadia',
      otherUserEmail: 'sadia@bup.edu.bd',
      otherUserId: '23524203003',
      lastMessage: 'I want to exchange this book.',
    ),
    Conversation(
      id: 'c3',
      otherUserName: 'Rifat',
      otherUserEmail: 'rifat@bup.edu.bd',
      otherUserId: '23524204004',
      lastMessage: 'Can I collect tomorrow?',
    ),
  ];

  // Initial seed chat for the demo conversation.
  // The first message list you see when you tap a conversation.
  static List<ChatMessage> seedChatFor(String conversationId) {
    if (conversationId == 'c1') {
      return [
        ChatMessage(sender: 'them', text: 'Hi, is the calculator still available?'),
        ChatMessage(sender: 'me', text: 'Yes, it is available.'),
        ChatMessage(sender: 'them', text: 'Can I collect it tomorrow?'),
        ChatMessage(sender: 'me', text: 'Sure.'),
      ];
    }
    return [
      ChatMessage(sender: 'them', text: 'Hello!'),
      ChatMessage(sender: 'me', text: 'Hi there.'),
    ];
  }

  // Dummy users for the Admin Manage Users section.
  static final List<Map<String, String>> adminUsers = [
    {
      'name': 'Tahmid Alam',
      'id': '23524202151',
      'email': 'student@bup.edu.bd',
      'status': 'Active',
    },
    {
      'name': 'Abdullah',
      'id': '23524202002',
      'email': 'abdullah@bup.edu.bd',
      'status': 'Active',
    },
    {
      'name': 'Sadia',
      'id': '23524203003',
      'email': 'sadia@bup.edu.bd',
      'status': 'Active',
    },
    {
      'name': 'Rifat',
      'id': '23524204004',
      'email': 'rifat@bup.edu.bd',
      'status': 'Suspended',
    },
  ];

  // Dummy reported listings for the Admin dashboard.
  static final List<Map<String, String>> reportedListings = [
    {
      'title': 'Suspicious Calculator Listing',
      'reason': 'Possibly fake',
      'status': 'Pending',
    },
    {
      'title': 'Duplicate Physics Book',
      'reason': 'Duplicate listing',
      'status': 'Pending',
    },
  ];
}
