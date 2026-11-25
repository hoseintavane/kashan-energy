import 'dart:async';
import 'dart:math' as m;
import 'package:flutter/material.dart';
import 'state.dart';
import 'ui.dart';

/// پس‌زمینه‌ی متحرک: آسمان شب، ستاره‌های چشمک‌زن و هاله‌های نورانی
class WelcomeBg extends StatefulWidget {
  final Widget child;
  const WelcomeBg({super.key, required this.child});
  @override
  State<WelcomeBg> createState() => _WelcomeBgState();
}

class _WelcomeBgState extends State<WelcomeBg> with SingleTickerProviderStateMixin {
  late final ac = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
        animation: ac,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + .4 * m.sin(ac.value * 6.283), -1),
              end: Alignment(1, 1 - .4 * m.cos(ac.value * 6.283)),
              colors: const [Color(0xFF040A1C), Color(0xFF0B1B45), Color(0xFF14307A)],
            ),
          ),
          child: CustomPaint(painter: _SkyPainter(ac.value), child: child),
        ),
        child: widget.child,
      );
}

class _SkyPainter extends CustomPainter {
  final double t;
  _SkyPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final r = m.Random(5);
    for (var i = 0; i < 80; i++) {
      final tw = (m.sin(t * 6.283 * (1 + i % 3) + i) + 1) / 2;
      c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height), r.nextDouble() * 1.3 + .3, Paint()..color = Colors.white.withOpacity(.15 + .6 * tw));
    }
    void blob(double fx, double fy, double rad, Color col, double ph) {
      final o = Offset(s.width * (fx + .08 * m.sin(t * 6.283 + ph)), s.height * (fy + .05 * m.cos(t * 6.283 + ph)));
      c.drawCircle(o, rad, Paint()..color = col..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90));
    }
    blob(.2, .25, 130, kBlue.withOpacity(.35), 0);
    blob(.85, .6, 150, kYellow.withOpacity(.16), 2);
    blob(.4, .95, 140, kRed.withOpacity(.18), 4);
  }

  @override
  bool shouldRepaint(_SkyPainter o) => true;
}

/// برق درخشان و نفس‌کش با حلقه‌های موج
class GlowBolt extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  const GlowBolt({super.key, this.icon = Icons.bolt_rounded, this.color = kYellow, this.size = 150});
  @override
  State<GlowBolt> createState() => _GlowBoltState();
}

class _GlowBoltState extends State<GlowBolt> with SingleTickerProviderStateMixin {
  late final ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SizedBox(
        width: widget.size * 1.6,
        height: widget.size * 1.6,
        child: AnimatedBuilder(
          animation: ac,
          builder: (_, __) {
            final b = (m.sin(ac.value * 6.283) + 1) / 2;
            return Stack(alignment: Alignment.center, children: [
              for (final k in [0.0, .5])
                Builder(builder: (_) {
                  final p = (ac.value + k) % 1;
                  return Container(
                    width: widget.size * (.9 + .7 * p),
                    height: widget.size * (.9 + .7 * p),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withOpacity((1 - p) * .5), width: 2)),
                  );
                }),
              Transform.scale(
                scale: .96 + .06 * b,
                child: Container(
                  width: widget.size * .8,
                  height: widget.size * .8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [widget.color.withOpacity(.35), Colors.white.withOpacity(.06)]),
                    border: Border.all(color: Colors.white.withOpacity(.25)),
                    boxShadow: [BoxShadow(color: widget.color.withOpacity(.35 + .3 * b), blurRadius: 40 + 30 * b, spreadRadius: 2)],
                  ),
                  child: Icon(widget.icon, size: widget.size * .48, color: widget.color),
                ),
              ),
            ]);
          },
        ),
      );
}

/// ظاهر شدن نرم با تأخیر
class FadeSlide extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeSlide({super.key, required this.child, this.delayMs = 0});
  @override
  State<FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<FadeSlide> with SingleTickerProviderStateMixin {
  late final ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) ac.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final a = CurvedAnimation(parent: ac, curve: Curves.easeOutCubic);
    return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a), child: widget.child));
  }
}

