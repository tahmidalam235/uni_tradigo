import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../data/app_state.dart';
import '../data/dummy_data.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/busy_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/section_header.dart';
import '../services/listing_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

// AddListingScreen — form for creating a new listing.
// Persists to Firestore via ListingService. The selected image is
// converted to a Base64 data URL and stored directly inside the listing
// document so we don't need Firebase Storage (works on the free Spark plan).
//
// When embedded=true, the screen renders without its own AppBar because
// it's a tab inside HomeScreen.

class AddListingScreen extends StatefulWidget {
  final bool embedded;
  final Item? editItem;

  /// Called when a new (non-edit) listing finishes uploading to Firestore.
  /// The Home screen wires this so that the embedded Add Listing tab can
  /// jump the bottom-nav back to the marketplace tab after a successful
  /// post. Optional — if null, the screen falls back to popping the route.
  final VoidCallback? onPosted;

  const AddListingScreen({
    super.key,
    this.embedded = false,
    this.editItem,
    this.onPosted,
  });

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listingService = ListingService();
  final _storageService = StorageService();
  final _userService = UserService();
  final _picker = ImagePicker();

  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _pickup;
  late String _category;
  late String _condition;
  late String _tradeType;

  // Selected image file (local file path) and current upload progress flag.
  File? _selectedImage;
  bool _busy = false;

