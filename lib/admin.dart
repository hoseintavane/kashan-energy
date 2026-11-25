import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'more.dart' show fmtLog;
import 'state.dart';
import 'ui.dart';

/// ===== پنل مدیریت (کاملاً جدا از برنامه‌ی کاربر) =====
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    const titles = ['نمای کلی', 'کاربران', 'سوابق تغییرات', 'API و پشتیبان'];
    final pages = [const AdminOverview(), const AdminUsers(), const AdminLog(), const AdminSettings()];
    return Bg(
      child: Scaffold(
        appBar: AppBar(title: Text('مدیریت - ${titles[a.tab]}'), actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'خروج', onPressed: a.logout)]),
        body: KeyedSubtree(key: ValueKey(a.tab), child: pages[a.tab.clamp(0, 3)]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: a.tab.clamp(0, 3),
          onDestinationSelected: (i) => a.update(() => a.tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'نمای کلی'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'کاربران'),
            NavigationDestination(icon: Icon(Icons.history), label: 'سوابق'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'تنظیمات'),
          ],
        ),
      ),
    );
  }
}

Iterable<Map> _userData(AppState a) => a.users.values.map((u) => (u['data'] ?? {}) as Map);

class AdminOverview extends StatefulWidget {
  const AdminOverview({super.key});
  @override
  State<AdminOverview> createState() => _OverviewState();
}

class _OverviewState extends State<AdminOverview> {
  final ann = TextEditingController();
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final pending = <(String, Map)>[];
    final support = <(String, Map)>[];
    var readings = 0;
    a.users.forEach((n, u) {
      final d = (u['data'] ?? {}) as Map;
      for (final b in ((d['bills'] ?? []) as List).cast<Map>()) {
        if (b['status'] == 'در انتظار تأیید') pending.add((n, b));
      }
      for (final s in ((d['support'] ?? []) as List).cast<Map>()) {
        support.add((n, s));
      }
      readings += ((d['readings'] ?? []) as List).length;
    });
    Widget stat(String t, int v, Color col) => Expanded(child: Glass(child: Column(children: [Text(fa(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: col)), Text(t, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)])));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Row(children: [stat('کاربران', a.users.length, kBlue), const SizedBox(width: 8), stat('رسید در انتظار', pending.length, kYellow), const SizedBox(width: 8), stat('قرائت‌های ثبت‌شده', readings, kRed)]),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('انتشار اطلاعیه برای کاربران', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: ann, decoration: const InputDecoration(labelText: 'متن اطلاعیه')),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              if (ann.text.trim().isEmpty) return toast(c, 'متن اطلاعیه را بنویسید.');
              a.anns.insert(0, {'id': DateTime.now().millisecondsSinceEpoch, 't': ann.text.trim()});
              a.log('انتشار اطلاعیه');
              a.persist();
              ann.clear();
              toast(c, 'اطلاعیه منتشر شد.');
            },
            child: const Text('انتشار'),
          ),
          for (final x in a.anns.cast<Map>())
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${x['t']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: kRed),
                onPressed: () async {
                  if (await confirmDelete(c, 'این اطلاعیه')) {
                    a.anns.remove(x);
                    a.log('حذف اطلاعیه');
                    a.persist();
                  }
                },
              ),
            ),
        ]),
      ),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('بررسی رسیدها', style: TextStyle(fontWeight: FontWeight.bold)),
          if (pending.isEmpty) const EmptyBox('رسیدی در انتظار تأیید نیست.', icon: Icons.verified_outlined),
          for (final p in pending)
            Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p.$2['title']} (${p.$1})'),
                subtitle: Text('${fa(p.$2['amount'] as num)} تومان'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check_circle, color: kBlue), onPressed: () { p.$2['status'] = 'پرداخت‌شده'; a.log('تأیید رسید «${p.$2['title']}» کاربر ${p.$1}'); a.persist(); }),
                  IconButton(icon: const Icon(Icons.cancel, color: kRed), onPressed: () { p.$2['status'] = 'پرداخت‌نشده'; p.$2['receipt'] = null; a.log('رد رسید «${p.$2['title']}» کاربر ${p.$1}'); a.persist(); }),
                ]),
              ),
              if (p.$2['receipt'] != null && File(p.$2['receipt']).existsSync())
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(p.$2['receipt']), height: 140, fit: BoxFit.cover)),
            ]),
        ]),
      ),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('درخواست‌های پشتیبانی', style: TextStyle(fontWeight: FontWeight.bold)),
          if (support.isEmpty) const EmptyBox('درخواستی ثبت نشده است.'),
          for (final s in support.take(30)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${s.$2['type']} - ${s.$1}'), subtitle: Text('${s.$2['t']}')),
        ]),
      ),
    ]);
  }
}

