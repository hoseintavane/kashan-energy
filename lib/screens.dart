import 'package:flutter/material.dart';
import 'more.dart';
import 'admin.dart';
import 'export.dart';
import 'map.dart';
import 'state.dart';
import 'ui.dart';

/// ===== ورود، ثبت‌نام، مدیر =====
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  int mode = 0; // 0 ورود، 1 ثبت‌نام، 2 مدیر
  final uc = TextEditingController(), pc = TextEditingController();
  bool busy = false, hide = true;

  Future<void> go() async {
    final a = Scope.of(context);
    final u = uc.text.trim(), p = pc.text;
    if (mode != 2 && u.isEmpty) return toast(context, 'نام کاربری را وارد کنید.');
    if (p.isEmpty) return toast(context, 'رمز عبور را وارد کنید.');
    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 50)); // اجازه‌ی نمایش نشانگر
    String? err;
    try {
      err = mode == 2 ? a.adminLogin(p) : mode == 1 ? a.register(u, p) : a.userLogin(u, p);
    } catch (_) {
      err = 'خطای غیرمنتظره رخ داد. دوباره تلاش کنید.';
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) toast(context, err);
  }

  @override
  Widget build(BuildContext c) {
    const labels = ['ورود کاربر', 'ثبت‌نام', 'مدیریت'];
    return Bg(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  const Icon(Icons.bolt_rounded, size: 64, color: kYellow),
                  Text('انرژی کاشان', style: Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: kBlue)),
                  const SizedBox(height: 20),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [for (var k = 0; k < 3; k++) ButtonSegment(value: k, label: Text(labels[k], style: const TextStyle(fontSize: 12)))],
                    selected: {mode},
                    onSelectionChanged: (s) => setState(() { mode = s.first; pc.clear(); }),
                  ),
                  const SizedBox(height: 20),
                  Glass(
                    child: Column(children: [
                      if (mode != 2) TextField(controller: uc, decoration: const InputDecoration(labelText: 'نام کاربری', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pc,
                        obscureText: hide,
                        onSubmitted: (_) => go(),
                        decoration: InputDecoration(
                          labelText: mode == 2 ? 'رمز مدیریت' : 'رمز عبور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: mode == 2 ? kRed : kBlue),
                        onPressed: busy ? null : go,
                        child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(labels[mode]),
                      ),
                    ]),
                  ),
                  Text(
                    mode == 1 ? 'اطلاعات شما رمزنگاری‌شده روی همین دستگاه ذخیره می‌شود.' : mode == 2 ? 'ورود مدیر کاملاً جدا از ورود کاربران است.' : 'حساب ندارید؟ از «ثبت‌نام» استفاده کنید.',
                    textAlign: TextAlign.center,
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== قالب اصلی کاربر =====
class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    const titles = ['انرژی کاشان', 'تحلیل و گزارش', 'نقشه ایران', 'ابزارها', 'حساب و تنظیمات'];
    final pages = [const Dashboard(), const AnalysisPage(), const MapPage(), const ToolsPage(), const MorePage()];
    final n = a.notifOn ? a.notifications().length : 0;
    return Bg(
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[a.tab]),
          actions: [
            IconButton(
              icon: Badge(isLabelVisible: n > 0, label: Text(fa(n)), child: const Icon(Icons.notifications_outlined)),
              onPressed: () => showModalBottomSheet(context: c, builder: (_) => Scope(notifier: a, child: const NotifSheet())),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (w, an) => FadeTransition(opacity: an, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(an), child: w)),
          child: KeyedSubtree(key: ValueKey(a.tab), child: pages[a.tab]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: a.tab,
          onDestinationSelected: (i) => a.update(() => a.tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'تحلیل'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'نقشه'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'ابزارها'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حساب'),
          ],
        ),
      ),
    );
  }
}

