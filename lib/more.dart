import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'state.dart';
import 'ui.dart';

/// ===== ابزارها: ماشین‌حساب، قبض‌ها، چالش‌ها =====
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    return DefaultTabController(
      length: 3,
      initialIndex: a.toolsTab,
      child: Column(children: const [
        TabBar(tabs: [Tab(text: 'ماشین‌حساب'), Tab(text: 'قبض‌ها'), Tab(text: 'چالش‌ها')]),
        Expanded(child: TabBarView(children: [CalcTab(), BillsTab(), ChallengesTab()])),
      ]),
    );
  }
}

class CalcTab extends StatefulWidget {
  const CalcTab({super.key});
  @override
  State<CalcTab> createState() => _CalcState();
}

class _CalcState extends State<CalcTab> {
  String sel = 'کولر آبی';
  double w = 250, h = 8;
  int q = 1;
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final tariff = (a.ud['tariff'] as num?)?.toDouble();
    final kwh = w * q * h * 30 / 1000;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String>(
            value: sel,
            decoration: const InputDecoration(labelText: 'وسیله‌ی برقی'),
            items: [for (final e in presets.keys) DropdownMenuItem(value: e, child: Text(e))],
            onChanged: (v) => setState(() {
              if (v == null) return;
              sel = v;
              w = presets[v]!;
            }),
          ),
          const SizedBox(height: 12),
          Text('توان: ${fa(w)} وات (مقدار تقریبی؛ از برچسب دستگاه بخوانید)'),
          Slider(value: w.clamp(5, 3000), min: 5, max: 3000, onChanged: (v) => setState(() => w = v.roundToDouble())),
          Text('مدت استفاده: ${fa(h, d: 1)} ساعت در روز'),
          Slider(value: h, min: 0, max: 24, divisions: 48, onChanged: (v) => setState(() => h = v)),
          Row(children: [
            const Text('تعداد'),
            const Spacer(),
            IconButton(onPressed: q > 1 ? () => setState(() => q--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text(fa(q), style: const TextStyle(fontSize: 18)),
            IconButton(onPressed: () => setState(() => q++), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ]),
      ),
      Glass(
        tint: kBlue.withOpacity(.1),
        child: Column(children: [
          Text('مصرف ماهانه: ${fa(kwh, d: 1)} کیلووات‌ساعت', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(tariff == null ? 'برای دیدن هزینه، نرخ را در «حساب» وارد کنید.' : 'هزینه‌ی تقریبی: ${fa(kwh * tariff)} تومان', style: const TextStyle(fontSize: 16, color: kBlue, fontWeight: FontWeight.bold)),
        ]),
      ),
    ]);
  }
}

class BillsTab extends StatefulWidget {
  const BillsTab({super.key});
  @override
  State<BillsTab> createState() => _BillsState();
}

class _BillsState extends State<BillsTab> {
  Future<void> upload(Map b) async {
    final a = Scope.of(context);
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (f == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(f.path).copy(path);
      b['receipt'] = path;
      b['status'] = 'در انتظار تأیید';
      a.log('بارگذاری رسید برای «${b['title']}»');
      a.persist();
    } catch (_) {
      if (mounted) toast(context, 'بارگذاری تصویر ناموفق بود. دسترسی به گالری را بررسی کنید.');
    }
  }

  Future<void> add() async {
    final a = Scope.of(context);
    final t = TextEditingController(), m = TextEditingController();
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('قبض جدید'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: const InputDecoration(labelText: 'عنوان (مثلاً قبض آبان)')),
          TextField(controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final amt = int.tryParse(m.text.trim());
              if (t.text.trim().isEmpty || amt == null || amt <= 0) return toast(d, 'عنوان و مبلغ معتبر وارد کنید.');
              a.bills.add({'title': t.text.trim(), 'amount': amt, 'status': 'پرداخت‌نشده', 'receipt': null});
              a.log('افزودن قبض «${t.text.trim()}»');
              a.persist();
              Navigator.pop(d);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final col = {'پرداخت‌شده': kBlue, 'پرداخت‌نشده': kRed, 'در انتظار تأیید': kYellow};
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.tonalIcon(onPressed: add, icon: const Icon(Icons.add), label: const Text('افزودن قبض')),
      const SizedBox(height: 12),
      if (a.bills.isEmpty) const EmptyBox('قبضی ثبت نشده است.', icon: Icons.receipt_long),
      for (final b in a.bills.cast<Map>())
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.bold))),
              Chip(label: Text('${b['status']}', style: const TextStyle(fontSize: 11)), side: BorderSide(color: col[b['status']] ?? kBlue)),
            ]),
            Text('${fa(b['amount'] as num)} تومان'),
            if (b['receipt'] != null && File(b['receipt']).existsSync())
              Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(b['receipt']), height: 110, fit: BoxFit.cover))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (b['status'] != 'پرداخت‌شده') OutlinedButton.icon(onPressed: () => upload(b), icon: const Icon(Icons.upload_file), label: const Text('بارگذاری رسید پرداخت')),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: kRed),
                onPressed: () async {
                  if (await confirmDelete(c, '${b['title']}')) {
                    a.bills.remove(b);
                    a.log('حذف قبض «${b['title']}»');
                    a.persist();
                  }
                },
              ),
            ]),
            if (b['status'] == 'پرداخت‌نشده') Text('پرداخت آنلاین پس از اتصال به درگاه رسمی فعال می‌شود؛ تا آن زمان رسید پرداخت را بارگذاری کنید تا مدیر تأیید کند.', style: Theme.of(c).textTheme.bodySmall),
          ]),
        ),
    ]);
  }
}