class AdminUsers extends StatelessWidget {
  const AdminUsers({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final names = a.users.keys.toList()..sort();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('برای حفظ حریم خصوصی، فقط نام کاربری و وضعیت حساب نمایش داده می‌شود؛ داده‌ی مصرف و رمز کاربران برای مدیر قابل مشاهده نیست.', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      if (names.isEmpty) const EmptyBox('کاربری ثبت‌نام نکرده است.', icon: Icons.people_outline),
      for (final n in names)
        Glass(
          child: Row(children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(n + (a.users[n]['disabled'] == true ? '  (غیرفعال)' : ''))),
            Switch(
              value: a.users[n]['disabled'] != true,
              onChanged: (v) async {
                if (!await reauth(c, 'تغییر وضعیت حساب «$n»')) return;
                a.users[n]['disabled'] = !v;
                a.log('${v ? 'فعال' : 'غیرفعال'}‌سازی کاربر $n');
                a.persist();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kRed),
              onPressed: () async {
                if (!await reauth(c, 'حذف کاربر «$n» و تمام اطلاعات او')) return;
                if (!c.mounted || !await confirmDelete(c, 'کاربر $n و تمام اطلاعاتش')) return;
                a.users.remove(n);
                a.log('حذف کاربر $n');
                a.persist();
              },
            ),
          ]),
        ),
    ]);
  }
}

class AdminLog extends StatelessWidget {
  const AdminLog({super.key});
  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final l = a.logs.cast<Map>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (l.isEmpty) const EmptyBox('سابقه‌ای ثبت نشده است.', icon: Icons.history),
      for (final e in l.take(200)) ListTile(dense: true, leading: Icon(e['who'] == 'مدیر' ? Icons.admin_panel_settings : Icons.person_outline, size: 18), title: Text('${e['w']}'), subtitle: Text('${e['who']} • ${fmtLog(e)}')),
    ]);
  }
}

/// ترجمه‌ی خطاهای اتصال به فارسی
String apiError(Object e) {
  if (e is TimeoutException) return 'مهلت اتصال به سرور تمام شد.';
  if (e is HandshakeException || e is TlsException) return 'گواهی امنیتی سرور معتبر نیست.';
  if (e is SocketException) return 'اتصال به سرور برقرار نشد؛ اینترنت یا نشانی را بررسی کنید.';
  if (e is HttpException) return 'پاسخ نامعتبر از سرور دریافت شد.';
  return 'خطای ناشناخته در اتصال: ${e.runtimeType}';
}

/// اعتبارسنجی نشانی و کلید و تست واقعی اتصال. null یعنی موفق.
Future<String?> validateApi(String url, String key) async {
  final u = Uri.tryParse(url.trim());
  if (u == null || u.scheme != 'https' || u.host.isEmpty) return 'نشانی باید معتبر باشد و با https شروع شود.';
  if (key.trim().length < 8) return 'کلید API بسیار کوتاه یا نامعتبر است.';
  final cl = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final rq = await cl.getUrl(u).timeout(const Duration(seconds: 10));
    rq.headers.set('Authorization', 'Bearer ${key.trim()}');
    final rs = await rq.close().timeout(const Duration(seconds: 10));
    await rs.drain();
    if (rs.statusCode == 401 || rs.statusCode == 403) return 'کلید API نامعتبر است یا دسترسی ندارد.';
    if (rs.statusCode >= 400) return 'سرور خطا برگرداند (کد ${fa(rs.statusCode)}).';
    return null;
  } catch (e) {
    return apiError(e);
  } finally {
    cl.close(force: true);
  }
}

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});
  @override
  State<AdminSettings> createState() => _SettingsState();
}

class _SettingsState extends State<AdminSettings> {
  bool hasKey = false, busy = false;
  @override
  void initState() {
    super.initState();
    context.getInheritedWidgetOfExactType<Scope>()!.notifier!.store.readApiKey().then((k) {
      if (mounted) setState(() => hasKey = k != null);
    }).catchError((_) {});
  }

