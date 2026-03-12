// lib/features/onboarding/presentation/pages/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import 'onboarding_page.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulse;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _runSplash();
  }

  Future<void> _runSplash() async {
    // Kick off storage check and animations in parallel
    final storageFuture = _checkOnboardingStatus();

    // Start animations immediately — no blank screen
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    // Wait for animations to finish AND at least a minimum display time
    await Future.wait([
      storageFuture,
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    final hasSeenOnboarding = await storageFuture;
    if (hasSeenOnboarding) {
      // Returning user — go straight to auth
      widget.onComplete();
    } else {
      // First-time user — show onboarding
      _showOnboarding();
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    const storage = FlutterSecureStorage();
    final value = await storage.read(key: StorageKeys.hasSeenOnboarding);
    return value == 'true';
  }

  void _showOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => OnboardingPage(
          onFinished: () {
            Navigator.of(context).pop();
            widget.onComplete();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3C2E),
      body: Stack(
        children: [
          const _BackgroundRings(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_logoController, _pulseController]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF52B788).withOpacity(0.25),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2D6A4F),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF52B788).withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, __) => SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          const Text(
                            'ClinicConnect',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Interoperable EHR for Kenya',
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF52B788).withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (_, __) => FadeTransition(
                opacity: _textOpacity,
                child: const Text(
                  'v1.0.0 · Laikipia University',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundRings extends StatelessWidget {
  const _BackgroundRings();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -120, right: -80, child: _ring(280, 0.06)),
        Positioned(top: -60, right: -30, child: _ring(160, 0.08)),
        Positioned(bottom: -100, left: -80, child: _ring(300, 0.05)),
        Positioned(bottom: -40, left: -20, child: _ring(160, 0.07)),
      ],
    );
  }

  Widget _ring(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF52B788).withOpacity(opacity),
            width: 1.5,
          ),
        ),
      );
}