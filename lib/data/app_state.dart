import 'package:flutter/widgets.dart';
import '../models/item.dart';

/// AppState — tiny in-memory store used as a cross-screen cache.
///
/// It is intentionally NOT a state-management library so the project
/// stays beginner-friendly for a viva. Screens call
/// `AppStateScope.of(context)` to read the cache and rebuild via
/// `AnimatedBuilder(animation: appState)`.
///
/// The home screen syncs `listings` from Firestore (via the
/// ListingService stream) into this cache so that other screens
/// (item details, my listings, wishlist) can read items by id without
/// re-querying Firestore.
class AppState extends ChangeNotifier {
  /// Wishlist item IDs.
  final Set<String> _wishlist = <String>{};

  /// Live mutable list of listings synced from Firestore.
  /// Starts empty — the home screen fills it from the `listings`
  /// collection on first build. We deliberately do NOT seed it with
  /// any dummy data so only real, user-created listings are shown.
  final List<Item> _listings = <Item>[];

  Set<String> get wishlist => _wishlist;

  List<Item> get listings => List.unmodifiable(_listings);

  /// Set the wishlist contents (used by WishlistService stream).
  void setWishlist(Set<String> ids) {
    _wishlist
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Toggle a single wishlist id (used as an optimistic UI update
  /// before the Firestore write completes).
  void toggleWishlistLocal(String id) {
    if (_wishlist.contains(id)) {
      _wishlist.remove(id);
    } else {
      _wishlist.add(id);
    }
    notifyListeners();
  }

  /// Get an item by id.
  Item? itemById(String id) {
    try {
      return _listings.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// List of items in the current user's wishlist.
  List<Item> get wishlistItems => _listings
      .where((i) => _wishlist.contains(i.id))
      .toList(growable: false);

  /// List of items posted by the current user.
  List<Item> get myListings => _listings
      .where((i) => i.sellerId == _currentUserId)
      .toList(growable: false);

  // The Firebase Auth UID of the currently signed-in user. Updated by
  // HomeScreen whenever the auth user changes.
  String _currentUserId = '';
  String get currentUserId => _currentUserId;

  void setCurrentUserId(String uid) {
    if (_currentUserId == uid) return;
    _currentUserId = uid;
    notifyListeners();
  }

  // Track the current user's display name (read from Firestore profile).
  String _currentUserName = '';
  String get currentUserName => _currentUserName;

  void setCurrentUserName(String name) {
    if (_currentUserName == name) return;
    _currentUserName = name;
    notifyListeners();
  }

  bool isWishlisted(String id) => _wishlist.contains(id);

  /// Add a brand-new listing. Generates a simple unique id.
  void addListing(Item item) {
    _listings.insert(0, item);
    notifyListeners();
  }

  /// Replaces the full listings list (used to sync Firestore + dummy).
  void replaceListings(List<Item> items) {
    _listings
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  /// Delete by id — used by My Listings.
  void deleteListing(String id) {
    _listings.removeWhere((i) => i.id == id);
    _wishlist.remove(id);
    notifyListeners();
  }
}

/// AppStateScope — a tiny InheritedWidget so any screen can look up AppState
/// without an external package. Because AppState is a ChangeNotifier, we listen
/// to it in each screen via `AnimatedBuilder(animation: AppStateScope.of(ctx))`.
class AppStateScope extends InheritedWidget {
  final AppState appState;

  const AppStateScope({
    super.key,
    required this.appState,
    required super.child,
  });

  /// Lookup without registering a dependency — we rebuild via AnimatedBuilder.
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
