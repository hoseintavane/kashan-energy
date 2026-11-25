import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===== محتوای ثابت (آموزشی/ابزاری؛ نه آمار) =====
const presets = {
  'کولر آبی': 250.0, 'کولر گازی': 1200.0, 'یخچال': 150.0, 'لامپ LED': 10.0,
  'تلویزیون': 100.0, 'لباسشویی': 500.0, 'بخاری برقی': 1500.0,
};
// عنوان، توضیح، تعداد روز لازم
const challenges = [
  ('۱۰٪ کاهش در یک ماه', 'مصرف این ماه را ۱۰٪ زیر ماه قبل نگه دارید. هر روز که پایبند بودید ثبت کنید.', 30),
  ('لامپ‌های بی‌استفاده خاموش', 'یک هفته هیچ لامپ روشنی در اتاق خالی نماند.', 7),
  ('دوری از ساعت اوج', 'بین ساعت ۱۲ تا ۱۶ وسایل پرمصرف را روشن نکنید.', 14),
];
const lessons = {
  'کاهش مصرف انرژی': [
    'دمای کولر گازی را روی ۲۴ تا ۲۶ درجه تنظیم کنید.',
    'لامپ‌های رشته‌ای را با LED عوض کنید.',
    'وسایل را در حالت آماده‌به‌کار نگذارید و از چندراهی کلیددار استفاده کنید.',
  ],
  'نکات کاربردی صرفه‌جویی': [
    'در تابستان پنجره‌ها را در ساعات گرم روز ببندید و شب هوا را تهویه کنید.',
    'درِ یخچال را زیاد باز نگذارید و غذای گرم را داخل آن نگذارید.',
    'لباسشویی را با بار کامل و آب سرد روشن کنید.',
  ],
  'انرژی و محیط زیست': [
    'تولید برق از سوخت‌های فسیلی گازهای گلخانه‌ای تولید می‌کند.',
    'کاهش مصرف یعنی فشار کمتر بر شبکه و خاموشی کمتر.',
    'انرژی خورشیدی برای اقلیم آفتابیِ کاشان گزینه‌ی مناسبی است.',
  ],
};

const jMonths = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];

String fa(num n, {int d = 0}) {
  final p = n.toStringAsFixed(d).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '٬');
  final s = p.length > 1 ? '$i٫${p[1]}' : i;
  const e = '0123456789', f = '۰۱۲۳۴۵۶۷۸۹';
  return s.split('').map((c) {
    final k = e.indexOf(c);
    return k < 0 ? c : f[k];
  }).join();
}

