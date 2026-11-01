import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

/// ChatScreen — real-time chat with another student.
///
/// Opens immediately when pushed, showing the peer's name in the
/// AppBar. The conversation is initialized lazily inside the screen
/// (idempotent — reopens the existing conversation if any, otherwise
/// creates a new one), then messages stream in live.
///
/// To open a chat, just `Navigator.push` this screen with `peerUid`
/// and `peerName`. The screen resolves everything else itself, so the
/// caller never has to wait on an async Firestore write before
/// navigating.
class ChatScreen extends StatefulWidget {
  final String peerName;
  final String peerEmail;
  final String peerUid;

  /// Optional pre-computed conversation id. If null, the screen will
  /// derive the id from the two sorted uids (the same derivation the
  /// service uses), so the screen always reopens the right
  /// conversation.
  final String? conversationId;

  const ChatScreen({
    super.key,
    required this.peerName,
    required this.peerEmail,
    required this.peerUid,
    this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final _chat = ChatService();
  final _userService = UserService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  bool _sending = false;
  String? _conversationId;
  String? _initError;

  /// True while an image is being picked / encoded / uploaded. The
  /// attach button and the send button are disabled during this time.
  bool _uploadingImage = false;

  /// 0.0 – 1.0 progress of the current image upload, or null when no
  /// upload is running. Drives the determinate progress indicator.
  double? _uploadProgress;

  /// Peer display name resolved from the Firebase user profile
  /// (`users/{peerUid}`). The widget's `peerName` is used as the initial
  /// value so the header renders instantly, then refined from Firestore
  /// when the profile loads (the Messages list passes an empty email and
  /// sometimes a stale/blank name).
  String _peerName = '';

  /// Peer email resolved from the same profile document.
  String _peerEmail = '';

  /// Peer department (e.g. "CSE"), shown under the name when known.
  String _peerDepartment = '';

  @override
  void initState() {
    super.initState();
    // If the caller already passed a conversationId, use it. Otherwise
    // compute the deterministic id from the sorted uids so this screen
    // always reopens the same conversation between the two users.
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _conversationId = widget.conversationId ??
        (myUid.isNotEmpty && widget.peerUid.isNotEmpty
            ? _chat.conversationIdFor(myUid, widget.peerUid)
            : null);
    // Start from the caller-supplied values so the header is never blank
    // while the profile read is in flight.
    _peerName = widget.peerName.trim();
    _peerEmail = widget.peerEmail.trim();
    // Kick off the idempotent conversation initialization in the
    // background. The screen renders immediately; messages will stream
    // in once the conversation exists.
    if (_conversationId != null && myUid.isNotEmpty) {
      _ensureConversation();
      _loadPeerProfile();
    } else {
      _initError = 'Cannot open chat: missing user or peer id.';
    }
  }

  /// Reads the peer's profile document (`users/{peerUid}`) so the header
  /// shows the real display name and contact details. Purely a display
  /// lookup — it does not touch the conversation or message logic.
  Future<void> _loadPeerProfile() async {
    final peerUid = widget.peerUid;
    if (peerUid.isEmpty) return;
    try {
      final profile = await _userService.getProfile(peerUid);
      if (profile == null || !mounted) return;
      final name = (profile['name'] ?? '').toString().trim();
      final email = (profile['email'] ?? '').toString().trim();
      final department = (profile['department'] ?? '').toString().trim();
      // Only overwrite when Firestore actually has a value — never blank
      // out a name the caller already supplied.
      if (name.isEmpty && email.isEmpty && department.isEmpty) return;
      setState(() {
        if (name.isNotEmpty) _peerName = name;
        if (email.isNotEmpty) _peerEmail = email;
        if (department.isNotEmpty) _peerDepartment = department;
      });
    } catch (_) {
      // Non-critical: keep whatever the caller supplied. The header stays
      // visible even if the profile read fails.
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureConversation() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty || widget.peerUid.isEmpty) return;
    try {
      String myName = '';
      final profile =
          await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (profile.exists) {
        myName = (profile.data()?['name'] ?? '').toString();
      }
      final id = await _chat.ensureConversation(
        myUid: myUid,
        myName: myName,
        otherUid: widget.peerUid,
        otherName: widget.peerName,
      );
      if (!mounted) return;
      setState(() => _conversationId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final convoId = _conversationId;
    if (convoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening chat… try again in a moment.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      String myName = '';
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (profile.exists) {
        myName = (profile.data()?['name'] ?? '').toString();
      }
      await _chat.sendMessage(
        conversationId: convoId,
        senderId: user.uid,
        senderName: myName,
        text: text,
      );
      _ctrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Opens the device gallery so the user can pick an image to send.
  ///
  /// The picked image is downscaled by the picker itself (max 1280px,
  /// JPEG quality 82) which keeps the Base64 payload small enough for a
  /// Firestore document — the same approach the listing images use.
  Future<void> _pickAndSendImage() async {
    if (_uploadingImage || _sending) return;
    final convoId = _conversationId;
    if (convoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening chat… try again in a moment.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1280,
        maxHeight: 1280,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
      return;
    }
    // The user dismissed the gallery picker.
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _uploadingImage = true;
      _uploadProgress = 0.0;
    });

    try {
      // Encode the picked file into a Base64 data URL. This is the same
      // storage strategy the listing images use, so no Firebase Storage
      // bucket is required.
      final encoded = await _storageService.encodeImageAsBase64(
        File(picked.path),
      );
      if (encoded == null) {
        throw StateError('Could not read the selected image.');
      }
      if (!mounted) return;
      setState(() => _uploadProgress = 0.6);

      // Resolve the sender's display name for the message envelope.
      String myName = '';
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (profile.exists) {
        myName = (profile.data()?['name'] ?? '').toString();
      }
      if (!mounted) return;
      setState(() => _uploadProgress = 0.85);

      // Any text already typed is sent along with the image so the user
      // can add a caption in one go.
      final caption = _ctrl.text.trim();

      await _chat.sendMessage(
        conversationId: convoId,
        senderId: user.uid,
        senderName: myName,
        text: caption,
        imageUrl: encoded,
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() => _uploadProgress = 1.0);

      // Scroll to the newly sent image, exactly like a text message.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message
                : 'Could not send image: $e',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _pickAndSendImage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _uploadProgress = null;
        });
      }
    }
  }

  /// Human-readable label for the current upload progress, e.g.
  /// "Uploading… 60%".
  String _uploadProgressLabel() {
    final p = _uploadProgress;
    if (p == null) return 'Uploading…';
    if (p >= 1) return 'Sending…';
    return 'Uploading… ${(p * 100).round()}%';
  }

  /// Builds the secondary line under the peer's name. Prefers the email
  /// (a unique identifier for the student) and falls back to the
  /// department when the email is not available. When both are known the
  /// department is appended so the header carries more context without
  /// becoming cluttered.
  String _peerSubtitle() {
    if (_peerEmail.isNotEmpty && _peerDepartment.isNotEmpty) {
      return '$_peerEmail  •  $_peerDepartment';
    }
    if (_peerEmail.isNotEmpty) return _peerEmail;
    if (_peerDepartment.isNotEmpty) return _peerDepartment;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';
    final convoId = _conversationId;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // The app's global AppBarTheme uses a LIGHT surface background
        // (AppColors.surface). The header text therefore has to use the
        // dark theme text colors — hard-coding white here made the peer's
        // name invisible (white on white).
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.outline,
        title: Row(
          children: [
            UserAvatar(
              name: _peerName,
              radius: 18,
              color: Theme.of(context).colorScheme.primary,
              textColor: Colors.white,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _peerName.isEmpty ? 'Chat' : _peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14),
                    ],
                  ),
                  if (_peerEmail.isNotEmpty || _peerDepartment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        _peerSubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _initError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_initError!, textAlign: TextAlign.center),
              ),
            )
          : convoId == null || myUid.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<ChatMsg>>(
                  stream: _chat.streamMessagesFor(myUid, convoId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Could not load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? const <ChatMsg>[];
                    return Column(
                      children: [
                        Expanded(
                          child: messages.isEmpty
                              ? Center(
                                  child: Text(
                                    'Say hello!',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: messages.length,
                                  itemBuilder: (_, i) {
                                    final m = messages[i];
                                    final isMe = user != null &&
                                        m.senderId == user.uid;
                                    return _MessageBubble(
                                        message: m, isMe: isMe);
                                  },
                                ),
                        ),
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Upload progress strip shown while an
                                // image is being encoded and sent.
                                if (_uploadingImage)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: _uploadProgress,
                                              minHeight: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _uploadProgressLabel(),
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    // Attach-image button, placed just before
                                    // the text field.
                                    _AttachButton(
                                      uploading: _uploadingImage,
                                      progress: _uploadProgress,
                                      enabled: !_sending && !_uploadingImage,
                                      onPressed: _pickAndSendImage,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TextField(
                                        controller: _ctrl,
                                        decoration: InputDecoration(
                                          hintText: 'Message',
                                          fillColor: AppColors.surfaceMuted,
                                          filled: true,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 1.4,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 10),
                                        ),
                                        onSubmitted: (_) => _send(),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton.filled(
                                      onPressed: _sending ? null : _send,
                                      icon: _sending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.send_rounded),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMsg message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? scheme.primary : AppColors.surfaceMuted;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final hasImage = message.hasImage;
    final hasText = message.text.trim().isNotEmpty;

    // An image-only message gets a tighter padding around the picture;
    // a text message keeps the original bubble padding.
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              _ChatImage(
                url: message.imageUrl,
                isMe: isMe,
                maxWidth: MediaQuery.of(context).size.width * 0.70,
              ),
            if (hasImage && hasText) const SizedBox(height: 6),
            if (hasText)
              Padding(
                // Inside an image bubble the text sits on the bubble
                // background, so it keeps the bubble's text colour.
                padding: hasImage
                    ? const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2)
                    : EdgeInsets.zero,
                child: Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// _ChatImage — renders a chat attachment.
///
/// Supports both the Base64 data URLs this app stores in Firestore and
/// plain http(s) URLs, mirroring the image handling used by the listing
/// cards. Falls back to a "broken image" placeholder when the image
/// cannot be decoded.
class _ChatImage extends StatelessWidget {
  final String url;
  final bool isMe;
  final double maxWidth;

  const _ChatImage({
    required this.url,
    required this.isMe,
    required this.maxWidth,
  });

  Widget _placeholder(BuildContext context) {
    return Container(
      height: 150,
      width: maxWidth,
      alignment: Alignment.center,
      color: isMe
          ? Colors.white.withValues(alpha: 0.18)
          : AppColors.surfaceContainer,
      child: Icon(
        Icons.broken_image_outlined,
        size: 32,
        color: isMe ? Colors.white70 : AppColors.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('data:image')
        ? _decodeDataUrl(context)
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(context),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 150,
                width: maxWidth,
                alignment: Alignment.center,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.surfaceContainer,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              );
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 260),
        child: image,
      ),
    );
  }

  /// Decodes a `data:image/...;base64,...` payload into bytes and renders
  /// it with `Image.memory`.
  Widget _decodeDataUrl(BuildContext context) {
    try {
      final base64String = url.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
        gaplessPlayback: true,
      );
    } catch (_) {
      return _placeholder(context);
    }
  }
}

/// _AttachButton — the paperclip / image button that sits next to the
/// message input. While an upload is running it shows a determinate
/// progress ring instead of the icon.
class _AttachButton extends StatelessWidget {
  final bool uploading;
  final double? progress;
  final bool enabled;
  final VoidCallback onPressed;

  const _AttachButton({
    required this.uploading,
    required this.progress,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (uploading) {
      final value = progress;
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2.4,
                backgroundColor: AppColors.surfaceMuted,
              ),
            ),
          ],
        ),
      );
    }
    return IconButton(
      tooltip: 'Send an image',
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        Icons.add_photo_alternate_outlined,
        color: enabled ? scheme.primary : AppColors.textMuted,
      ),
    );
  }
}