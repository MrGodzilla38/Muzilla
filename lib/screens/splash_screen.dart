import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'root_shell.dart';

/// Tek açılış ekranı: ortada logo, hemen altında Lottie yüklenme barı.
/// Zemin rengi native açılış ekranıyla birebir aynı (#07102F) olduğundan
/// OS splash'ından bu ekrana geçiş kesintisiz akar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color background = Color(0xFF07102F);

  /// Bar animasyonu hız çarpanı: 1 = orijinal hız, 2 = 2 kat hızlı.
  static const double barSpeed = 3.5;

  /// Animasyonda dolu barın (trim %50) ulaştığı kompozisyon oranı.
  /// loading.json: trim 0. kareden 310. kareye kadar %0 -> %100,
  /// kompozisyon toplamı 362 kare, yani yarı = 155/362.
  static const double barHalfProgress = 155 / 362;

  /// Lottie yüklenemezse uygulamanın yine de açılması için güvenlik süresi.
  static const Duration fallbackDuration = Duration(seconds: 5);

  late final AnimationController _logoController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  late final AnimationController _barController;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.88, end: 1));
    _fade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);

    _barController = AnimationController(
      vsync: this,
      duration: fallbackDuration,
    );

    _logoController.forward();
    _scheduleNavigation(fallbackDuration);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _logoController.dispose();
    _barController.dispose();
    super.dispose();
  }

  void _scheduleNavigation(Duration delay) {
    if (_navigated) return;
    _navTimer?.cancel();
    _navTimer = Timer(delay, _goToHome);
  }

  void _onBarLoaded(LottieComposition composition) {
    final int scaledMs =
        (composition.duration.inMilliseconds / barSpeed).round();

    _barController.duration = Duration(milliseconds: scaledMs);
    _barController.forward(from: 0);

    // Uygulama bar tam ortaya (yüzde 50) geldiğinde açılsın.
    _scheduleNavigation(
      Duration(milliseconds: (scaledMs * barHalfProgress).round()),
    );
  }

  void _goToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const RootShell(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double logoSize = (screen.width * 0.42).clamp(140.0, 240.0);
    final double barWidth = (screen.width * 0.78).clamp(220.0, 420.0);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(logoSize * 0.22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2FD8FF).withValues(alpha: 0.25),
                        blurRadius: 70,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, logoSize / 2 + screen.height * 0.075),
              child: FadeTransition(
                opacity: _fade,
                child: SizedBox(
                  width: barWidth,
                  height: barWidth * 200 / 1080,
                child: Lottie.asset(
                  'assets/animations/loading.json',
                  controller: _barController,
                  onLoaded: _onBarLoaded,
                  fit: BoxFit.fill,
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