/// تبدیل تاریخ میلادی به شمسی → [سال، ماه، روز]
List<int> toJalali(DateTime d) {
  const g = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = d.month > 2 ? d.year + 1 : d.year;
  var days = 355666 + (365 * d.year) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) + d.day + g[d.month - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

String jDate(DateTime d) {
  final j = toJalali(d);
  return '${fa(j[0])}/${fa(j[1])}/${fa(j[2])}';
}

/// ===== رمزنگاری و هش =====
// رمز مدیر هرگز به‌صورت متن ساده در برنامه نیست؛ فقط نمک و هش PBKDF2-SHA256 (۲۰هزار دور).
// توجه: هش داخل APK با تلاش آفلاین قابل حدس‌زدن است؛ امنیت واقعی نیازمند اعتبارسنجی سمت سرور است.
const kAdminSalt = '6U7JQjnEzqxIJ/qNfW1+rA==';
const kAdminHash = 'POn5epJpLD9lkdU8hAxqItDTYvD3RMaZoT10BD4y5oU=';
const kIter = 20000;

List<int> pbkdf2(String pw, List<int> salt, int iters) {
  final h = Hmac(sha256, utf8.encode(pw));
  var u = h.convert([...salt, 0, 0, 0, 1]).bytes;
  final t = List<int>.from(u);
  for (var i = 1; i < iters; i++) {
    u = h.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var r = 0;
  for (var i = 0; i < a.length; i++) {
    r |= a[i] ^ b[i];
  }
  return r == 0;
}

List<int> _rnd(int n) => List<int>.generate(n, (_) => Random.secure().nextInt(256));
bool verifyPw(String pw, String saltB64, String hashB64) =>
    _eq(pbkdf2(pw, base64.decode(saltB64), kIter), base64.decode(hashB64));

/// ===== ذخیره‌ی رمزنگاری‌شده (AES-256) با پشتیبان خودکار =====
class Store {
  static const _kData = 'db_v2', _kBak = 'db_bak', _kKey = 'db_key', _kApi = 'api_key';
  final _ss = const FlutterSecureStorage();
  late SharedPreferences sp;
  late enc.Key _key;
  bool recovered = false; // اگر داده خراب بود و نسخه‌ی خراب نگه‌داری شد

  Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    var k = await _ss.read(key: _kKey);
    if (k == null) {
      k = base64.encode(_rnd(32));
      await _ss.write(key: _kKey, value: k);
    }
    _key = enc.Key(Uint8List.fromList(base64.decode(k)));
  }

  /// AES-256-GCM (رمزنگاری + تشخیص دستکاری). خواندن قالب قدیمی CBC هم پشتیبانی می‌شود.
  String _enc(String plain, enc.Key key) {
    final iv = enc.IV(Uint8List.fromList(_rnd(12)));
    final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return '${iv.base64}:${e.encrypt(plain, iv: iv).base64}';
  }

  String _dec(String s, enc.Key key) {
    final p = s.split(':');
    final iv = enc.IV.fromBase64(p[0]);
    final mode = iv.bytes.length == 12 ? enc.AESMode.gcm : enc.AESMode.cbc;
    return enc.Encrypter(enc.AES(key, mode: mode)).decrypt64(p[1], iv: iv);
  }

  Map<String, dynamic>? _try(String k) {
    final raw = sp.getString(k);
    if (raw == null) return null;
    try {
      return jsonDecode(_dec(raw, _key)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> load() {
    final main = _try(_kData);
    if (main != null) return main;
    final bak = _try(_kBak);
    if (bak != null) return bak;
    if (sp.getString(_kData) != null) {
      // داده وجود دارد ولی خوانده نشد: نسخه‌ی خراب را پاک نمی‌کنیم
      sp.setString('db_corrupt_${DateTime.now().millisecondsSinceEpoch}', sp.getString(_kData)!);
      recovered = true;
    }
    return {};
  }

  Future<void> save(Map<String, dynamic> db) async {
    final cur = sp.getString(_kData);
    if (cur != null) await sp.setString(_kBak, cur);
    await sp.setString(_kData, _enc(jsonEncode(db), _key));
  }

  /// فایل پشتیبان با رمز مدیر رمزنگاری می‌شود و روی هر دستگاه قابل بازیابی است.
  String exportBackup(Map<String, dynamic> db, String pass) {
    final salt = _rnd(16);
    final k = enc.Key(Uint8List.fromList(pbkdf2(pass, salt, kIter)));
    return 'KB1:${base64.encode(salt)}:${_enc(jsonEncode(db), k)}';
  }

  Map<String, dynamic>? importBackup(String text, String pass) {
    try {
      final p = text.trim().split(':');
      if (p.length != 4 || p[0] != 'KB1') return null;
      final k = enc.Key(Uint8List.fromList(pbkdf2(pass, base64.decode(p[1]), kIter)));
      return jsonDecode(_dec('${p[2]}:${p[3]}', k)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> readApiKey() => _ss.read(key: _kApi);
  Future<void> writeApiKey(String? v) => v == null ? _ss.delete(key: _kApi) : _ss.write(key: _kApi, value: v);
}

/// ===== محاسبات مصرف از قرائت‌های واقعی کنتور =====
class Period {
  final List<String> labels;
  final List<double> values;
  final List<bool> has; // آیا برای این بازه داده وجود دارد
  Period(this.labels, this.values, this.has);
  bool get any => has.any((e) => e);
}

DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

/// مصرف هر روز: اختلاف دو قرائت پیاپی به‌طور مساوی بین روزهای بازه پخش می‌شود.
Map<DateTime, double> dailyUsage(List<dynamic> readings) {
  final r = [...readings]..sort((a, b) => (a['d'] as String).compareTo(b['d'] as String));
  final out = <DateTime, double>{};
  for (var i = 1; i < r.length; i++) {
    final d0 = day(DateTime.parse(r[i - 1]['d'])), d1 = day(DateTime.parse(r[i]['d']));
    final diff = (r[i]['v'] as num).toDouble() - (r[i - 1]['v'] as num).toDouble();
    final n = d1.difference(d0).inDays;
    if (n <= 0 || diff < 0) continue;
    for (var k = 1; k <= n; k++) {
      out[d0.add(Duration(days: k))] = diff / n;
    }
  }
  return out;
}

Period periodOf(Map<DateTime, double> u, int mode) {
  final today = day(DateTime.now());
  final labels = <String>[], vals = <double>[], has = <bool>[];
  if (mode == 0) {
    // ۷ روز اخیر
    const wd = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      labels.add(wd[d.weekday - 1]);
      vals.add(u[d] ?? 0);
      has.add(u.containsKey(d));
    }
  } else if (mode == 1) {
    // ۸ هفته‌ی اخیر
    for (var w = 7; w >= 0; w--) {
      var s = 0.0, h = false;
      for (var i = 0; i < 7; i++) {
        final d = today.subtract(Duration(days: w * 7 + i));
        if (u.containsKey(d)) {
          s += u[d]!;
          h = true;
        }
      }
      labels.add(fa(8 - w));
      vals.add(s);
      has.add(h);
    }
  } else if (mode == 2) {
    // ۱۲ ماه شمسی اخیر
    final j = toJalali(today);
    var y = j[0], m = j[1];
    final keys = <int>[];
    for (var i = 0; i < 12; i++) {
      keys.insert(0, y * 12 + (m - 1));
      m--;
      if (m == 0) {
        m = 12;
        y--;
      }
    }
    final sums = <int, double>{};
    for (final e in u.entries) {
      final jj = toJalali(e.key);
      final k = jj[0] * 12 + (jj[1] - 1);
      sums[k] = (sums[k] ?? 0) + e.value;
    }
    for (final k in keys) {
      labels.add(jMonths[k % 12].substring(0, min(3, jMonths[k % 12].length)));
      vals.add(sums[k] ?? 0);
      has.add(sums.containsKey(k));
    }
  } else {
    final sums = <int, double>{};
    for (final e in u.entries) {
      final y = toJalali(e.key)[0];
      sums[y] = (sums[y] ?? 0) + e.value;
    }
    final ys = sums.keys.toList()..sort();
    for (final y in ys) {
      labels.add(fa(y));
      vals.add(sums[y]!);
      has.add(true);
    }
  }
  return Period(labels, vals, has);
}

/// ===== وضعیت برنامه =====
class AppState extends ChangeNotifier {
  final Store store;
  Map<String, dynamic> db;
  AppState(this.store) : db = store.load() {
    db.putIfAbsent('users', () => <String, dynamic>{});
    db.putIfAbsent('log', () => <dynamic>[]);
    db.putIfAbsent('ann', () => <dynamic>[]);
    db.putIfAbsent('lock', () => <String, dynamic>{});
    final p = store.sp;
    themePref = p.getString('themePref') ?? 'auto';
    seed = Color(p.getInt('seed') ?? 0xFF2463EB);
    scale = p.getDouble('scale') ?? 1.0;
    onboarded = p.getBool('onboarded') ?? false;
    _t = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
    // ورود کاربر با بستن برنامه نمی‌پرد (مدیر هرگز ذخیره نمی‌شود)
    final ss = p.getString('session');
    if (ss != null && users[ss] != null && users[ss]['disabled'] != true) {
      name = ss;
      signedIn = true;
    }
  }

  String themePref = 'auto';
  Color seed = const Color(0xFF2463EB);
  double scale = 1.0;
  bool onboarded = false;
  bool signedIn = false, isAdmin = false, notifOn = true;
  String name = '';
  int tab = 0, toolsTab = 0;
  late final Timer _t;

  bool get dark {
    if (themePref == 'auto') {
      final h = DateTime.now().hour;
      return h < 6 || h >= 18;
    }
    return themePref == 'dark';
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }

  void savePrefs() {
    store.sp.setString('themePref', themePref);
    store.sp.setInt('seed', seed.value);
    store.sp.setDouble('scale', scale);
    store.sp.setBool('onboarded', onboarded);
  }

  Future<void> persist() async {
    try {
      await store.save(db);
    } catch (_) {}
    notifyListeners();
  }

  Map<String, dynamic> get users => db['users'] as Map<String, dynamic>;
  Map<String, dynamic> get ud {
    final d = (users[name]['data'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    d.putIfAbsent('readings', () => <dynamic>[]);
    d.putIfAbsent('bills', () => <dynamic>[]);
    d.putIfAbsent('notes', () => <dynamic>[]);
    d.putIfAbsent('joined', () => <String, dynamic>{});
    d.putIfAbsent('dismissed', () => <dynamic>[]);
    d.putIfAbsent('support', () => <dynamic>[]);
    d.putIfAbsent('alerts', () => <String, dynamic>{'افزایش مصرف': true, 'موعد پرداخت قبض': true});
    return d;
  }

  List get readings => ud['readings'] as List;
  List get bills => ud['bills'] as List;
  List get anns => db['ann'] as List;
  List get logs => db['log'] as List;

  void log(String what) {
    logs.insert(0, {'t': DateTime.now().toIso8601String(), 'who': isAdmin ? 'مدیر' : name, 'w': what});
    if (logs.length > 500) logs.removeRange(500, logs.length);
  }

  // ---- ورود و محدودیت تلاش ----
  /// ثانیه‌های باقی‌مانده از قفل، یا 0
  int lockLeft(String key) {
    final l = (db['lock'] as Map)[key];
    if (l == null) return 0;
    final until = DateTime.tryParse(l['until'] ?? '');
    if (until == null) return 0;
    final s = until.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  void _fail(String key) {
    final m = db['lock'] as Map;
    final l = (m[key] ??= <String, dynamic>{'n': 0}) as Map;
    l['n'] = (l['n'] as int) + 1;
    if (l['n'] >= 5) {
      l['n'] = 0;
      l['until'] = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      log('قفل موقت ورود برای «$key» پس از ۵ تلاش ناموفق');
    }
    persist();
  }

  void _ok(String key) {
    (db['lock'] as Map).remove(key);
  }

  String _lockMsg(int s) => 'تعداد تلاش‌های ناموفق زیاد بود. ${fa((s / 60).ceil())} دقیقه‌ی دیگر دوباره تلاش کنید.';

  /// null یعنی موفق؛ در غیر این صورت پیام خطا به فارسی
  String? userLogin(String u, String p) {
    final k = 'u:$u';
    final s = lockLeft(k);
    if (s > 0) return _lockMsg(s);
    final rec = users[u];
    if (rec == null || !verifyPw(p, rec['salt'], rec['hash'])) {
      _fail(k);
      return 'نام کاربری یا رمز اشتباه است.';
    }
    if (rec['disabled'] == true) return 'این حساب توسط مدیر غیرفعال شده است.';
    _ok(k);
    isAdmin = false;
    name = u;
    signedIn = true;
    tab = 0;
    store.sp.setString('session', u);
    log('ورود کاربر');
    persist();
    return null;
  }

  String? register(String u, String p) {
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(u)) return 'نام کاربری باید ۳ تا ۲۰ حرف انگلیسی، عدد یا _ باشد.';
    if (u.toLowerCase() == 'admin') return 'این نام کاربری مجاز نیست.';
    if (p.length < 6) return 'رمز عبور حداقل ۶ کاراکتر باشد.';
    if (users.containsKey(u)) return 'این نام کاربری قبلاً ثبت شده است.';
    final salt = _rnd(16);
    users[u] = {
      'salt': base64.encode(salt),
      'hash': base64.encode(pbkdf2(p, salt, kIter)),
      'created': DateTime.now().toIso8601String(),
      'disabled': false,
      'data': <String, dynamic>{},
    };
    isAdmin = false;
    name = u;
    signedIn = true;
    tab = 0;
    store.sp.setString('session', u);
    log('ثبت‌نام کاربر جدید');
    persist();
    return null;
  }

  /// بررسی رمز مدیر (برای ورود و تأیید هویت عملیات حساس)
  String? checkAdmin(String p) {
    final s = lockLeft('admin');
    if (s > 0) return _lockMsg(s);
    if (!verifyPw(p, kAdminSalt, kAdminHash)) {
      _fail('admin');
      return 'رمز مدیریت نادرست است.';
    }
    _ok('admin');
    return null;
  }

  String? adminLogin(String p) {
    final e = checkAdmin(p);
    if (e != null) return e;
    store.sp.remove('session');
    isAdmin = true;
    name = 'مدیر';
    signedIn = true;
    tab = 0;
    log('ورود مدیر');
    persist();
    return null;
  }

  String? changePassword(String oldP, String newP) {
    final rec = users[name];
    if (!verifyPw(oldP, rec['salt'], rec['hash'])) return 'رمز فعلی اشتباه است.';
    if (newP.length < 6) return 'رمز جدید حداقل ۶ کاراکتر باشد.';
    final salt = _rnd(16);
    rec['salt'] = base64.encode(salt);
    rec['hash'] = base64.encode(pbkdf2(newP, salt, kIter));
    log('تغییر رمز عبور');
    persist();
    return null;
  }

  void logout() {
    store.sp.remove('session');
    log('خروج');
    persist();
    update(() {
      signedIn = false;
      isAdmin = false;
      name = '';
      tab = 0;
    });
  }

  /// اعلان‌ها: هشدارهای محاسبه‌شده از داده‌ی واقعی + اطلاعیه‌های مدیر
  List<String> notifications() {
    if (!signedIn || isAdmin) return [];
    final out = <String>[];
    final al = ud['alerts'] as Map;
    if (al['افزایش مصرف'] == true) {
      final p = periodOf(dailyUsage(readings), 2);
      final n = p.values.length;
      if (n >= 2 && p.has[n - 1] && p.has[n - 2] && p.values[n - 2] > 0 && p.values[n - 1] > p.values[n - 2] * 1.3) {
        out.add('هشدار: مصرف این ماه بیش از ۳۰٪ نسبت به ماه قبل افزایش یافته است.');
      }
    }
    if (al['موعد پرداخت قبض'] == true) {
      final n = bills.where((b) => b['status'] == 'پرداخت‌نشده').length;
      if (n > 0) out.add('${fa(n)} قبض پرداخت‌نشده دارید.');
    }
    final dis = (ud['dismissed'] as List);
    for (final a in anns) {
      if (!dis.contains(a['id'])) out.add('اطلاعیه: ${a['t']}');
    }
    return out;
  }

  void clearNotifs() {
    final dis = (ud['dismissed'] as List);
    for (final a in anns) {
      if (!dis.contains(a['id'])) dis.add(a['id']);
    }
    persist();
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }
}

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState super.notifier, required super.child});
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}
