import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'state.dart';
import 'ui.dart';

/// خروجی گزارش مصرف از داده‌ی واقعیِ ثبت‌شده. Excel: فایل CSV با UTF-8 که در Excel باز می‌شود.
Future<void> exportReport(BuildContext c, String title, Period p, double? tariff, {required bool pdf}) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  try {
    final rows = <List<String>>[];
    for (var i = 0; i < p.labels.length; i++) {
      if (!p.has[i]) continue;
      var ch = '';
      if (i > 0 && p.has[i - 1] && p.values[i - 1] > 0) {
        ch = '${fa((p.values[i] - p.values[i - 1]) / p.values[i - 1] * 100, d: 1)}٪';
      }
      rows.add([p.labels[i], fa(p.values[i], d: 1), tariff == null ? '-' : fa(p.values[i] * tariff), ch.isEmpty ? '-' : ch]);
    }
    const head = ['بازه', 'مصرف (kWh)', 'هزینه (تومان)', 'تغییر'];
    if (pdf) {
      final font = await PdfGoogleFonts.vazirmatnRegular();
      final doc = pw.Document();
      doc.addPage(pw.Page(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('گزارش مصرف برق - $title', style: const pw.TextStyle(fontSize: 20)),
            pw.Text('تاریخ: ${jDate(DateTime.now())}'),
            pw.SizedBox(height: 12),
            pw.Table(border: pw.TableBorder.all(), children: [
              for (final r in [head, ...rows])
                pw.TableRow(children: [for (final x in r) pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(x))]),
            ]),
          ]),
        ),
      ));
      await Printing.sharePdf(bytes: await doc.save(), filename: 'kashan_energy_$stamp.pdf');
    } else {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/kashan_energy_$stamp.csv');
      final csv = [head, ...rows].map((r) => r.map((x) => '"${x.replaceAll('"', '""')}"').join(',')).join('\r\n');
      await f.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      await Share.shareXFiles([XFile(f.path)]);
    }
  } catch (_) {
    if (c.mounted) toast(c, pdf ? 'ساخت PDF ناموفق بود. اتصال اینترنت (برای دریافت فونت فارسی) را بررسی کنید.' : 'ساخت فایل Excel ناموفق بود.');
  }
}
