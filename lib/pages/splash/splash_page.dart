import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/main.dart';
import 'package:roost_app/pages/auth/welcome_page.dart';
import 'package:roost_app/pages/onboarding/onboarding_page.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/country_service.dart';
import 'package:roost_app/widgets/common/roost_logo_icon.dart';
import 'package:roost_app/theme/app_colors.dart';

/// X (Twitter) platform-style splash screen.
/// Solid black background with a clean centered logo mark.
/// On launch completion, the logo expands seamlessly outward (zoom-through reveal)
/// as the app screen fades in behind it.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _zoomController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  bool _isLoggedIn = false;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 18.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _logoOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1200)),
      _prepareRouting(),
    ]);

    if (!mounted) return;

    // Execute X-style logo expansion zoom-through
    await _zoomController.forward();

    if (!mounted) return;
    _navigateToTarget();
  }

  Future<void> _prepareRouting() async {
    try {
      await CountryService.instance.init();
      _isLoggedIn = await AuthService.isLoggedIn();
      final prefs = await SharedPreferences.getInstance();
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    } catch (_) {}
  }

  void _navigateToTarget() {
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
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: AnimatedBuilder(
            animation: _zoomController,
            builder: (context, child) {
              return Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: const RoostLogoIcon(size: 88),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