class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final joined = a.ud['joined'] as Map;
    final today = day(DateTime.now()).toIso8601String();
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (var i = 0; i < challenges.length; i++)
        Builder(builder: (_) {
          final id = '$i';
          final days = (joined[id] as List?)?.cast<String>();
          final on = days != null;
          final done = days?.length ?? 0;
          return Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(challenges[i].$1, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(challenges[i].$2, style: Theme.of(c).textTheme.bodySmall),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: on ? (done / challenges[i].$3).clamp(0, 1).toDouble() : 0, minHeight: 8, borderRadius: BorderRadius.circular(8), color: kYellow, backgroundColor: kYellow.withOpacity(.2)),
              if (on) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${fa(done)} از ${fa(challenges[i].$3)} روز', style: Theme.of(c).textTheme.bodySmall)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton.tonal(
                  onPressed: () {
                    if (on) {
                      joined.remove(id);
                    } else {
                      joined[id] = <String>[];
                      a.log('پیوستن به چالش «${challenges[i].$1}»');
                    }
                    a.persist();
                  },
                  child: Text(on ? 'انصراف' : 'پیوستن'),
                ),
                if (on)
                  FilledButton(
                    onPressed: days!.contains(today) ? null : () { days.add(today); a.persist(); },
                    child: Text(days!.contains(today) ? 'امروز ثبت شد' : 'امروز پایبند بودم'),
                  ),
              ]),
            ]),
          );
        }),
    ]);
  }
}

/// ===== حساب و تنظیمات =====
class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    Widget tile(IconData i, String t, Widget p) => Glass(padding: EdgeInsets.zero, child: ListTile(leading: Icon(i, color: kBlue), title: Text(t), trailing: const Icon(Icons.chevron_left), onTap: () => push(c, p)));
    final tariff = (a.ud['tariff'] as num?)?.toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Glass(
        child: Row(children: [
          const CircleAvatar(radius: 28, backgroundColor: kBlue, child: Icon(Icons.person, color: Colors.white, size: 30)),
          const SizedBox(width: 14),
          Text(a.name, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]),
      ),
      Glass(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.payments_outlined, color: kBlue),
          title: const Text('نرخ هر کیلووات‌ساعت (تومان)'),
          subtitle: Text(tariff == null ? 'ثبت نشده؛ برای برآورد هزینه وارد کنید' : fa(tariff)),
          trailing: const Icon(Icons.edit),
          onTap: () {
            final t = TextEditingController(text: tariff?.toStringAsFixed(0) ?? '');
            showDialog(
              context: c,
              builder: (d) => AlertDialog(
                title: const Text('نرخ هر کیلووات‌ساعت'),
                content: TextField(controller: t, keyboardType: TextInputType.number, decoration: const InputDecoration(helperText: 'نرخ را از قبض برق خود وارد کنید')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
                  FilledButton(
                    onPressed: () {
                      final v = double.tryParse(t.text.trim());
                      if (v == null || v <= 0) return toast(d, 'یک عدد معتبر وارد کنید.');
                      a.ud['tariff'] = v;
                      a.log('تغییر نرخ');
                      a.persist();
                      Navigator.pop(d);
                    },
                    child: const Text('ذخیره'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      tile(Icons.speed, 'اشتراک و اطلاعات کنتور', const SubPage()),
      tile(Icons.school_outlined, 'آموزش و فرهنگ‌سازی', const LearnPage()),
      tile(Icons.edit_note, 'یادداشت‌ها و جست‌وجو', const NotesPage()),
      tile(Icons.notifications_active_outlined, 'هشدارهای هوشمند', const AlertsPage()),
      tile(Icons.support_agent, 'پشتیبانی و قطعی برق', const SupportPage()),
      tile(Icons.palette_outlined, 'شخصی‌سازی ظاهر', const ThemePage()),
      tile(Icons.lock_reset, 'تغییر رمز عبور', const PasswordPage()),
      tile(Icons.history, 'سوابق فعالیت من', const MyLogPage()),
      Glass(padding: EdgeInsets.zero, child: ListTile(leading: const Icon(Icons.logout, color: kRed), title: const Text('خروج از حساب'), onTap: a.logout)),
    ]);
  }
}

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});
  @override
  Widget build(BuildContext c) => Frame('آموزش و فرهنگ‌سازی', child: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in lessons.entries)
          Glass(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              leading: const Icon(Icons.lightbulb_outline, color: kYellow),
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              children: [for (final t in e.value) ListTile(dense: true, leading: const Icon(Icons.check_circle, size: 18, color: kBlue), title: Text(t))],
            ),
          ),
      ]));
}

