import 'package:flutter/widgets.dart';
import '../models/item.dart';
import 'dummy_data.dart';

// AppState — a tiny in-memory store using ChangeNotifier so any screen can
// react to changes (wishlist added, listing posted, chat message, etc.).
// This is intentionally NOT a global provider — we instantiate it once
// inside main.dart and pass it down via an InheritedWidget.
// This keeps the architecture trivially understandable for a viva.
//
// TODO: Replace with Firestore streams. For example:
//   FirebaseFirestore.instance.collection('items').snapshots()
//   .listen((snap) => items = snap.docs.map(...).toList());

class AppState extends ChangeNotifier {
  // Wishlist item IDs.
  final Set<String> _wishlist = <String>{};

  // Live mutable list of listings — initially seeded with dummy data.
  final List<Item> _listings = List<Item>.from(DummyData.listings);

  // Live mutable chat messages, keyed by conversation id.
  final Map<String, List<ChatMessage>> _messages = {
    for (final c in DummyData.conversations) c.id: DummyData.seedChatFor(c.id),
  };

  Set<String> get wishlist => _wishlist;

  List<Item> get listings => List.unmodifiable(_listings);

  // Get an item by id.
  Item? itemById(String id) {
    try {
      return _listings.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  // List of items in the current user's wishlist.
  List<Item> get wishlistItems => _listings
      .where((i) => _wishlist.contains(i.id))
      .toList(growable: false);

  // List of items posted by the current user.
  List<Item> get myListings => _listings
      .where((i) => i.sellerId == DummyData.currentUserId)
      .toList(growable: false);

  bool isWishlisted(String id) => _wishlist.contains(id);

  void toggleWishlist(String id) {
    if (_wishlist.contains(id)) {
      _wishlist.remove(id);
    } else {
      _wishlist.add(id);
    }
    notifyListeners();
  }

  // Add a brand-new listing. Generates a simple unique id.
  void addListing(Item item) {
    _listings.insert(0, item);
    notifyListeners();
  }

  // Replaces the full listings list (used to sync Firestore + dummy).
  void replaceListings(List<Item> items) {
    // Avoid unnecessary notifications if the list is structurally the same.
    _listings
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  // Delete by id — used by My Listings.
  void deleteListing(String id) {
    _listings.removeWhere((i) => i.id == id);
    _wishlist.remove(id);
    notifyListeners();
  }

  // Toggle availability — used by My Listings "Archive/Activate".
  void toggleAvailable(String id) {
    final idx = _listings.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _listings[idx];
    _listings[idx] = Item(
      id: old.id,
      title: old.title,
      description: old.description,
      price: old.price,
      category: old.category,
      condition: old.condition,
      tradeType: old.tradeType,
      imageUrl: old.imageUrl,
      sellerName: old.sellerName,
      sellerEmail: old.sellerEmail,
      sellerId: old.sellerId,
      pickupLocation: old.pickupLocation,
      isAvailable: !old.isAvailable,
      postedAt: old.postedAt,
    );
    notifyListeners();
  }

  // Chat helpers.
  List<ChatMessage> messagesFor(String conversationId) =>
      _messages[conversationId] ?? <ChatMessage>[];

  void sendMessage(String conversationId, String text, {required bool fromMe}) {
    _messages.putIfAbsent(conversationId, () => <ChatMessage>[]);
    _messages[conversationId]!.add(
      ChatMessage(
        sender: fromMe ? 'me' : 'them',
        text: text,
      ),
    );
    notifyListeners();
  }
}

// AppStateScope — a tiny InheritedWidget so any screen can look up AppState
// without an external package. Because AppState is a ChangeNotifier, we listen
// to it in each screen via `AnimatedBuilder(animation: AppStateScope.of(ctx))`.
class AppStateScope extends InheritedWidget {
  final AppState appState;

  const AppStateScope({
    super.key,
    required this.appState,
    required super.child,
  });

  // Lookup without registering a dependency — we rebuild via AnimatedBuilder.
  static AppState of(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<AppStateScope>()
        ?.widget as AppStateScope?;
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.appState;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) =>
      oldWidget.appState != appState;
}