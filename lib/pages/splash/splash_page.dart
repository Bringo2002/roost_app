import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/main.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/onboarding/onboarding_page.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';
import 'package:roost_app/theme/app_colors.dart';

/// Premium animated splash screen with logo entrance, ambient glow,
/// dynamic typography, and fluid route transition.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseGlow;

  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<double> _textOffsetY;

  bool _isLoggedIn = false;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();

    // 1. Logo spring entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    // 2. Subtle ambient pulse breathing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Brand text & tagline reveal
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textOffsetY = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Immediately remove native static splash view so Flutter's smooth
    // animation starts cleanly
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      _prepareRouting(),
    ]);

    if (!mounted) return;
    _navigateWithSmoothTransition();
  }

  Future<void> _prepareRouting() async {
    try {
      await CountryService.instance.init();
      _isLoggedIn = await AuthService.isLoggedIn();
      final prefs = await SharedPreferences.getInstance();
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    } catch (_) {}
  }

  void _navigateWithSmoothTransition() {
    Widget targetPage;
    if (!_isLoggedIn) {
      if (!_onboardingCompleted) {
        targetPage = const OnboardingPage();
      } else {
        targetPage = const WelcomePage();
      }
    } else {
      targetPage = const HomePage();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient background glow effect
          AnimatedBuilder(
            animation: _pulseGlow,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8 * _pulseGlow.value,
                    colors: [
                      AppColors.white.withValues(alpha: 0.08),
                      AppColors.background.withValues(alpha: 0.8),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              );
            },
          ),

          // Central Logo & Brand Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Icon with animated scale, glow, and spring entrance
                AnimatedBuilder(
                  animation: Listenable.merge([_logoController, _pulseController]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.white.withValues(
                                  alpha: 0.18 * _pulseGlow.value,
                                ),
                                blurRadius: 40 * _pulseGlow.value,
                                spreadRadius: 10 * _pulseGlow.value,
                              ),
                            ],
                          ),
                          child: const RoostLogoIcon(size: 140),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Brand Name & Tagline Animated Reveal
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textOffsetY.value),
                        child: Column(
                          children: [
                            Text(
                              'ROOST',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8.0,
                                color: AppColors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Verified Homes & Rentals',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Minimalist bottom loading indicator
          Positioned(
            bottom: 60,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: SizedBox(
                    width: 48,
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.grey800,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.white.withValues(alpha: 0.8),
                      ),
                      minHeight: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