class SubPage extends StatefulWidget {
  const SubPage({super.key});
  @override
  State<SubPage> createState() => _SubState();
}

class _SubState extends State<SubPage> {
  late final id = TextEditingController(text: '${Scope.of(context).ud['billId'] ?? ''}');
  late final meter = TextEditingController(text: '${Scope.of(context).ud['meter'] ?? ''}');
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    return Frame('اشتراک و کنتور', child: ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(children: [
          TextField(controller: id, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شناسه‌ی قبض')),
          const SizedBox(height: 12),
          TextField(controller: meter, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شماره‌ی کنتور')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              a.ud['billId'] = id.text.trim();
              a.ud['meter'] = meter.text.trim();
              a.log('به‌روزرسانی اطلاعات اشتراک');
              await a.persist();
              if (c.mounted) toast(c, 'به‌صورت رمزنگاری‌شده روی دستگاه ذخیره شد.');
            },
            child: const Text('ذخیره'),
          ),
        ]),
      ),
      Text('اطلاعات فقط رمزنگاری‌شده روی همین دستگاه نگه داشته می‌شود و به سامانه‌ی رسمی وصل نیست.', style: Theme.of(c).textTheme.bodySmall),
    ]));
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesState();
}

class _NotesState extends State<NotesPage> {
  String q = '';
  void add() {
    final a = Scope.of(context);
    final t = TextEditingController();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('یادداشت جدید'),
        content: TextField(controller: t, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              if (t.text.trim().isNotEmpty) {
                (a.ud['notes'] as List).insert(0, t.text.trim());
                a.persist();
              }
              Navigator.pop(d);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final notes = (a.ud['notes'] as List).cast<String>();
    final shown = notes.where((n) => n.contains(q)).toList();
    return Frame('یادداشت‌ها', child: Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جست‌وجو در یادداشت‌ها')),
        const SizedBox(height: 12),
        if (shown.isEmpty) const EmptyBox('یادداشتی نیست. با دکمه‌ی + اولین یادداشت را بنویسید.'),
        for (final n in shown)
          Glass(child: Row(children: [
            Expanded(child: Text(n)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kRed),
              onPressed: () async {
                if (await confirmDelete(c, 'این یادداشت')) {
                  (a.ud['notes'] as List).remove(n);
                  a.persist();
                }
              },
            ),
          ])),
      ]),
      Positioned(bottom: 20, left: 20, child: FloatingActionButton(onPressed: add, child: const Icon(Icons.add))),
    ]));
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final al = a.ud['alerts'] as Map;
    return Frame('هشدارهای هوشمند', child: ListView(padding: const EdgeInsets.all(16), children: [
      Glass(padding: EdgeInsets.zero, child: SwitchListTile(title: const Text('نمایش اعلان‌ها'), value: a.notifOn, onChanged: (v) => a.update(() => a.notifOn = v))),
      Glass(padding: EdgeInsets.zero, child: SwitchListTile(title: const Text('هشدار افزایش غیرعادی مصرف (بیش از ۳۰٪ نسبت به ماه قبل)'), value: al['افزایش مصرف'] == true, onChanged: (v) { al['افزایش مصرف'] = v; a.persist(); })),
      Glass(padding: EdgeInsets.zero, child: SwitchListTile(title: const Text('یادآوری قبض‌های پرداخت‌نشده'), value: al['موعد پرداخت قبض'] == true, onChanged: (v) { al['موعد پرداخت قبض'] = v; a.persist(); })),
    ]));
  }
}

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportState();
}