class NotifSheet extends StatelessWidget {
  const NotifSheet({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final ns = a.notifOn ? a.notifications() : <String>[];
    return SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('اعلان‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (a.anns.isNotEmpty) TextButton(onPressed: () { a.clearNotifs(); Navigator.pop(c); }, child: const Text('پاک کردن اطلاعیه‌ها')),
        ]),
        if (ns.isEmpty) const EmptyBox('اعلانی وجود ندارد.', icon: Icons.notifications_none),
        for (final n in ns) ListTile(leading: const Icon(Icons.notifications_active_outlined, color: kYellow), title: Text(n)),
      ]),
    );
  }
}

/// ثبت قرائت کنتور (منبع واقعی همه‌ی آمار برنامه)
Future<void> addReadingDialog(BuildContext c) async {
  final a = Scope.of(c);
  final t = TextEditingController();
  var date = day(DateTime.now());
  String? err;
  await showDialog(
    context: c,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('ثبت قرائت کنتور'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'عدد کنتور (کیلووات‌ساعت)', errorText: err)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('تاریخ: ${jDate(date)}'),
            onPressed: () async {
              final p = await showDatePicker(context: d, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (p != null) set(() => date = day(p));
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(t.text.trim().replaceAll('٫', '.').replaceAll(',', '.'));
              if (v == null || v < 0) return set(() => err = 'یک عدد معتبر وارد کنید.');
              final list = [...a.readings.map((e) => Map<String, dynamic>.from(e)), {'d': date.toIso8601String(), 'v': v}]
                ..sort((x, y) => (x['d'] as String).compareTo(y['d'] as String));
              for (var i = 1; i < list.length; i++) {
                if ((list[i]['v'] as num) < (list[i - 1]['v'] as num)) {
                  return set(() => err = 'عدد کنتور نباید از قرائت قبلی در تاریخ پیشین‌تر کمتر باشد.');
                }
              }
              a.ud['readings'] = list;
              a.log('ثبت قرائت کنتور ${fa(v, d: 1)}');
              a.persist();
              Navigator.pop(d);
              toast(c, 'قرائت ذخیره شد.');
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ),
  );
}

/// ===== داشبورد شخصی (فقط داده‌ی واقعیِ واردشده) =====
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final now = DateTime.now();
    final j = toJalali(now);
    final u = dailyUsage(a.readings);
    final wk = periodOf(u, 0);
    final mo = periodOf(u, 2);
    final hasM = mo.has.last;
    final tariff = (a.ud['tariff'] as num?)?.toDouble();
    Widget stat(String t, String v, String sub) => Expanded(
          child: Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: Theme.of(c).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(v, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: kBlue)),
              Text(sub, style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Row(children: [
        const CircleAvatar(backgroundColor: kBlue, child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('سلام، ${a.name}', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('${fa(j[2])} ${jMonths[j[1] - 1]} ${fa(j[0])}', style: Theme.of(c).textTheme.bodySmall),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      if (a.readings.length < 2)
        Glass(
          child: Column(children: [
            const EmptyBox('هنوز داده‌ای ثبت نشده است. برای دیدن مصرف، دست‌کم دو قرائت کنتور (در دو تاریخ مختلف) ثبت کنید.', icon: Icons.speed),
            FilledButton.icon(onPressed: () => addReadingDialog(c), icon: const Icon(Icons.add), label: const Text('ثبت قرائت کنتور')),
          ]),
        )
      else ...[
        Row(children: [
          stat('مصرف این ماه', hasM ? '${fa(mo.values.last, d: 1)} kWh' : 'بدون داده', 'بر پایه‌ی قرائت‌های شما'),
          const SizedBox(width: 12),
          stat('هزینه‌ی برآوردی این ماه', hasM && tariff != null ? '${fa(mo.values.last * tariff)} تومان' : 'نرخ ثبت نشده', tariff == null ? 'نرخ را در «حساب» وارد کنید' : 'با نرخ ${fa(tariff)}'),
        ]),
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مصرف ۷ روز اخیر', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 170, child: wk.any ? lineChart(wk.values, wk.labels, kBlue) : const EmptyBox('برای ۷ روز اخیر قرائتی ثبت نشده است.')),
          ]),
        ),
        FilledButton.tonalIcon(onPressed: () => addReadingDialog(c), icon: const Icon(Icons.add), label: const Text('ثبت قرائت جدید')),
        const SizedBox(height: 12),
      ],
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final q in [
            (Icons.map_rounded, 'نقشه', () => a.update(() => a.tab = 2)),
            (Icons.receipt_long_rounded, 'قبض‌ها', () => a.update(() { a.tab = 3; a.toolsTab = 1; })),
            (Icons.bar_chart_rounded, 'تحلیل', () => a.update(() => a.tab = 1)),
            (Icons.school_rounded, 'آموزش', () => push(c, const LearnPage())),
          ])
            Glass(
              padding: EdgeInsets.zero,
              onTap: q.$3,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(q.$1, color: kBlue), const SizedBox(height: 4), Text(q.$2, style: const TextStyle(fontSize: 12))]),
            ),
        ],
      ),
    ]);
  }
}