  Future<void> editApi() async {
    final a = Scope.of(context);
    if (!await reauth(context, 'ثبت یا تغییر API')) return;
    if (!mounted) return;
    final u = TextEditingController(text: '${a.db['apiUrl'] ?? ''}'), k = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('اتصال API'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: u, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'نشانی (https://...)')),
          TextField(controller: k, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'کلید API')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('بررسی و ذخیره')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => busy = true);
    final err = await validateApi(u.text, k.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) return toast(context, 'اتصال برقرار نشد: $err');
    await a.store.writeApiKey(k.text.trim());
    a.db['apiUrl'] = u.text.trim();
    a.log('ثبت/تغییر API');
    await a.persist();
    if (mounted) {
      setState(() => hasKey = true);
      toast(context, 'اتصال موفق بود و ذخیره شد.');
    }
  }

  Future<void> removeApi() async {
    final a = Scope.of(context);
    if (!await reauth(context, 'حذف API')) return;
    if (!mounted || !await confirmDelete(context, 'تنظیمات API')) return;
    await a.store.writeApiKey(null);
    a.db.remove('apiUrl');
    a.log('حذف API');
    await a.persist();
    if (mounted) setState(() => hasKey = false);
  }

  Future<void> backup() async {
    final a = Scope.of(context);
    final pw = await reauthPw(context, 'ساخت پشتیبان (با همین رمز رمزنگاری می‌شود)');
    if (pw == null || !mounted) return;
    try {
      final text = a.store.exportBackup(a.db, pw);
      await Clipboard.setData(ClipboardData(text: text));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/kashan_backup_${DateTime.now().millisecondsSinceEpoch}.kbk');
      await f.writeAsString(text);
      a.log('ساخت پشتیبان');
      a.persist();
      if (mounted) toast(context, 'پشتیبان در کلیپ‌بورد کپی شد.');
      await Share.shareXFiles([XFile(f.path)]);
    } catch (_) {
      if (mounted) toast(context, 'ساخت پشتیبان ناموفق بود.');
    }
  }

  Future<void> restore() async {
    final a = Scope.of(context);
    final pw = await reauthPw(context, 'بازیابی اطلاعات از پشتیبان');
    if (pw == null || !mounted) return;
    final t = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('بازیابی'),
        content: TextField(controller: t, maxLines: 4, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'متن پشتیبان را اینجا جای‌گذاری کنید')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('بازیابی')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final data = a.store.importBackup(t.text, pw);
    if (data == null || data['users'] == null) return toast(context, 'پشتیبان نامعتبر است یا با این رمز رمزنگاری نشده.');
    if (!await confirmDelete(context, 'اطلاعات فعلی (جایگزین پشتیبان می‌شود)')) return;
    a.db = data;
    a.db.putIfAbsent('log', () => <dynamic>[]);
    a.db.putIfAbsent('ann', () => <dynamic>[]);
    a.db.putIfAbsent('lock', () => <String, dynamic>{});
    a.log('بازیابی از پشتیبان');
    await a.persist();
    if (mounted) toast(context, 'اطلاعات بازیابی شد.');
  }

  @override
  Widget build(BuildContext c) {
    final a = Scope.of(c);
    final url = a.db['apiUrl'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مدیریت API', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(hasKey && url != null ? 'متصل: $url\nکلید: ذخیره‌شده و محافظت‌شده (نمایش داده نمی‌شود)' : 'API ثبت نشده است؛ بنابراین هیچ داده‌ی آنلاینی نمایش داده نمی‌شود.'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: busy ? null : editApi, child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(hasKey ? 'تغییر' : 'ثبت API')),
            if (hasKey) OutlinedButton(onPressed: removeApi, child: const Text('حذف')),
          ]),
        ]),
      ),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('پشتیبان‌گیری و بازیابی', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('پشتیبان شامل اطلاعات تمام کاربران است و با رمز مدیر رمزنگاری می‌شود. نسخه‌ی خودکار قبلی نیز در هر ذخیره نگه داشته می‌شود.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: backup, icon: const Icon(Icons.backup), label: const Text('ساخت پشتیبان')),
            OutlinedButton.icon(onPressed: restore, icon: const Icon(Icons.restore), label: const Text('بازیابی')),
          ]),
        ]),
      ),
    ]);
  }
}