class _SupportState extends State<SupportPage> {
  String type = 'گزارش خرابی';
  final t = TextEditingController();
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final sent = (a.ud['support'] as List).cast<Map>();
    return Frame('پشتیبانی', child: ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: type,
            items: [for (final e in ['گزارش خرابی', 'قطعی برق', 'سؤال یا پیشنهاد']) DropdownMenuItem(value: e, child: Text(e))],
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          TextField(controller: t, maxLines: 4, decoration: const InputDecoration(labelText: 'توضیحات')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (t.text.trim().isEmpty) return toast(c, 'توضیحات را بنویسید.');
              (a.ud['support'] as List).insert(0, {'type': type, 't': t.text.trim(), 'd': DateTime.now().toIso8601String()});
              a.log('ثبت درخواست پشتیبانی');
              a.persist();
              t.clear();
              toast(c, 'درخواست برای مدیر ثبت شد.');
            },
            child: const Text('ثبت درخواست'),
          ),
        ]),
      ),
      for (final s in sent) Glass(child: Row(children: [const Icon(Icons.hourglass_top, color: kYellow), const SizedBox(width: 10), Expanded(child: Text('${s['type']}: ${s['t']}\n${jDate(DateTime.parse(s['d']))}', style: Theme.of(c).textTheme.bodySmall))])),
      Glass(child: Row(children: [const Icon(Icons.power_off_outlined, color: kRed), const SizedBox(width: 10), Expanded(child: Text('اطلاعیه‌ی قطعی برق: منبع رسمی هنوز متصل نیست؛ اطلاعیه‌های رسمی فقط از طریق مدیر منتشر می‌شوند.', style: Theme.of(c).textTheme.bodySmall))])),
    ]));
  }
}

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    const colors = [kBlue, kRed, Color(0xFF16A34A), Color(0xFF7C3AED), Color(0xFFEA7A1E)];
    return Frame('شخصی‌سازی', child: ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'auto', label: Text('خودکار')), ButtonSegment(value: 'light', label: Text('روشن')), ButtonSegment(value: 'dark', label: Text('تاریک'))],
            selected: {a.themePref},
            onSelectionChanged: (s) => a.update(() { a.themePref = s.first; a.savePrefs(); }),
          ),
          const SizedBox(height: 16),
          const Text('رنگ اصلی', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            for (final k in colors)
              GestureDetector(
                onTap: () => a.update(() { a.seed = k; a.savePrefs(); }),
                child: CircleAvatar(backgroundColor: k, radius: 18, child: a.seed.value == k.value ? const Icon(Icons.check, color: Colors.white) : null),
              ),
          ]),
          const SizedBox(height: 16),
          Text('اندازه‌ی نوشته: ${fa(a.scale * 100)}٪', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(value: a.scale, min: .85, max: 1.3, onChanged: (v) => a.update(() => a.scale = v), onChangeEnd: (_) => a.savePrefs()),
        ]),
      ),
    ]));
  }
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});
  @override
  State<PasswordPage> createState() => _PasswordState();
}

class _PasswordState extends State<PasswordPage> {
  final o = TextEditingController(), n = TextEditingController();
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    return Frame('تغییر رمز عبور', child: ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(children: [
          TextField(controller: o, obscureText: true, decoration: const InputDecoration(labelText: 'رمز فعلی')),
          const SizedBox(height: 12),
          TextField(controller: n, obscureText: true, decoration: const InputDecoration(labelText: 'رمز جدید (حداقل ۶ کاراکتر)')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final e = a.changePassword(o.text, n.text);
              toast(c, e ?? 'رمز تغییر کرد.');
              if (e == null) Navigator.pop(c);
            },
            child: const Text('ذخیره'),
          ),
        ]),
      ),
    ]));
  }
}

String fmtLog(Map e) {
  final d = DateTime.tryParse(e['t'] ?? '');
  return d == null ? '' : '${jDate(d)}  ${fa(d.hour)}:${fa(d.minute).padLeft(2, '۰')}';
}

class MyLogPage extends StatelessWidget {
  const MyLogPage({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final mine = a.logs.cast<Map>().where((e) => e['who'] == a.name).toList();
    return Frame('سوابق فعالیت من', child: ListView(padding: const EdgeInsets.all(16), children: [
      if (mine.isEmpty) const EmptyBox('سابقه‌ای نیست.'),
      for (final e in mine.take(100)) ListTile(dense: true, leading: const Icon(Icons.history, size: 18), title: Text('${e['w']}'), subtitle: Text(fmtLog(e))),
    ]));
  }
}
