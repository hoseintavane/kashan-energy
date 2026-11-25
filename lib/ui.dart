import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'state.dart';

const kBlue = Color(0xFF2463EB);
const kRed = Color(0xFFE5484D);
const kYellow = Color(0xFFF5C84C);
const kSilver = Color(0xFFF2F4F7);

void push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

class Bg extends StatelessWidget {
  final Widget child;
  const Bg({super.key, required this.child});
  @override
  Widget build(BuildContext c) => AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark(c)
                ? const [Color(0xFF0A1020), Color(0xFF12214A), Color(0xFF0A1020)]
                : const [Color(0xFFFFFFFF), Color(0xFFE8EEFB), kSilver],
          ),
        ),
        child: child,
      );
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? tint;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.tint});
  @override
  Widget build(BuildContext c) {
    final d = isDark(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? (d ? Colors.white.withOpacity(.07) : Colors.white),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: d ? Colors.white.withOpacity(.1) : const Color(0xFFE4E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(d ? .25 : .06), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// صفحه‌ی داخلی با پس‌زمینه و نوار عنوان
class Frame extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const Frame(this.title, {super.key, required this.child, this.actions});
  @override
  Widget build(BuildContext c) => Bg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(title), actions: actions),
          body: child,
        ),
      );
}

/// پیام خالی بودن داده (به‌جای نمایش آمار ساختگی)
class EmptyBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyBox(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: Colors.grey),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
        ])),
      );
}

void toast(BuildContext c, String m) {
  final s = ScaffoldMessenger.maybeOf(c);
  s?.hideCurrentSnackBar();
  s?.showSnackBar(SnackBar(content: Text(m)));
}

/// تأیید هویت مدیر قبل از عملیات حساس
Future<String?> reauthPw(BuildContext c, String why) async {
  final a = Scope.of(c);
  final t = TextEditingController();
  String? err;
  final ok = await showDialog<String>(
    context: c,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('تأیید هویت مدیر'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(why),
          const SizedBox(height: 10),
          TextField(controller: t, obscureText: true, decoration: InputDecoration(labelText: 'رمز مدیریت', errorText: err)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final e = a.checkAdmin(t.text);
              if (e == null) {
                Navigator.pop(d, t.text);
              } else {
                set(() => err = e);
              }
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    ),
  );
  return ok;
}

Future<bool> reauth(BuildContext c, String why) async => (await reauthPw(c, why)) != null;

/// تأیید دومرحله‌ای برای حذف: ۱) پرسش ۲) تایپ کلمه‌ی «حذف»
Future<bool> confirmDelete(BuildContext c, String what) async {
  final first = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('حذف اطلاعات'),
      content: Text('«$what» حذف شود؟ این کار قابل بازگشت نیست.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kRed), onPressed: () => Navigator.pop(d, true), child: const Text('ادامه')),
      ],
    ),
  );
  if (first != true || !c.mounted) return false;
  final t = TextEditingController();
  final second = await showDialog<bool>(
    context: c,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('تأیید نهایی'),
        content: TextField(controller: t, onChanged: (_) => set(() {}), decoration: const InputDecoration(labelText: 'برای تأیید، کلمه‌ی «حذف» را بنویسید')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kRed), onPressed: t.text.trim() == 'حذف' ? () => Navigator.pop(d, true) : null, child: const Text('حذف قطعی')),
        ],
      ),
    ),
  );
  return second == true;
}

const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

FlTitlesData _titles(List<String> l) => FlTitlesData(
      topTitles: _noTitles,
      rightTitles: _noTitles,
      leftTitles: _noTitles,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          reservedSize: 26,
          getTitlesWidget: (x, m) {
            final i = x.toInt();
            if (i < 0 || i >= l.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(l[i], style: const TextStyle(fontSize: 10)));
          },
        ),
      ),
    );

final _grid = FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(.18), strokeWidth: 1),
);

Widget lineChart(List<double> v, List<String> l, Color col) => v.isEmpty ? const EmptyBox('داده‌ای برای نمایش نیست.') : LineChart(
      LineChartData(
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(l),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
            isCurved: true,
            barWidth: 3,
            color: col,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: col.withOpacity(.12)),
          ),
        ],
      ),
    );

Widget barChart(List<double> v, List<String> l, Color col) => v.isEmpty ? const EmptyBox('داده‌ای برای نمایش نیست.') : BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(l),
        barGroups: [
          for (var i = 0; i < v.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: v[i],
                width: v.length > 8 ? 10 : 16,
                color: i == v.length - 1 ? kYellow : col,
                borderRadius: BorderRadius.circular(5),
              ),
            ]),
        ],
      ),
    );
