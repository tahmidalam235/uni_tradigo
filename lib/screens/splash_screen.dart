import 'package:flutter/material.dart';

/// SplashScreen — shows the Uni-Tradigo logo and campus marketplace
/// branding with smooth animations while auth state resolves.
///
/// Note: Navigation is handled by `_AuthGate` in main.dart, so this screen
/// handles strictly UI presentation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF0B6B4F);
    const brandGreenDark = Color(0xFF0A4D3C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F9F5), Color(0xFFE5F3EC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Ambient soft glowing radial orb (top-right)
            Positioned(
              top: -90,
              right: -90,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.12),
                      const Color(0xFF0B6B4F).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Ambient soft glowing radial orb (bottom-left)
            Positioned(
              bottom: -100,
              left: -90,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0B6B4F).withValues(alpha: 0.10),
                      const Color(0xFF0A4D3C).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Top accent brand bar line
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0A4D3C),
                      Color(0xFF0B6B4F),
                      Color(0xFF10B981),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),

                            // Center Logo & Hero Badge section
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Card container displaying Uni-Tradigo logo
                                      //
                                      // The logo asset has been trimmed to its
                                      // exact artwork bounds (1035x954), so
                                      // the image *is* the artwork with no
                                      // dead white margin. The card sizes
                                      // itself to the logo's real 1.085:1
                                      // proportions and the image is given
                                      // an explicit width with
                                      // BoxFit.contain, which scales the
                                      // whole logo down to fit rather than
                                      // letting it overflow and get clipped
                                      // by the card.
                                      Container(
                                        width: 300,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: brandGreen.withValues(
                                              alpha: 0.08,
                                            ),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: brandGreenDark.withValues(
                                                alpha: 0.09,
                                              ),
                                              blurRadius: 36,
                                              offset: const Offset(0, 14),
                                              spreadRadius: 2,
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Image.asset(
                                          'assets/images/uni_tradigo_logo.png',
                                          width: 258,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                      const SizedBox(height: 28),

                                      // Verified Campus Marketplace Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: brandGreen.withValues(
                                            alpha: 0.07,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: brandGreen.withValues(
                                              alpha: 0.15,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified_user_rounded,
                                              size: 15,
                                              color: brandGreen,
                                            ),
                                            const SizedBox(width: 6),
                                            // Flexible + FittedBox so the badge
                                            // scales down on narrow screens
                                            // instead of overflowing the row.
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment:
                                                    Alignment.centerLeft,
                                                child: const Text(
                                                  'VERIFIED CAMPUS MARKETPLACE',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.1,
                                                    color: brandGreenDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Footer Progress & Status
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      color: brandGreen,
                                      strokeWidth: 2.8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Connecting to Campus Network...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: brandGreenDark.withValues(
                                        alpha: 0.65,
                                      ),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
