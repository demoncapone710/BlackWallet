import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  Future<File> generateTransactionPdf(Map<String, dynamic> tx) async {
    final pdf = pw.Document();
    final df = DateFormat.yMMMd().add_jm();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BlackWallet', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Transaction Receipt', style: pw.TextStyle(fontSize: 18)),
                pw.Divider(),
                pw.Text('Transaction ID: ${tx['id']}'),
                pw.SizedBox(height: 8),
                pw.Text('Date: ${df.format(DateTime.parse(tx['created_at'] ?? DateTime.now().toIso8601String()))}'),
                pw.SizedBox(height: 8),
                pw.Text('Type: ${tx['type'] ?? 'n/a'}'),
                pw.SizedBox(height: 8),
                pw.Text('From: ${tx['sender'] ?? '—'}'),
                pw.SizedBox(height: 8),
                pw.Text('To: ${tx['receiver'] ?? '—'}'),
                pw.SizedBox(height: 8),
                pw.Text('Amount: \$${(tx['amount'] as num).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                if (tx['note'] != null && (tx['note'] as String).isNotEmpty) pw.SizedBox(height: 12),
                if (tx['note'] != null && (tx['note'] as String).isNotEmpty) pw.Text('Note: ${tx['note']}'),
                pw.Spacer(),
                pw.Divider(),
                pw.Text('Thank you for using BlackWallet', style: pw.TextStyle(color: PdfColor.fromHex('#666666'))),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/transaction_${tx['id']}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> exportTransactionsCsv(List<Map<String, dynamic>> transactions) async {
    final headers = ['id', 'date', 'type', 'sender', 'receiver', 'amount', 'note'];
    final rows = <List<dynamic>>[];
    rows.add(headers);

    for (var tx in transactions) {
      rows.add([
        tx['id'] ?? '',
        tx['created_at'] ?? '',
        tx['type'] ?? '',
        tx['sender'] ?? '',
        tx['receiver'] ?? '',
        (tx['amount'] as num).toStringAsFixed(2),
        tx['note'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/transactions_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<void> shareFile(File file, {String? subject, String? text}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'BlackWallet Export',
    );
  }
}
