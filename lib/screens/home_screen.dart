import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../data/dummy_data.dart';
import '../models/item.dart';
import '../widgets/item_card.dart';
import '../widgets/category_chip.dart';
import 'item_details_screen.dart';
import 'wishlist_screen.dart';
import 'add_listing_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'wanted_posts_screen.dart';
import '../services/listing_service.dart';
import '../services/wishlist_service.dart';
import '../services/user_service.dart';

// HomeScreen — bottom-nav host with 5 tabs:
//   Home (marketplace), Wishlist, Add (FAB-style), Messages, Profile.
// Also includes a "Wanted Posts" entry in the AppBar.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Pages indexed by the bottom nav.
  late final List<Widget> _pages = [
    const _MarketplaceTab(),
    const WishlistScreen(embedded: true),
    AddListingScreen(
      embedded: true,
      // After a successful new listing post, switch the bottom-nav back
      // to the marketplace tab so the new item is visible.
      onPosted: () {
        if (mounted) setState(() => _index = 0);
      },
    ),
    const MessagesScreen(embedded: true),
    const ProfileScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Different title per tab.
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/uni_tradigo_logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(_titles[_index]),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wanted Posts',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WantedPostsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  static const _titles = [
    'Uni-Tradigo',
    'My Wishlist',
    'Add Listing',
    'Messages',
    'My Profile',
  ];
}

// ---------------- Marketplace Tab ----------------

class _MarketplaceTab extends StatefulWidget {
  const _MarketplaceTab();

  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _listingService = ListingService();
  final _wishlistService = WishlistService();
  final _userService = UserService();
  String? _selectedCategory; // null = all
  String _sort = 'Recent'; // Recent / PriceLow / PriceHigh
  String _condition = ''; // empty = any
  String _tradeType = ''; // empty = any

  @override
  void initState() {
    super.initState();
    // Set the current user id/name on the AppState so other screens
    // (My Listings, Profile) can read them without re-querying Firebase.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final appState = AppStateScope.of(context);
      appState.setCurrentUserId(user.uid);
      // Best-effort: load the user's display name from their profile doc.
      _userService.getProfile(user.uid).then((profile) {
        if (profile != null) {
          appState.setCurrentUserName(
              (profile['name'] ?? '').toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Returns the listings straight from Firestore.
  /// Dummy data is no longer mixed in — only real user-created listings
  /// are shown in the marketplace.
  List<Item> _combined(List<Item> firestore) => firestore;

  List<Item> _filtered(List<Item> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = all.where((i) {
      if (_selectedCategory != null && i.category != _selectedCategory) {
        return false;
      }
      if (_condition.isNotEmpty && i.condition != _condition) {
        return false;
      }
      if (_tradeType.isNotEmpty && i.tradeType != _tradeType) {
        return false;
      }
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case 'PriceLow':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'PriceHigh':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      default: // Recent
        list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    }
    return list;
  }

  void _openFilters() {
    String? tempCategory = _selectedCategory;
    String tempSort = _sort;
    String tempCondition = _condition;
    String tempTrade = _tradeType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: SizedBox(
                      width: 40,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Category'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempCategory == null,
                        onSelected: (_) => setSheet(() => tempCategory = null),
                      ),
                      for (final c in DummyData.categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: tempCategory == c,
                          onSelected: (_) => setSheet(() => tempCategory = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Sort by'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in const ['Recent', 'PriceLow', 'PriceHigh'])
                        ChoiceChip(
                          label: Text(s == 'PriceLow'
                              ? 'Price: Low to High'
                              : s == 'PriceHigh'
                                  ? 'Price: High to Low'
                                  : 'Recent'),
                          selected: tempSort == s,
                          onSelected: (_) => setSheet(() => tempSort = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Condition'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Any'),
                        selected: tempCondition.isEmpty,
                        onSelected: (_) => setSheet(() => tempCondition = ''),
                      ),
                      for (final c in DummyData.conditions)
                        ChoiceChip(
                          label: Text(c),
                          selected: tempCondition == c,
                          onSelected: (_) => setSheet(() => tempCondition = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Trade Type'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Any'),
                        selected: tempTrade.isEmpty,
                        onSelected: (_) => setSheet(() => tempTrade = ''),
                      ),
                      for (final t in DummyData.tradeTypes)
                        ChoiceChip(
                          label: Text(t),
                          selected: tempTrade == t,
                          onSelected: (_) => setSheet(() => tempTrade = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheet(() {
                              tempCategory = null;
                              tempSort = 'Recent';
                              tempCondition = '';
                              tempTrade = '';
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _sort = tempSort;
                              _condition = tempCondition;
                              _tradeType = tempTrade;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<Item>>(
      stream: _listingService.streamAllListings(),
      builder: (context, snapshot) {
        // 1) Error state: surface it with a friendly message.
        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load listings.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please check your internet connection.\n'
                    'Details: ${snapshot.error}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // 2) Loading: show a spinner on the very first build.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 3) Loaded: use the Firestore data directly.
        final firestoreListings = snapshot.data ?? const <Item>[];
        final combinedForState = _combined(firestoreListings);

        // Keep AppState's internal _listings up-to-date so other
        // screens that read from appState.listings (item details,
        // wishlist) see the same data.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          appState.replaceListings(combinedForState);
        });

        // Stream the user's wishlist ids into AppState so the heart
        // icons everywhere stay in sync with Firestore.
        if (user != null) {
          return StreamBuilder<Set<String>>(
            stream: _wishlistService.streamWishlistIds(user.uid),
            builder: (context, wishSnap) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                appState.setWishlist(wishSnap.data ?? <String>{});
              });
              return _buildContent(appState, combinedForState);
            },
          );
        }

        return _buildContent(appState, combinedForState);
      },
    );
  }

  Widget _buildContent(AppState appState, List<Item> combinedForState) {
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        final filtered = _filtered(combinedForState);
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Search bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            // Category strip.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  CategoryChip(
                    label: 'All',
                    icon: Icons.apps,
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: 8),
                  for (final c in DummyData.categories) ...[
                    CategoryChip(
                      label: c,
                      icon: _iconFor(c),
                      selected: _selectedCategory == c,
                      onTap: () => setState(() => _selectedCategory = c),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            // Featured header.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Featured Listings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (filtered.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length < 3 ? filtered.length : 3,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return _FeaturedTile(
                      item: item,
                      onTap: () => _openDetails(item),
                    );
                  },
                ),
              ),
            // Recent header.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Recent Listings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    combinedForState.isEmpty
                        ? 'No listings yet.\nBe the first to post one!'
                        : 'No items match your search.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final item in filtered)
                ItemCard(
                  item: item,
                  onTap: () => _openDetails(item),
                  isWishlisted: appState.isWishlisted(item.id),
                  onWishlistToggle: () => _toggleWishlist(item.id),
                ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Future<void> _toggleWishlist(String listingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final appState = AppStateScope.of(context);
    final isWished = appState.isWishlisted(listingId);
    // Optimistic UI update
    appState.toggleWishlistLocal(listingId);
    try {
      if (isWished) {
        await _wishlistService.remove(user.uid, listingId);
      } else {
        await _wishlistService.add(user.uid, listingId);
      }
    } catch (e) {
      if (!mounted) return;
      // Revert on failure
      appState.toggleWishlistLocal(listingId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update wishlist: $e')),
      );
    }
  }

  void _openDetails(Item item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemDetailsScreen(itemId: item.id)),
    );
  }

  IconData _iconFor(String cat) {
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
}

class _FeaturedTile extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const _FeaturedTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.tradeType,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                    const Icon(Icons.verified, color: Colors.white, size: 18),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}