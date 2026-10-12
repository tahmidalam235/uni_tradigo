import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../data/dummy_data.dart';
import '../models/item.dart';
import '../widgets/item_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'item_details_screen.dart';
import 'wishlist_screen.dart';
import 'add_listing_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'wanted_posts_screen.dart';
import '../services/listing_service.dart';
import '../services/wishlist_service.dart';
import '../services/user_service.dart';

/// HomeScreen — bottom-nav host with 5 tabs:
///   Home (marketplace), Wishlist, Add, Messages, Profile.
/// Also exposes a "Wanted Posts" action in the AppBar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    const _MarketplaceTab(),
    const WishlistScreen(embedded: true),
    AddListingScreen(
      embedded: true,
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
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.softShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/uni_tradigo_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _titles[_index],
              style: AppTypography.titleLarge,
            ),
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
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box_rounded),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
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
  String? _selectedCategory;
  String _sort = 'Recent';
  String _condition = '';
  String _tradeType = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final appState = AppStateScope.of(context);
      appState.setCurrentUserId(user.uid);
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
      default:
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
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Filters', style: AppTypography.titleLarge),
                  const SizedBox(height: 16),
                  _filterLabel('Category'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  _filterLabel('Sort by'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  _filterLabel('Condition'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  _filterLabel('Trade Type'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 24),
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

  Widget _filterLabel(String text) {
    return Text(
      text,
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<Item>>(
      stream: _listingService.streamAllListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return ErrorState(
            message:
                'Please check your internet connection.\nDetails: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final firestoreListings = snapshot.data ?? const <Item>[];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          appState.replaceListings(firestoreListings);
        });

        if (user != null) {
          return StreamBuilder<Set<String>>(
            stream: _wishlistService.streamWishlistIds(user.uid),
            builder: (context, wishSnap) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                appState.setWishlist(wishSnap.data ?? <String>{});
              });
              return _buildContent(appState, firestoreListings);
            },
          );
        }

        return _buildContent(appState, firestoreListings);
      },
    );
  }

  Widget _buildContent(AppState appState, List<Item> items) {
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        final filtered = _filtered(items);
        return ListView(
          padding: const EdgeInsets.only(bottom: 100, top: 4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search items…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
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
                    icon: const Icon(Icons.tune_rounded),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  CategoryChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
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
            const SectionHeader(title: 'Featured'),
            if (filtered.isNotEmpty)
              SizedBox(
                height: 160,
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
            const SectionHeader(title: 'Recent listings'),
            if (filtered.isEmpty)
              EmptyState(
                icon: items.isEmpty
                    ? Icons.shopping_bag_outlined
                    : Icons.search_off_rounded,
                title: items.isEmpty
                    ? 'No listings yet'
                    : 'No matches',
                subtitle: items.isEmpty
                    ? 'Be the first to post a listing for your campus.'
                    : 'Try adjusting your search or filters.',
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    for (final item in filtered) ...[
                      ItemCard(
                        item: item,
                        onTap: () => _openDetails(item),
                        isWishlisted: appState.isWishlisted(item.id),
                        onWishlistToggle: () => _toggleWishlist(item.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
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
    appState.toggleWishlistLocal(listingId);
    try {
      if (isWished) {
        await _wishlistService.remove(user.uid, listingId);
      } else {
        await _wishlistService.add(user.uid, listingId);
      }
    } catch (e) {
      if (!mounted) return;
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
        return Icons.menu_book_rounded;
      case 'Electronics':
        return Icons.devices_rounded;
      case 'Calculator':
        return Icons.calculate_rounded;
      case 'Accessories':
        return Icons.lightbulb_outline_rounded;
      case 'Furniture':
        return Icons.chair_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }
}

class _FeaturedTile extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const _FeaturedTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.tradeType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.3,
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