/// ===== تحلیل و گزارش‌گیری =====
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override
  State<AnalysisPage> createState() => _AnalysisState();
}

class _AnalysisState extends State<AnalysisPage> {
  int r = 1;
  static const names = ['روزانه', 'هفتگی', 'ماهانه', 'سالانه'];
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final p = periodOf(dailyUsage(a.readings), r == 0 ? 0 : r);
    final n = p.values.length;
    final canCmp = n >= 2 && p.has[n - 1] && p.has[n - 2] && p.values[n - 2] > 0;
    final ch = canCmp ? (p.values[n - 1] - p.values[n - 2]) / p.values[n - 2] * 100 : 0.0;
    final tariff = (a.ud['tariff'] as num?)?.toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [for (var k = 0; k < 4; k++) ButtonSegment(value: k, label: Text(names[k], style: const TextStyle(fontSize: 12)))],
        selected: {r},
        onSelectionChanged: (s) => setState(() => r = s.first),
      ),
      const SizedBox(height: 12),
      Glass(child: SizedBox(height: 200, child: p.any ? barChart(p.values, p.labels, kBlue) : const EmptyBox('داده‌ای برای این بازه ثبت نشده است. از «خانه» قرائت کنتور ثبت کنید.', icon: Icons.bar_chart))),
      Glass(
        child: canCmp
            ? Row(children: [
                Icon(ch > 0 ? Icons.trending_up : Icons.trending_down, color: ch > 0 ? kRed : kBlue, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${ch > 0 ? '+' : ''}${fa(ch, d: 1)}٪ نسبت به دوره‌ی قبل', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(ch > 0 ? 'مصرف افزایش یافته است؛ پیشنهادها را ببینید.' : 'مصرف کاهش یافته است؛ ادامه دهید.', style: Theme.of(c).textTheme.bodySmall),
                  ]),
                ),
              ])
            : const EmptyBox('برای مقایسه‌ی دوره‌ها، دو بازه‌ی پیاپی با داده لازم است.', icon: Icons.compare_arrows),
      ),
      if (p.any)
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('جزئیات', style: TextStyle(fontWeight: FontWeight.bold)),
            for (var i = 0; i < n; i++)
              if (p.has[i])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.labels[i]),
                  trailing: Text('${fa(p.values[i], d: 1)} kWh${tariff != null ? '  |  ${fa(p.values[i] * tariff)} تومان' : ''}'),
                ),
          ]),
        ),
      if (canCmp && ch > 0)
        const Glass(child: Text('پیشنهاد: دمای سرمایش/گرمایش را یک تا دو درجه تعدیل کنید و وسایل پرمصرف را در ساعات کم‌باری استفاده کنید.')),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: p.any ? () => exportReport(c, names[r], p, tariff, pdf: true) : null, icon: const Icon(Icons.picture_as_pdf), label: const Text('خروجی PDF'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: p.any ? () => exportReport(c, names[r], p, tariff, pdf: false) : null, icon: const Icon(Icons.table_chart), label: const Text('خروجی Excel'))),
      ]),
    ]);
  }
}
