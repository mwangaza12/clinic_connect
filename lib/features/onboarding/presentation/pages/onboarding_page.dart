// lib/features/onboarding/presentation/pages/onboarding_page.dart
//
// 4-slide onboarding shown exactly once on first install.
// After "Get Started" taps → marks hasSeenOnboarding = true → goes to AuthWrapper.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';

// ── Data model for each slide ────────────────────────────────────────────────
class _OnboardSlide {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String tag;       // small label above title e.g. "OFFLINE FIRST"
  final String title;
  final String body;
  final List<Color> gradientColors;

  const _OnboardSlide({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.tag,
    required this.title,
    required this.body,
    required this.gradientColors,
  });
}

const _slides = [
  _OnboardSlide(
    icon: Icons.person_add_alt_1_rounded,
    iconBg: Color(0xFFDEF7EC),
    iconColor: Color(0xFF2D6A4F),
    tag: 'PATIENT IDENTITY',
    title: 'One Patient,\nOne Identity',
    body:
        'Every patient is registered with a National Unique Patient Identifier (NUPI), '
        'ensuring accurate identity across every health facility in Kenya — no duplicates, no mix-ups.',
    gradientColors: [Color(0xFF1A3C2E), Color(0xFF0F2419)],
  ),
  _OnboardSlide(
    icon: Icons.wifi_off_rounded,
    iconBg: Color(0xFFFFF7ED),
    iconColor: Color(0xFFF59E0B),
    tag: 'OFFLINE FIRST',
    title: 'Works Without\nthe Internet',
    body:
        'All records are saved locally on the device first. '
        'When connectivity returns, everything syncs automatically to the cloud — '
        'no data is ever lost during outages.',
    gradientColors: [Color(0xFF2D1F00), Color(0xFF1A1200)],
  ),
  _OnboardSlide(
    icon: Icons.swap_horiz_rounded,
    iconBg: Color(0xFFEFF6FF),
    iconColor: Color(0xFF2563EB),
    tag: 'REFERRALS',
    title: 'Seamless\nFacility Referrals',
    body:
        'Send a patient to another facility in seconds. '
        'The receiving team is notified instantly, '
        'and you can track every step — accepted, in transit, arrived — in real time.',
    gradientColors: [Color(0xFF0D1F3C), Color(0xFF060E1E)],
  ),
  _OnboardSlide(
    icon: Icons.verified_user_rounded,
    iconBg: Color(0xFFF0FDF4),
    iconColor: Color(0xFF059669),
    tag: 'HL7 FHIR R4',
    title: 'Built for\nInteroperability',
    body:
        'All clinical data is structured using international HL7 FHIR R4 standards. '
        'ClinicConnect is designed to connect with KenyaEMR, DHIS2, and national health '
        'systems as the ecosystem grows.',
    gradientColors: [Color(0xFF022C22), Color(0xFF011A15)],
  ),
];

// ── Main onboarding widget ───────────────────────────────────────────────────
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Per-slide enter animations
  late final List<AnimationController> _slideControllers;
  late final List<Animation<double>> _iconScales;
  late final List<Animation<double>> _contentOpacities;
  late final List<Animation<Offset>> _contentSlides;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _slideControllers = List.generate(
      _slides.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _iconScales = _slideControllers.map((c) {
      return Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.elasticOut),
      );
    }).toList();

    _contentOpacities = _slideControllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: c,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        ),
      );
    }).toList();

    _contentSlides = _slideControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: c,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    }).toList();

    // Animate first slide in immediately
    _slideControllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _slideControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _slideControllers[page].forward(from: 0);
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    const storage = FlutterSecureStorage();
    await storage.write(
      key: StorageKeys.hasSeenOnboarding,
      value: 'true',
    );
    if (!mounted) return;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Pop back to the root Navigator — AuthWrapper will take over
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background gradient ───────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _slides[_currentPage].gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Background decorative dots grid ────────────────────
          const _DotsGrid(),

          // ── Page content ───────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (_, i) =>
                _SlidePage(
                  slide: _slides[i],
                  iconScale: _iconScales[i],
                  contentOpacity: _contentOpacities[i],
                  contentSlide: _contentSlides[i],
                ),
          ),

          // ── Top skip button ────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page counter
                  Text(
                    '${_currentPage + 1} / ${_slides.length}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom controls ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(
              currentPage: _currentPage,
              totalPages: _slides.length,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual slide content ─────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _OnboardSlide slide;
  final Animation<double> iconScale;
  final Animation<double> contentOpacity;
  final Animation<Offset> contentSlide;

  const _SlidePage({
    required this.slide,
    required this.iconScale,
    required this.contentOpacity,
    required this.contentSlide,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 1),

            // Icon card
            AnimatedBuilder(
              animation: iconScale,
              builder: (_, __) => Transform.scale(
                scale: iconScale.value,
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: slide.iconBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: slide.iconColor.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(slide.icon, size: 44, color: slide.iconColor),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Tag + title + body
            AnimatedBuilder(
              animation: contentOpacity,
              builder: (_, __) => FadeTransition(
                opacity: contentOpacity,
                child: SlideTransition(
                  position: contentSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Feature tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: slide.iconColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: slide.iconColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          slide.tag,
                          style: TextStyle(
                            color: slide.iconColor.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        slide.title,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Body
                      Text(
                        slide.body,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar: dots + next/get-started button ───────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == totalPages - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
        ),
      ),
      child: Row(
        children: [
          // Page indicator dots
          Row(
            children: List.generate(totalPages, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 6),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF52B788)
                      : Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const Spacer(),

          // Next / Get Started button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF52B788),
                foregroundColor: const Color(0xFF022C22),
                padding: EdgeInsets.symmetric(
                  horizontal: isLast ? 28 : 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isLast ? 18 : 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subtle dot-grid background decoration ───────────────────────────────────
class _DotsGrid extends StatelessWidget {
  const _DotsGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotsPainter(),
      size: MediaQuery.of(context).size,
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const dotRadius = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}