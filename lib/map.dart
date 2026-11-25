import 'dart:math' as m;
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'state.dart';
import 'ui.dart';

/// ===== نقشه‌ی ایران (روز و شب) =====
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapState();
}

class _MapState extends State<MapPage> with SingleTickerProviderStateMixin {
  late final ac = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  int mode = 0; // 0 نقشه‌ی واقعی کاشان، 1 نقشه‌ی شماتیک ایران
  static const kashan = LatLng(33.9850, 51.4100);
  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  Widget real(bool d) {
    final map = FlutterMap(
      options: const MapOptions(initialCenter: kashan, initialZoom: 12.5, minZoom: 4, maxZoom: 18),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ir.kashan.kashan_energy'),
        const MarkerLayer(markers: [Marker(point: kashan, width: 90, height: 60, child: Column(children: [Icon(Icons.location_on, color: kRed, size: 34), Text('کاشان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87, backgroundColor: Colors.white70))]))]),
        const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
      ],
    );
    // حالت شب: تیره‌کردن کاشی‌های نقشه
    return d
        ? ColorFiltered(colorFilter: const ColorFilter.matrix([-.8, 0, 0, 0, 255, 0, -.8, 0, 0, 255, 0, 0, -.8, 0, 255, 0, 0, 0, 1, 0]), child: map)
        : map;
  }

  @override
  Widget build(BuildContext c) {
    final d = isDark(c);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [ButtonSegment(value: 0, label: Text('نقشه‌ی کاشان')), ButtonSegment(value: 1, label: Text('ایران (شماتیک)'))],
        selected: {mode},
        onSelectionChanged: (s) => setState(() => mode = s.first),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: mode == 0 ? 1 : 1.32,
          child: mode == 0 ? real(d) : AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: IranPainter(d, ac.value))),
        ),
      ),
      const SizedBox(height: 12),
      Glass(
        child: Row(children: [
          const Icon(Icons.location_on, color: kRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('کاشان', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(mode == 0 ? 'نقشه‌ی واقعی از OpenStreetMap؛ برای نمایش به اینترنت نیاز دارد. با دو انگشت بزرگ‌نمایی کنید.' : 'نقشه‌ی شماتیک و ساده‌شده است و داده‌ی مصرف شهرها را نشان نمی‌دهد.', style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class IranPainter extends CustomPainter {
  final bool dark;
  final double t;
  IranPainter(this.dark, this.t);

  static const outline = [
    [44.0, 39.4], [45.5, 38.9], [47.5, 39.6], [48.9, 38.4], [49.5, 37.5], [51.0, 36.8], [53.9, 37.3], [54.7, 37.5],
    [56.0, 38.2], [57.3, 38.0], [59.3, 37.6], [60.5, 36.6], [61.2, 36.6], [60.8, 34.5], [60.5, 33.6], [60.9, 31.5],
    [61.8, 31.3], [61.6, 29.8], [63.2, 29.5], [62.4, 28.2], [61.6, 25.2], [57.3, 25.7], [56.7, 27.1], [54.5, 26.6],
    [52.5, 27.5], [51.0, 28.9], [50.1, 30.2], [48.9, 30.2], [48.0, 30.0], [47.7, 31.0], [46.1, 33.0], [45.4, 34.4],
    [45.9, 35.9], [44.8, 37.2], [44.2, 38.4],
  ];
  // طول، عرض، وزن روشنایی
  static const cities = [
    [51.4, 35.7, 3.0], [59.6, 36.3, 2.2], [51.7, 32.65, 2.0], [52.5, 29.6, 1.8], [46.3, 38.1, 1.8],
    [48.7, 31.3, 1.6], [57.1, 30.3, 1.2], [49.6, 37.3, 1.2], [56.3, 27.2, 1.0], [60.9, 29.5, 0.8],
    [54.4, 31.9, 1.0], [47.1, 34.3, 1.1], [51.45, 33.98, 1.4],
  ];

  Offset _p(double lo, double la, Size s) => Offset((lo - 43.5) / 20.5 * s.width, (40 - la) / 15.5 * s.height);

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF050B1A), Color(0xFF0E1B3D)] : const [Color(0xFFD6E6FF), Colors.white],
        ).createShader(r),
    );
    final path = ui.Path();
    for (var i = 0; i < outline.length; i++) {
      final o = _p(outline[i][0], outline[i][1], s);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    if (dark) {
      final rnd = m.Random(7);
      for (var i = 0; i < 60; i++) {
        final tw = (m.sin(t * 6.283 + i) + 1) / 2;
        c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * .9), rnd.nextDouble() * 1.1 + .3, Paint()..color = Colors.white.withOpacity(.2 + .5 * tw));
      }
    } else {
      c.drawShadow(path, const Color(0xFF2463EB), 10, true);
    }
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF14224A), Color(0xFF0C1630)] : const [Colors.white, kSilver],
        ).createShader(r),
    );
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = dark ? const Color(0xFF3A4F85) : kBlue.withOpacity(.55));

    for (var k = 0; k < cities.length; k++) {
      final ct = cities[k];
      final o = _p(ct[0], ct[1], s);
      final w = ct[2];
      final rnd = m.Random(k + 11);
      if (dark) {
        final tw = .55 + .35 * m.sin(t * 6.283 + k);
        c.drawCircle(o, 9 + 4 * w, Paint()..color = kYellow.withOpacity(.35 * tw)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        for (var i = 0; i < (w * 9).round(); i++) {
          final q = o + Offset((rnd.nextDouble() - .5) * (16 + 6 * w), (rnd.nextDouble() - .5) * (16 + 6 * w));
          c.drawCircle(q, .9 + rnd.nextDouble() * .8, Paint()..color = const Color(0xFFFFE9A8).withOpacity(.6 + .4 * tw));
        }
        c.drawCircle(o, 2 + w * .5, Paint()..color = const Color(0xFFFFF4CC));
      } else {
        for (var i = 0; i < (w * 5).round(); i++) {
          final q = o + Offset((rnd.nextDouble() - .5) * (14 + 5 * w), (rnd.nextDouble() - .5) * (14 + 5 * w));
          c.drawCircle(q, 1.1, Paint()..color = kBlue.withOpacity(.35));
        }
        c.drawCircle(o, 2.2 + w * .5, Paint()..color = kBlue);
      }
    }
    final k = _p(51.45, 33.98, s);
    c.drawCircle(k, 7 + 14 * t, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kRed.withOpacity(1 - t));
    c.drawCircle(k, 4.5, Paint()..color = kRed);
    final tp = TextPainter(
      text: TextSpan(text: 'کاشان', style: TextStyle(color: dark ? Colors.white : kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, k + const Offset(10, -7));
  }

  @override
  bool shouldRepaint(IranPainter o) => true;
}
