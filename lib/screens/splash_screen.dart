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
    with SingleTickerProviderStateMixin {
  static const Color background = Color(0xFF07102F);
  static const Duration minSplashDuration = Duration(milliseconds: 2600);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.88, end: 1));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
    Future<void>.delayed(minSplashDuration, _goToHome);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    fit: BoxFit.fill,
                    repeat: true,
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
