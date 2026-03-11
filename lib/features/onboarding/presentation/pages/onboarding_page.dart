import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _primary = Color(0xFF2D6A4F); // Forest Green
const _accent  = Color(0xFFEBF5F0); // Soft Mint for the top stage
const _dark    = Color(0xFF0F172A); // Slate
const _muted   = Color(0xFF64748B); // Gray
const _white   = Color(0xFFFFFFFF);

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _animCtrl.reset();
    _animCtrl.forward();
  }

  Future<void> _finish() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: StorageKeys.hasSeenOnboarding, value: 'true');
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            // ─── BACKGROUND STAGE ───────────────────────────────────────────
            // This removes the "too white" look by coloring the top half
            Container(
              height: screenHeight * 0.45,
              decoration: const BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
            ),

            // ─── MAIN CONTENT ───────────────────────────────────────────────
            PageView.builder(
              controller: _pageCtrl,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, i) => _OnboardSlide(
                slide: _slides[i],
                fade: _fade,
                slideAnim: _slide,
              ),
            ),

            // ─── NAVIGATION (Centered Dots & Right Button) ──────────────────
            Positioned(
              bottom: 40,
              left: 30,
              right: 30,
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dots at Bottom Center
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) => _buildDot(i)),
                      ),
                      
                      // Compact Action Button at Bottom Right
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildSmallButton(isLast),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    bool active = index == _page;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: active ? 20 : 6,
      decoration: BoxDecoration(
        color: active ? _primary : _primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildSmallButton(bool isLast) {
    return GestureDetector(
      onTap: () {
        if (isLast) {
          _finish();
        } else {
          _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: isLast ? 20 : 14),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLast) ...[
              const Text('Get Started', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  final _Slide slide;
  final Animation<double> fade;
  final Animation<Offset> slideAnim;

  const _OnboardSlide({required this.slide, required this.fade, required this.slideAnim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          children: [
            // Pulls image into the colored stage area
            SizedBox(height: constraints.maxHeight * 0.12),
            
            FadeTransition(
              opacity: fade,
              child: SvgPicture.asset(
                slide.asset, 
                height: constraints.maxHeight * 0.32,
                fit: BoxFit.contain,
              ),
            ),
            
            SizedBox(height: constraints.maxHeight * 0.1),
            
            FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slideAnim,
                child: Column(
                  children: [
                    Text(
                      slide.eyebrow, 
                      style: const TextStyle(
                        color: _primary, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1.2, 
                        fontSize: 11
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25, 
                        fontWeight: FontWeight.w900, 
                        color: _dark, 
                        height: 1.2
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14, 
                        color: _muted, 
                        height: 1.5
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120), // Clearance for the bottom controls
          ],
        );
      },
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────
class _Slide {
  final String asset;
  final String eyebrow;
  final String headline;
  final String body;
  const _Slide({required this.asset, required this.eyebrow, required this.headline, required this.body});
}

const _slides = [
  _Slide(
    asset: 'assets/svg/medical_care.svg',
    eyebrow: 'PATIENT IDENTITY',
    headline: 'One record.\nFollows them everywhere.',
    body: 'A National Unique Patient Identifier (NUPI) links every visit, eliminating duplicates across Kenya.',
  ),
  _Slide(
    asset: 'assets/svg/cloud_sync.svg',
    eyebrow: 'OFFLINE FIRST',
    headline: 'No signal?\nKeep working.',
    body: 'Records are encrypted locally and sync automatically the moment you reconnect.',
  ),
  _Slide(
    asset: 'assets/svg/connected_world.svg',
    eyebrow: 'INTEROPERABILITY',
    headline: 'Kenya\'s health systems,\nconnected.',
    body: 'Real-time referrals and live status updates bridge your facility with National gateways.',
  ),
];