Widget goldTitle(String t, double size) => ShaderMask(
      shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFF4CC), kYellow, Color(0xFFFFB84C)]).createShader(r),
      child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
    );

/// ===== خوش‌آمدگویی هنگام هر بار باز شدن برنامه =====
class WelcomeSplash extends StatelessWidget {
  final VoidCallback onDone;
  const WelcomeSplash({super.key, required this.onDone});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final h = DateTime.now().hour;
    final greet = h < 5 ? 'شب بخیر' : h < 12 ? 'صبح بخیر' : h < 17 ? 'ظهر بخیر' : h < 20 ? 'عصر بخیر' : 'شب بخیر';
    return GestureDetector(
      onTap: onDone,
      child: WelcomeBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const GlowBolt(),
                const SizedBox(height: 12),
                FadeSlide(delayMs: 200, child: goldTitle('به انرژی کاشان خوش آمدید', 28)),
                const SizedBox(height: 10),
                FadeSlide(delayMs: 600, child: Text(a.signedIn && !a.isAdmin ? '$greet، ${a.name} عزیز' : greet, style: const TextStyle(color: Colors.white, fontSize: 18))),
                const SizedBox(height: 6),
                FadeSlide(delayMs: 900, child: Text('مصرف هوشمند، شهر روشن‌تر', style: TextStyle(color: Colors.white.withOpacity(.65)))),
                const SizedBox(height: 36),
                FadeSlide(
                  delayMs: 1200,
                  child: SizedBox(
                    width: 140,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1800),
                      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 4, borderRadius: BorderRadius.circular(4), color: kYellow, backgroundColor: Colors.white12),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== راهنمای اولین ورود =====
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final pc = PageController();
  int i = 0;
  static const pages = [
    (Icons.bolt_rounded, kYellow, 'انرژی کاشان', 'مصرف برق خود را ببینید، بسنجید و هوشمندانه مدیریت کنید.'),
    (Icons.insights_rounded, Color(0xFF6EA8FF), 'تحلیل و هشدار', 'روند مصرف، مقایسه با دوره‌های قبل و هشدار افزایش غیرعادی، همه در یک جا.'),
    (Icons.shield_moon_rounded, Color(0xFFFF7A80), 'امن و خصوصی', 'اطلاعات شما رمزنگاری می‌شود و فقط روی دستگاه خودتان می‌ماند.'),
  ];

  void finish() {
    final a = Scope.of(context);
    a.update(() {
      a.onboarded = true;
      a.savePrefs();
    });
  }

  @override
  Widget build(BuildContext c) => WelcomeBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(children: [
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: finish, child: const Text('رد کردن', style: TextStyle(color: Colors.white70)))),
              Expanded(
                child: PageView.builder(
                  controller: pc,
                  itemCount: pages.length,
                  onPageChanged: (v) => setState(() => i = v),
                  itemBuilder: (_, k) {
                    final p = pages[k];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        GlowBolt(icon: p.$1, color: p.$2, size: 140),
                        const SizedBox(height: 20),
                        FadeSlide(key: ValueKey('t$k'), delayMs: 150, child: goldTitle(p.$3, 28)),
                        const SizedBox(height: 14),
                        FadeSlide(key: ValueKey('d$k'), delayMs: 400, child: Text(p.$4, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 16, height: 1.8))),
                      ]),
                    );
                  },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < pages.length; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.all(4),
                    width: k == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: k == i ? kYellow : Colors.white30, borderRadius: BorderRadius.circular(8)),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: kYellow, foregroundColor: const Color(0xFF1B1B1B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  onPressed: () => i == pages.length - 1 ? finish() : pc.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
                  child: Text(i == pages.length - 1 ? 'شروع کنید' : 'بعدی', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      );
}
