import 'package:flutter/material.dart';

/// Animation d'ouverture avant l'écran de bienvenue (sélection de rôle) :
/// le logo complet (avec tagline) apparaît en une seule étape, zoom léger +
/// fondu (ScaleTransition + FadeTransition, easeOutBack), puis courte pause
/// avant la navigation automatique. Pas de phase intermédiaire avec l'aigle
/// seul. Le splash NATIF (flutter_native_splash, écran fixe avant que
/// Flutter démarre) est indépendant de cet écran et n'est pas concerné ici.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _leadIn = Duration(milliseconds: 300);
  static const _zoomFade = Duration(milliseconds: 1300); // logo complet : zoom + fondu
  static const _pause = Duration(milliseconds: 700); // pause sur le logo complet

  late final Duration _animDuration = _zoomFade + _pause;

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animDuration);

    final zoomEnd = _zoomFade.inMilliseconds / _animDuration.inMilliseconds;

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, zoomEnd, curve: Curves.easeOutBack)),
    );

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: _zoomFade.inMilliseconds.toDouble()),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _pause.inMilliseconds.toDouble()),
    ]).animate(_controller);

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(_leadIn);
    if (!mounted) return;
    await _controller.forward();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/role_selection');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Image.asset(
                  'assets/branding/logo_with_tagline_partner_merchant.png',
                  width: MediaQuery.of(context).size.width * 0.65,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