  // For edits: keep the previous imageUrl so we can keep the existing
  // uploaded image when the user does not pick a new one.
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _price =
        TextEditingController(text: e == null ? '' : (e.price <= 0 ? '' : e.price.toStringAsFixed(0)));
    _pickup = TextEditingController(text: e?.pickupLocation ?? 'BUP Campus');
    _category = e?.category ?? DummyData.categories.first;
    _condition = e?.condition ?? DummyData.conditions.first;
    _tradeType = e?.tradeType ?? DummyData.tradeTypes.first;
    _existingImageUrl = (e?.imageUrl != null && e!.imageUrl.isNotEmpty)
        ? e.imageUrl
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _pickup.dispose();
    super.dispose();
  }

  // Pick an image from the device gallery.
  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _selectedImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  // Remove the currently selected image (only clears the local selection,
  // not a previously uploaded image).
  void _removeImage() {
    setState(() => _selectedImage = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;

    final priceText = _price.text.trim();
    final priceVal = priceText.isEmpty
        ? (_tradeType == 'Donation' ? 0.0 : null)
        : double.tryParse(priceText);
    if (_tradeType != 'Donation' && (priceVal == null || priceVal < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    // Identify the current Firebase user — required for sellerId.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to post a listing.'),
        ),
      );
      return;
    }

    // Look up the user's display name from their profile document if we
    // don't already have one in the form.
    String sellerName = '';
    String sellerEmail = user.email ?? '';
    try {
      final profile = await _userService.getProfile(user.uid);
      if (profile != null) {
        sellerName = (profile['name'] ?? '').toString();
        sellerEmail = (profile['email'] ?? sellerEmail).toString();
      }
    } catch (_) {
      // If we can't read the profile, fall back to FirebaseAuth info.
    }

    setState(() => _busy = true);

    try {
      // 1. Convert the picked image into a Base64 data URL (stored inside
      //    the Firestore document so we don't need Firebase Storage).
      //    If encoding fails, post without an image rather than blocking.
      String? imageUrl = _existingImageUrl;
      bool imageUploadFailed = false;
      if (_selectedImage != null) {
        final encoded = await _storageService.encodeImageAsBase64(
          _selectedImage!,
        );
        if (encoded == null) {
          imageUploadFailed = true;
          imageUrl = '';
        } else {
          imageUrl = encoded;
        }
      }

      // 2. Build the Item and persist it.
      final edit = widget.editItem;
      Item newItem = Item(
        id: edit?.id ?? '',
        title: _title.text.trim(),
        description: _desc.text.trim(),
        price: _tradeType == 'Donation' ? 0 : (priceVal ?? 0),
        category: _category,
        condition: _condition,
        tradeType: _tradeType,
        imageUrl: imageUrl ?? '',
        sellerName: sellerName,
        sellerEmail: sellerEmail,
        sellerId: user.uid,
        pickupLocation: _pickup.text.trim(),
        isAvailable: edit?.isAvailable ?? true,
        postedAt: edit?.postedAt ?? DateTime.now(),
      );

      if (edit != null && edit.id.isNotEmpty) {
        // Update the existing Firestore document.
        await _listingService.updateListing(newItem);
      } else {
        // Create a brand-new Firestore document.
        final newId = await _listingService.createListing(newItem);
        newItem = Item(
          id: newId,
          title: newItem.title,
          description: newItem.description,
          price: newItem.price,
          category: newItem.category,
          condition: newItem.condition,
          tradeType: newItem.tradeType,
          imageUrl: newItem.imageUrl,
          sellerName: newItem.sellerName,
          sellerEmail: newItem.sellerEmail,
          sellerId: newItem.sellerId,
          pickupLocation: newItem.pickupLocation,
          isAvailable: newItem.isAvailable,
          postedAt: newItem.postedAt,
        );
      }

      // Keep the in-memory AppState cache in sync so other screens that
      // already read from AppState reflect the new listing immediately.
      final appState = AppStateScope.of(context);
      if (edit != null) {
        appState.deleteListing(edit.id);
      }
      appState.addListing(newItem);

      if (!context.mounted) return;

      // If image encoding failed, surface it but still show success.
      if (imageUploadFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Listing posted, but the image could not be read. '
              'Try picking it again.',
            ),
          ),
        );
      }

      // Post-upload navigation:
      //   - embedded tab in HomeScreen: ask the parent to switch the
      //     bottom-nav back to the marketplace tab so the new listing
      //     is visible.
      //   - pushed route (e.g. from MyListings): pop the entire stack
      //     back to the root (HomeScreen) so the user lands on the
      //     marketplace.
      //   - edit case: do nothing — just close the screen.
      if (edit == null) {
        if (widget.onPosted != null) {
          widget.onPosted!();
        } else if (mounted) {
          // Standalone route — pop everything down to the root
          // (HomeScreen) so the user lands on the marketplace.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Listing Updated'),
            content:
                const Text('Your listing has been updated successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (!widget.embedded) Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Show the actual error message so it's easy to debug from the UI
      // without needing to open logcat.
      String message = e.toString();
      if (message.toLowerCase().contains('socketexception') ||
          message.toLowerCase().contains('network') ||
          message.toLowerCase().contains('failed host lookup')) {
        message = 'Unable to post listing. Please check your internet connection.';
      } else if (message.toLowerCase().contains('permission')) {
        message =
            'Post denied by Firestore rules. Please publish the firestore.rules file in Firebase Console.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            CustomTextField(
              label: 'Item Title',
              controller: _title,
              prefixIcon: Icons.title_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              label: 'Description',
              controller: _desc,
              maxLines: 3,
              prefixIcon: Icons.notes_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              label: 'Price (Taka) — 0 or empty for Donation',
              controller: _price,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
              validator: (v) {
                if (_tradeType == 'Donation') return null;
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _dropdown('Category', _category, Icons.category_outlined,
                DummyData.categories, (v) {
              setState(() => _category = v!);
            }),
            const SizedBox(height: AppSpacing.md),
            _dropdown('Condition', _condition, Icons.verified_outlined,
                DummyData.conditions, (v) {
              setState(() => _condition = v!);
            }),
            const SizedBox(height: AppSpacing.md),
            _dropdown('Trade Type', _tradeType, Icons.swap_horiz_rounded,
                DummyData.tradeTypes, (v) {
              setState(() => _tradeType = v!);
            }),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              label: 'Campus Pickup Location',
              controller: _pickup,
              prefixIcon: Icons.location_on_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Image picker area -----
            _buildImagePicker(),

            const SizedBox(height: AppSpacing.xl),
            BusyButton(
              onPressed: _busy ? null : _submit,
              busy: _busy,
              label: widget.editItem == null
                  ? 'Post Listing'
                  : 'Update Listing',
              icon: Icons.send_rounded,
              expand: true,
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return widget.editItem == null
          ? Column(
              children: [
                const SectionHeader(
                  title: 'Post a new listing',
                ),
                Expanded(child: body),
              ],
            )
          : body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.editItem == null ? 'Add Listing' : 'Edit Listing'),
      ),
      body: body,
    );
  }

  // Image picker UI: shows a preview of the selected image (or existing
  // uploaded image) and lets the user pick/change/remove it.
  Widget _buildImagePicker() {
    // Show the newly-selected local file first.
    if (_selectedImage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Selected Image',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Change'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: _busy ? null : _removeImage,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                label: const Text(
                  'Remove',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // No new selection — show existing uploaded image (edit mode) if any.
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Current Image',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildExistingImage(),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Change Image'),
          ),
        ],
      );
    }

    // No image yet.
    return InkWell(
      onTap: _busy ? null : _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outline,
            style: BorderStyle.solid,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a cover image',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Optional, but helps the listing stand out',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingImage() {
    final url = _existingImageUrl!;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageErrorIcon(),
        );
      } catch (e) {
        return _imageErrorIcon();
      }
    }
    return Image.network(
      url,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imageErrorIcon(),
    );
  }

  Widget _imageErrorIcon() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.broken_image_outlined, size: 40),
    );
  }

  Widget _dropdown(String label, String value, IconData icon,
      List<String> items, ValueChanged<String?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final v in items)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
